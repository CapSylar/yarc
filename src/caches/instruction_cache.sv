
// Should be a pretty straighforward I$
// all writes from the cpu's wb interface are ignored
// 2-way set associative
// TODO: could we rewrite this in a way to make the way associativity passed in as a parameter

module instruction_cache
#(
    parameter unsigned NUM_SETS_LOG2 = 0
)
(
    input clk_i,
    input rstn_i,

    input flush_req_i,
    output flush_ack_o,

    // cpu <-> I$
    wishbone_if.SLAVE cpu_if,

    // I$ <-> Memory
    wishbone_if.MASTER mem_if
);

// offset is 2-bits => 4 words in a cache line
// each block is 4-bytes
// thus each cache line is 16-bytes or 128-bits
localparam unsigned NUM_SETS = 2**NUM_SETS_LOG2;
localparam unsigned INDEX_W = NUM_SETS_LOG2;
localparam unsigned OFFSET_W = 2;
localparam unsigned NUM_WAYS = 2;

localparam unsigned CPU_AW = $bits(cpu_if.addr);
localparam unsigned TAG_W = CPU_AW - INDEX_W - OFFSET_W;
// tag store
logic valid_bits [NUM_WAYS-1:0][NUM_SETS-1:0];// indicates that the corresponding cache line in valid
logic [NUM_SETS-1:0] set_age; // a bit for each set for now

localparam unsigned DATA_W = 32;
localparam unsigned LINE_W = (2**OFFSET_W) * DATA_W;

logic is_cpu_req_d, is_cpu_req_q;

// -------------------- Skid Buffer --------------------

// Pipe the wishbone cpu port through a skid buffer
typedef struct packed {
    logic [$bits(cpu_if.addr)-1:0] addr;
    logic [$bits(cpu_if.sel)-1:0] sel;
} wb_req_t;

wb_req_t cpu_if_req, cpu_if_req_skid;
assign cpu_if_req = '{addr: cpu_if.addr, sel: cpu_if.sel};
logic skid_valid, cache_ready, skid_ready;

skid_buffer
#(.T(wb_req_t))
skid_buffer_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .valid_i(cpu_if.stb & cpu_if.cyc),
    .data_i(cpu_if_req),
    .ready_o(skid_ready),

    .valid_o(skid_valid),
    .data_o(cpu_if_req_skid),
    .ready_i(cache_ready)
);

// Memory Instantiations
// ***********************************************************
logic [TAG_W-1:0] tag_addr_d, tag_addr_q;
logic [INDEX_W-1:0] index_addr_d, index_addr_q;
logic [OFFSET_W-1:0] offset_addr_d, offset_addr_q;
logic [CPU_AW-1:0] cpu_addr_d, cpu_addr_q;

always_comb begin
    cpu_addr_d = cpu_addr_q;

    if (is_cpu_req_d) begin // save the address when a request happens
        cpu_addr_d = cpu_if_req_skid.addr;
    end
end

assign {tag_addr_d, index_addr_d, offset_addr_d} = cpu_addr_d;
assign {tag_addr_q, index_addr_q, offset_addr_q} = cpu_addr_q;

logic valid_bits_re; // we read all of them at once
logic valid_bits_we [NUM_WAYS-1:0];
logic valid_bits_rdata [NUM_WAYS-1:0];
logic valid_bits_wdata; // only one is written at a time
logic [INDEX_W-1:0] valid_bits_raddr;
logic [INDEX_W-1:0] valid_bits_waddr;

logic flush_req;
logic flush_cache;

// valid_bits_e read and write
generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        always_ff@(posedge clk_i) begin
            if (!rstn_i | flush_cache) begin
                valid_bits[i] <= '{default: '0};
            end else begin
                if (valid_bits_re) begin
                    valid_bits_rdata[i] <= valid_bits[i][valid_bits_raddr];
                end

                if (valid_bits_we[i]) begin
                    valid_bits[i][valid_bits_waddr] <= valid_bits_wdata;
                end
            end
        end
    end
endgenerate

logic tag_mem_re; // we read all of them at once
logic tag_mem_we [NUM_WAYS-1:0];
logic [TAG_W-1:0] tag_mem_rdata [NUM_WAYS-1:0];
logic [TAG_W-1:0] tag_mem_wdata; // only one is written at a time
logic [INDEX_W-1:0] tag_mem_raddr;
logic [INDEX_W-1:0] tag_mem_waddr;

generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        sdp_mem #(.DW(TAG_W), .AW(INDEX_W), .INIT_MEM('0)) tag_mem
        (
            .clk_i(clk_i),

            .en_a_i(tag_mem_re),
            .addr_a_i(tag_mem_raddr),
            .rdata_a_o(tag_mem_rdata[i]),

            .en_b_i(tag_mem_we[i]),
            .addr_b_i(tag_mem_waddr),
            .wdata_b_i(tag_mem_wdata)
        );
    end
endgenerate

logic data_mem_re;
logic data_mem_we [NUM_WAYS-1:0];
logic [LINE_W-1:0] data_mem_rdata [NUM_WAYS-1:0];
logic [LINE_W-1:0] data_mem_wdata;
logic [INDEX_W-1:0] data_mem_raddr;
logic [INDEX_W-1:0] data_mem_waddr;

generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        sdp_mem #(.DW(LINE_W), .AW(INDEX_W), .INIT_MEM('0)) data_mem
        (
            .clk_i(clk_i),

            .en_a_i(data_mem_re),
            .addr_a_i(data_mem_raddr),
            .rdata_a_o(data_mem_rdata[i]),

            .en_b_i(data_mem_we[i]),
            .addr_b_i(data_mem_waddr),
            .wdata_b_i(data_mem_wdata)
        );
    end
endgenerate

// ***********************************************************

logic replace_way_idx; // index pointing to the way that will get replaced
logic [LINE_W-1:0] mem_if_rdata_q;

// wb sigs
assign is_cpu_req_d = skid_valid & cache_ready;

logic read_stores; // this signals that the tag and data stores are to be read
assign read_stores = is_cpu_req_d;

logic get_decision;
assign get_decision = is_cpu_req_q;

logic cpu_if_stall;
logic miss;
logic memory_send_req;
logic memory_resp_valid;
logic update_age;
logic restart;

// cache FSM
enum {RUNNING, WAIT_MEMORY, REFILL} state, next;
always_ff @(posedge clk_i)
    if (!rstn_i) state <= RUNNING;
    else         state <= next;

always_comb begin
    next = state;

    cache_ready = 1'b0;
    memory_send_req = '0;
    update_age = '0;
    restart = '0;
    flush_cache = '0;

    valid_bits_we = '{default: '0};
    tag_mem_we = '{default: '0};
    data_mem_we = '{default: '0};

    unique case (state)
        /*
        In this state, the cache accepts pipelined requests and handles them
        as soon as a request misses, the cpu wb bus is stalled and the state 
        changes to REFILL
        */
        RUNNING: begin
            cache_ready = 1'b1;

            if (miss) begin
                cache_ready = 1'b0; // can't accept any requests
                memory_send_req = 1'b1;
                next = WAIT_MEMORY;
            end else if (flush_req) begin
                cache_ready = 1'b0; // can't accept any requests
                flush_cache = 1'b1;
            end
        end

        // request the missing cache line from the backing storage
        WAIT_MEMORY: begin
            if (memory_resp_valid) begin
                next = REFILL;
            end
        end

        // the memory has given us a response, we need to place the 
        // loaded line in the storage
        REFILL: begin
            // write the tag, data and valid bits in the way that will be replaced
            tag_mem_we[replace_way_idx] = 1'b1;
            tag_mem_waddr = index_addr_q;
            tag_mem_wdata = tag_addr_q;
            data_mem_we[replace_way_idx] = 1'b1;
            data_mem_waddr = index_addr_q;
            data_mem_wdata = mem_if_rdata_q;
            valid_bits_we[replace_way_idx] = 1'b1;
            valid_bits_waddr = index_addr_q;
            valid_bits_wdata = 1'b1;

            // early restart
            restart = 1'b1;

            update_age = 1'b1;
            next = RUNNING;
        end
    endcase
end

logic mem_if_cyc;
logic mem_if_stb;
logic [$bits(mem_if.sel)-1:0] mem_if_sel;
logic [$bits(mem_if.addr)-1:0] mem_if_addr;

