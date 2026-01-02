`default_nettype none

// Should be a pretty straighforward D$
// 4-way set associative
// write-through with a write buffer
// read misses should bypass write buffer

module data_cache
#(
    parameter unsigned NUM_SETS_LOG2 = 0,
    parameter unsigned WRITE_BUFFER_DEPTH_LOG2 = 0
)
(
    input wire clk_i,
    input wire rstn_i,

    // cpu <-> D$
    wishbone_if.SLAVE cpu_if,

    // D$ <-> memory
    wishbone_if.MASTER mem_if
);

localparam unsigned NUM_SETS = 2**NUM_SETS_LOG2;
localparam unsigned INDEX_W = NUM_SETS_LOG2;
localparam unsigned OFFSET_W = 2;
localparam unsigned NUM_WAYS = 4;
localparam unsigned AGE_BITS = NUM_WAYS-1; // per set, for PLRU

localparam unsigned CPU_AW = $bits(cpu_if.addr);
localparam unsigned CPU_DW = $bits(cpu_if.wdata);
localparam unsigned CPU_SEL_W = CPU_DW/8;

localparam unsigned TAG_W = CPU_AW - INDEX_W - OFFSET_W;
// tag store
logic valid_bits [NUM_WAYS-1:0][NUM_SETS-1:0];// indicates that the corresponding cache line in valid
logic [AGE_BITS-1:0] set_age [NUM_SETS-1:0]; // a bit for each set for now

localparam unsigned DATA_W = 32;
localparam unsigned LINE_DW = (2**OFFSET_W) * DATA_W;
localparam unsigned LINE_SEL_W = LINE_DW/8;

localparam SB_AW = WRITE_BUFFER_DEPTH_LOG2;
localparam unsigned SB_THRESHOLD = (2**SB_AW)/2;

typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [INDEX_W-1:0] index;
    logic [OFFSET_W-1:0] offset;
} req_addr_t;

logic is_cpu_req_d, is_cpu_req_q;
logic cpu_if_we_d, cpu_if_we_q;
req_addr_t cpu_if_addr_d, cpu_if_addr_q;
logic [CPU_SEL_W-1:0] cpu_if_sel_d, cpu_if_sel_q;
logic [CPU_DW-1:0] cpu_if_wdata_d, cpu_if_wdata_q;

fifo_types #(.DW(LINE_DW), .SEL_W(LINE_SEL_W), .AW(CPU_AW - 2)) types_i ();
typedef types_i.fifo_line_t fifo_line_t;

fifo_line_t sb_rdata;
logic [CPU_DW-1:0] sb_store_data;
logic [CPU_SEL_W -1:0] sb_store_sel;
logic [CPU_AW-1:0] sb_store_address;
logic sb_we, sb_re;
logic sb_empty, sb_full;
logic [SB_AW:0] sb_fill_count;

// -------------------- Skid Buffer --------------------

// Pipe the wishbone cpu port through a skid buffer
typedef struct packed {
    logic we;
    logic [$bits(cpu_if.addr)-1:0] addr;
    logic [$bits(cpu_if.sel)-1:0] sel;
    logic [$bits(cpu_if.wdata)-1:0] wdata;
} wb_req_t;

wb_req_t cpu_if_req, cpu_if_req_skid;
assign cpu_if_req = '{we: cpu_if.we, addr: cpu_if.addr, sel: cpu_if.sel, wdata: cpu_if.wdata};
logic skid_valid, cache_ready, skid_ready;

logic new_req_accepted;
assign new_req_accepted = skid_valid & cache_ready;

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

// -------------------- Memory Instantiations --------------------

always_comb begin
    cpu_if_we_d = cpu_if_we_q;
    cpu_if_addr_d = cpu_if_addr_q;
    cpu_if_sel_d = cpu_if_sel_q;
    cpu_if_wdata_d = cpu_if_wdata_q;

    // save the request when one is present
    if (new_req_accepted) begin
        cpu_if_we_d = cpu_if_req_skid.we;
        cpu_if_addr_d = cpu_if_req_skid.addr;
        cpu_if_sel_d = cpu_if_req_skid.sel;
        cpu_if_wdata_d = cpu_if_req_skid.wdata;
    end
end

logic valid_bits_re; // we read all of them at once
logic valid_bits_we [NUM_WAYS-1:0];
logic valid_bits_rdata [NUM_WAYS-1:0];
logic valid_bits_wdata; // only one is written at a time
logic [INDEX_W-1:0] valid_bits_raddr;
logic [INDEX_W-1:0] valid_bits_waddr;

// valid_bits_e read and write
generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        always_ff@(posedge clk_i) begin
            if (!rstn_i) begin
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
logic [LINE_DW-1:0] data_mem_rdata [NUM_WAYS-1:0];
logic [LINE_DW-1:0] data_mem_wdata;
logic [LINE_SEL_W-1:0] data_mem_wsel;
logic [INDEX_W-1:0] data_mem_raddr;
logic [INDEX_W-1:0] data_mem_waddr;

generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        sdp_mem_with_sel #(.DW(LINE_DW), .AW(INDEX_W), .INIT_MEM('0)) data_mem
        (
            .clk_i(clk_i),

            .en_a_i(data_mem_re),
            .addr_a_i(data_mem_raddr),
            .rdata_a_o(data_mem_rdata[i]),

            .en_b_i(data_mem_we[i]),
            .addr_b_i(data_mem_waddr),
            .wdata_b_i(data_mem_wdata),
            .wsel_b_i(data_mem_wsel)
        );
    end
endgenerate

// ***********************************************************

logic [$clog2(NUM_WAYS)-1:0] replace_way_idx; // index pointing to the way that will get replaced
logic [$clog2(NUM_WAYS)-1:0] access_way_idx; // index pointing to the way that will get replaced

logic [AGE_BITS-1:0] age_bits_next; // index pointing to the way that will get replaced
logic [LINE_DW-1:0] mem_if_rdata_q;

logic hold_req; // driven by the fsm

always_comb begin
    is_cpu_req_d = is_cpu_req_q;

    if (!hold_req) begin
        is_cpu_req_d = new_req_accepted;
    end
end

logic read_stores; // this signals that the tag and data stores are to be read
assign read_stores = new_req_accepted;

// logic cpu_if_stall;
logic fsm_stall_cpu_reqs;
logic read_miss, read_hit;
logic write_miss, write_hit;
logic memory_refill_req;
logic memory_resp_valid;
logic update_age_fill;
logic update_age_hit;
logic restart;

logic install_cache_line;
logic write_into_cache_line;

logic is_read, is_write;
// data hazard detection
// detect when a read hits the word that was hit by a write in the previous cycle
// or a read hits a word that was written into the store buffer (write miss)
// we need to stall a cycle in this case since the read may get stale data
// we don't check for the sizes, which means we could sometimes stall when we shouldn't
// but this doesn't matter since optimal code won't read something that was written to memory right away

logic data_hazard;
assign data_hazard = is_write & skid_valid & ~(fsm_stall_cpu_reqs) & ~cpu_if_req_skid.we & (cpu_if_req_skid.addr == cpu_if_addr_q); // TODO: clean this shit up
logic sb_full_stall;

// TODO: even when sb_full_stall is one, the cpu gets the ack which it should not
assign cache_ready = ~(fsm_stall_cpu_reqs | data_hazard);

// cache FSM
enum {RUNNING, WAIT_MEMORY, REFILL, SB_FULL_WAIT} state, next;
always_ff @(posedge clk_i)
    if (!rstn_i) state <= RUNNING;
    else         state <= next;

always_comb begin
    next = state;

    fsm_stall_cpu_reqs = '0;
    install_cache_line = '0;
    memory_refill_req = '0;
    update_age_fill = '0;
    restart = '0;
    write_into_cache_line = '0;
    hold_req = '0;

    unique case (state)
        /*
        In this state, the cache accepts pipelined requests and handles them
        as soon as a request misses, the cpu wb bus is stalled and the state 
        changes to REFILL
        */
        RUNNING: begin
            case (1'b1)
                sb_full_stall: begin
                    hold_req = 1'b1;
                    fsm_stall_cpu_reqs = 1'b1; // can't access anymore requests
                    next = SB_FULL_WAIT;
                end

                read_miss: begin
                    fsm_stall_cpu_reqs = 1'b1; // can't access anymore requests
                    memory_refill_req = 1'b1;
                    next = WAIT_MEMORY;
                end

                write_miss: begin
                    // TODO: do we need to stall the interface ? we can keep going i think
                    // FIXME: need to stall if the write buffer is full 
                end

                write_hit: begin
                    write_into_cache_line = 1'b1;
                    // update the cache line
                end
                default: begin end
            endcase
        end

        // request the missing cache line from the backing storage
        WAIT_MEMORY: begin
            memory_refill_req = 1'b1; // we'll keep it high until we get a resp_valid signal
            fsm_stall_cpu_reqs = 1'b1; // can't accept anymore requests
            if (memory_resp_valid) begin
                next = REFILL;
            end
        end

        // the memory has given us a response, we need to place the 
        // loaded line in the storage
        REFILL: begin
            fsm_stall_cpu_reqs = 1'b1; // can't accept anymore requests
            install_cache_line = 1'b1;

            // early restart
            restart = 1'b1;

            update_age_fill = 1'b1;
            next = RUNNING;
        end

        SB_FULL_WAIT: begin
            hold_req = 1'b1;
            fsm_stall_cpu_reqs = 1'b1;

            if(!sb_full) begin
                next = RUNNING;
            end
        end
    endcase
end

logic mem_if_cyc;
logic mem_if_stb;
logic mem_if_we;
logic [$bits(mem_if.sel)-1:0] mem_if_sel;
logic [$bits(mem_if.addr)-1:0] mem_if_addr;
logic [LINE_DW-1:0] mem_if_wdata;

// this fsm is responsible for interacting with the memory, one hierarchy lower
// memory wishbone fsm
enum {IDLE, READ_REQUEST, WRITE_REQUEST} wbstate, wbnext;
always_ff @(posedge clk_i)
    if (!rstn_i) wbstate <= IDLE;
    else         wbstate <= wbnext;

always_comb begin
    wbnext = wbstate;

    mem_if_we = '0;
    mem_if_sel = '1;
    mem_if_addr = '0;
    mem_if_cyc = '0;
    mem_if_stb = '0;
    mem_if_wdata = '0;

    memory_resp_valid = '0;

    sb_re = '0;

    unique case (wbstate)

        IDLE: begin
            // check if there are writes in the write buffer that need to be retired
            // if a refill request comes in, it takes priority

            if (!mem_if.stall) begin // don't do anything if the memory is stalled
                if (memory_refill_req) begin
                    mem_if_cyc = 1'b1;
                    mem_if_stb = 1'b1;
                    mem_if_addr = cpu_if_addr_q[CPU_AW-1 : 2]; // TODO: localparam this
                    wbnext = READ_REQUEST;

                /*
                    don't immediately empty the store buffer, it's wise to keep some entries in it
                    which will make it possible to merge more entries
                */
                end else if (sb_fill_count > SB_THRESHOLD) begin
                    // pop write request from the write buffer and send it to memory
                    sb_re = 1'b1;

                    mem_if_cyc = 1'b1;
                    mem_if_stb = 1'b1;
                    mem_if_we = 1'b1;
                    mem_if_sel = sb_rdata.sel;
                    mem_if_addr = sb_rdata.address;
                    mem_if_wdata = sb_rdata.data;
                    wbnext = WRITE_REQUEST;
                end
            end
        end

        READ_REQUEST: begin
            mem_if_cyc = 1'b1;

            if (mem_if.ack) begin
                memory_resp_valid = 1'b1;
                wbnext = IDLE;
            end
        end

        WRITE_REQUEST: begin
            mem_if_cyc = 1'b1;

            if(mem_if.ack) begin
                wbnext = IDLE;
            end
        end
    endcase
end

// write to write buffer on every write, hit or miss
assign sb_store_data = cpu_if_wdata_q;
assign sb_store_sel = cpu_if_sel_q;
assign sb_store_address = cpu_if_addr_q;

assign sb_we = is_write & !hold_req;
assign sb_full_stall = is_write & sb_full; // stall the request when the store buffer is full

always_ff @(posedge clk_i) begin
    if (memory_resp_valid) begin // hold the loaded word
        mem_if_rdata_q <= mem_if.rdata;
    end
end

assign tag_mem_re = read_stores;
assign data_mem_re = read_stores;
assign valid_bits_re = read_stores;
assign tag_mem_raddr = cpu_if_addr_d.index;
assign data_mem_raddr = cpu_if_addr_d.index;
assign valid_bits_raddr = cpu_if_addr_d.index;

// ------------------- Hit or Miss logic -------------------

logic [NUM_WAYS-1:0] cache_line_valid ; // determines which way is valid
logic [$clog2(NUM_WAYS)-1:0] cache_line_valid_idx ;
logic cache_hit;
logic read_hit_cache, read_hit_sb;
logic sb_hit;
logic [DATA_W-1:0] read_word_cacheline; // the word requested by the cpu

logic sb_check;
logic [CPU_AW-1:0] sb_check_address;
logic [CPU_SEL_W-1:0] sb_check_sel;

logic sb_match;
logic [DATA_W-1:0] sb_match_data;

// read hit = hit in cache line | hit in write buffer
// write hit = hit in cache line only (we don't check the write buffer)

generate
    for (genvar i = 0; i < NUM_WAYS; ++i) begin: calc_line_valid
        assign cache_line_valid[i] = (cpu_if_addr_q.tag == tag_mem_rdata[i]) & (valid_bits_rdata[i]);
    end
endgenerate

assign sb_check = new_req_accepted; // results are valid at the next posedge
assign sb_check_address = cpu_if_addr_d;
assign sb_check_sel = cpu_if_sel_d;
assign sb_hit = is_cpu_req_q & sb_match;

always_comb begin: calc_valid_index
    for (int i = 0 ; i < NUM_WAYS; ++i) begin
        cache_line_valid_idx = i;
        if (cache_line_valid[i]) begin
            break;
        end
    end
end

assign is_write = is_cpu_req_q & cpu_if_we_q;
assign is_read = is_cpu_req_q & ~cpu_if_we_q;

// TODO: refactor these
assign cache_hit = is_cpu_req_q & |cache_line_valid;

assign read_hit_cache = !cpu_if_we_q & (cache_hit);
assign read_hit_sb = !cpu_if_we_q & (sb_hit);

assign read_hit = read_hit_cache | read_hit_sb;
assign write_hit = cpu_if_we_q & (cache_hit);

assign update_age_hit = read_hit | write_hit;

assign read_miss = is_read & !read_hit;
assign write_miss = is_write & !write_hit;

assign read_word_cacheline = get_data_from_line(cpu_if_addr_q.offset, data_mem_rdata[cache_line_valid_idx]);

function [DATA_W-1:0] get_data_from_line (logic [OFFSET_W-1:0] offset, logic [LINE_DW-1:0] line_data);
    get_data_from_line = DATA_W'(line_data >> (DATA_W * offset));
endfunction

logic cpu_if_ack;
logic [DATA_W-1:0] cpu_if_rdata;

assign cpu_if_ack = (restart | read_hit | write_hit | write_miss) & !hold_req;

// cpu wishbone logic
always_comb begin
    case (1'b1)
        restart:        cpu_if_rdata = get_data_from_line(cpu_if_addr_q.offset, mem_if_rdata_q);
        read_hit_cache: cpu_if_rdata = read_word_cacheline;
        read_hit_sb:    cpu_if_rdata = sb_match_data;
        default:        cpu_if_rdata = '0;
    endcase
end

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        cpu_if_addr_q <= '0;
        cpu_if_we_q <= '0;
        cpu_if_wdata_q <= '0;
        cpu_if_sel_q <= '0;
        is_cpu_req_q <= '0;
    end else begin
        cpu_if_addr_q <= cpu_if_addr_d;
        cpu_if_we_q <= cpu_if_we_d;
        cpu_if_wdata_q <= cpu_if_wdata_d;
        cpu_if_sel_q <= cpu_if_sel_d;
        is_cpu_req_q <= is_cpu_req_d;
    end
end

//  --------------------- Age Update Logic, Replacement PLRU ---------------------

assign access_way_idx = update_age_fill ? replace_way_idx : cache_line_valid_idx;

plru #(.NUM_WAYS(NUM_WAYS))
plru_i
(
    .age_bits_i(set_age[cpu_if_addr_q.index]),
    .access_idx_i(access_way_idx),

    .age_bits_next_o(age_bits_next),
    .lru_idx_o(replace_way_idx)
);

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        set_age <= '{default: '0};
    end else if (update_age_fill | update_age_hit) begin
        set_age[cpu_if_addr_q.index] = age_bits_next;
    end
end

// ------------------- Logic that interacts with the tag, data memories -------------------
always_comb begin
    // defaults
    valid_bits_we = '{default: '0};
    tag_mem_we = '{default: '0};
    data_mem_we = '{default: '0};
    data_mem_wsel = {($size(data_mem_wsel)){1'b1}};

    tag_mem_waddr = cpu_if_addr_q.index;
    tag_mem_wdata = cpu_if_addr_q.tag;
    data_mem_waddr = cpu_if_addr_q.index;

    valid_bits_waddr = cpu_if_addr_q.index;
    valid_bits_wdata = 1'b1;

    unique case (1'b1)
        install_cache_line: begin
            tag_mem_we[replace_way_idx] = 1'b1;
            data_mem_we[replace_way_idx] = 1'b1;
            data_mem_wdata = mem_if_rdata_q;
            valid_bits_we[replace_way_idx] = 1'b1;
        end

        write_into_cache_line: begin
            data_mem_we[cache_line_valid_idx] = 1'b1;

            // the written word is smaller than the cache line
            // position it correctly
            data_mem_wdata = cpu_if_wdata_q << (CPU_DW * cpu_if_addr_q.offset);
            data_mem_wsel = cpu_if_sel_q << ((CPU_SEL_W) * cpu_if_addr_q.offset);
        end

        default: begin end
    endcase
end

// --------------------- Write Buffer ---------------------
write_buffer 
#(
    .LINE_DW(LINE_DW),
    .DATA_W(DATA_W),
    .ADDRESS_WIDTH(CPU_AW),
    .DEPTH_LOG2(SB_AW)
)
write_buffer_i 
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // write side
    .we_i(sb_we),
    .store_data_i(sb_store_data),
    .store_sel_i(sb_store_sel),
    .store_address_i(sb_store_address),

    // read side
    .re_i(sb_re),
    .rdata_o(sb_rdata),

    // status
    .fill_count_o(sb_fill_count),
    .empty_o(sb_empty),
    .full_o(sb_full),

    // logic for load hazard detection
    .check_i(sb_check),
    .check_address_i(sb_check_address),
    .check_sel_i(sb_check_sel),

    .hit_o(sb_match),
    .hit_data_o(sb_match_data)
);

// assign cpu wishbone outputs
assign cpu_if.rdata = cpu_if_rdata;
assign cpu_if.rty = '0;
assign cpu_if.ack = cpu_if_ack;
assign cpu_if.stall = ~skid_ready;
assign cpu_if.err = '0;

// assign memory wishbone outputs
assign mem_if.cyc = mem_if_cyc;
assign mem_if.stb = mem_if_stb;
assign mem_if.we = mem_if_we;
assign mem_if.addr = mem_if_addr;
assign mem_if.sel = mem_if_sel;
assign mem_if.wdata = mem_if_wdata;

endmodule: data_cache