// memory wishbone fsm
enum {IDLE, REQUEST} wbstate, wbnext;
always_ff @(posedge clk_i)
    if (!rstn_i) wbstate <= IDLE;
    else         wbstate <= wbnext;

always_comb begin
    wbnext = wbstate;

    mem_if_sel = '1;
    mem_if_addr = '0;
    mem_if_cyc = '0;
    mem_if_stb = '0;

    memory_resp_valid = '0;

    unique case (wbstate)

        IDLE: begin
            if (memory_send_req) begin // FIXME: what is mem_if is stalled ?
                mem_if_cyc = 1'b1;
                mem_if_stb = 1'b1;
                mem_if_addr = cpu_addr_q[CPU_AW-1 : 2]; // TODO: localparam this
                wbnext = REQUEST;
            end
        end

        REQUEST: begin
            mem_if_cyc = 1'b1;

            if (mem_if.ack) begin
                memory_resp_valid = 1'b1;
                wbnext = IDLE;
            end
        end
    endcase
end

always_ff @(posedge clk_i) begin
    if (memory_resp_valid) begin // hold the loaded word
        mem_if_rdata_q <= mem_if.rdata;
    end
end

assign tag_mem_re = read_stores;
assign data_mem_re = read_stores;
assign valid_bits_re = read_stores;
assign tag_mem_raddr = index_addr_d;
assign data_mem_raddr = index_addr_d;
assign valid_bits_raddr = index_addr_d;

// logic that determines if hit or miss
logic [NUM_WAYS-1:0] line_valid ; // determines which way is valid
logic [$clog2(NUM_WAYS)-1:0] line_valid_idx ;
logic hit;
logic [DATA_W-1:0] read_word; // the word requested by the cpu

generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin: calc_line_valid
        assign line_valid[i] = (tag_addr_q == tag_mem_rdata[i]) & (valid_bits_rdata[i]);
    end
endgenerate

always_comb begin: calc_valid_index
    for (int i = 0 ; i < NUM_WAYS; ++i) begin
        line_valid_idx = i;
        if (line_valid[i]) begin
            break;
        end
    end
end

assign hit = get_decision ? |line_valid : '0;
assign miss = get_decision ? !hit : '0;
assign read_word = get_data_from_line(offset_addr_q, data_mem_rdata[line_valid_idx]);

function [DATA_W-1:0] get_data_from_line (logic [OFFSET_W-1:0] offset, logic [LINE_W-1:0] line_data);
    get_data_from_line = DATA_W'(line_data >> (DATA_W * offset));
endfunction

logic cpu_if_ack;
logic [DATA_W-1:0] cpu_if_rdata;

// cpu wishbone logic
always_comb begin
    cpu_if_ack = restart | hit;
    cpu_if_rdata = restart ? get_data_from_line(offset_addr_q, mem_if_rdata_q)
        : read_word;
end

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        cpu_addr_q <= '0;
        is_cpu_req_q <= '0;
    end else begin
        cpu_addr_q <= cpu_addr_d;
        is_cpu_req_q <= is_cpu_req_d;
    end
end

always_ff @(posedge clk_i) begin
    if (!rstn_i | flush_cache) begin
        set_age <= '{default: '0};
    end else if (update_age) begin
        set_age[index_addr_q] = ~replace_way_idx; // the new points now points to the other way
    end
end

// Replacement logic
assign replace_way_idx = set_age[index_addr_q];

// assign cpu wishbone outputs
assign cpu_if.rdata = cpu_if_rdata;
assign cpu_if.rty = '0;
assign cpu_if.ack = cpu_if_ack;
assign cpu_if.stall = ~skid_ready;
assign cpu_if.err = '0;

// assign memory wishbone outputs
assign mem_if.cyc = mem_if_cyc;
assign mem_if.stb = mem_if_stb;
assign mem_if.we = '0;
assign mem_if.addr = mem_if_addr;
assign mem_if.sel = mem_if_sel;
assign mem_if.wdata = '0;

logic flush_ack_q;
assign flush_req = flush_req_i & ~flush_ack_q;
wire flush_ack = flush_req & flush_cache;

flopr #(1) flush_ack_pipe (clk_i, rstn_i, flush_ack, flush_ack_q);

assign flush_ack_o = flush_ack_q;

endmodule: instruction_cache
