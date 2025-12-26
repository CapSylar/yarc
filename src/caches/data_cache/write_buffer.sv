`default_nettype none
// a write buffer for the data cache
// does coalescing writes

module write_buffer
#(
    // width of the stored data in a fifo line
    parameter unsigned LINE_DW = 0,

    // TODO: document
    parameter unsigned DATA_W = 0,
    // width of the address that is stored along side the data
    parameter unsigned ADDRESS_WIDTH = 0,
    // depth of fifo buffer log2, 3 => 8 entries
    parameter unsigned DEPTH_LOG2 = 0,

    localparam unsigned OFFSET_BITS = $clog2(LINE_DW/DATA_W),
    localparam unsigned LINE_AW = ADDRESS_WIDTH - OFFSET_BITS,

    localparam unsigned SEL_W = DATA_W / 8,
    localparam unsigned LINE_SEL_W = LINE_DW / 8,
    localparam unsigned FIFO_DW = LINE_DW + LINE_SEL_W + LINE_AW,
    localparam unsigned NUM_ELEMS = 2**DEPTH_LOG2
)
(
    input wire clk_i,
    input wire rstn_i,

    // write side
    input wire we_i,
    input wire [DATA_W-1:0] store_data_i,
    input wire [SEL_W-1:0] store_sel_i,
    input wire [ADDRESS_WIDTH-1:0] store_address_i,

    // read side
    input wire re_i,
    output logic [FIFO_DW-1:0] rdata_o,

    output logic [DEPTH_LOG2:0] fill_count_o,
    output logic empty_o,
    output logic full_o,

    // hit logic for load hazard detection
    input wire check_i,

    input wire [ADDRESS_WIDTH-1:0] check_address_i,
    input wire [SEL_W-1:0] check_sel_i,

    output logic hit_o,
    output logic [DATA_W-1:0] hit_data_o
);

localparam NUM_ELE_W = DEPTH_LOG2;

fifo_types #(.DW(LINE_DW), .SEL_W(LINE_SEL_W), .AW(LINE_AW)) types_i ();
typedef types_i.fifo_line_t fifo_line_t;

// -------------------------- FIFO LOGIC --------------------------
fifo_line_t mem [NUM_ELEMS];

// one additional bit that allows us to detect wrap arounds
logic [NUM_ELE_W:0] wr_addr, rd_addr; 
logic [NUM_ELE_W-1:0] wr_addr_mem, rd_addr_mem; // these are used to access fifo memory

assign wr_addr_mem = wr_addr[NUM_ELE_W-1:0];
assign rd_addr_mem = rd_addr[NUM_ELE_W-1:0];

logic merge;
logic [NUM_ELE_W-1:0] merge_line_hit_idx;
logic re, fifo_append;
fifo_line_t merged_line;

assign re = re_i & ~empty_o;
assign fifo_append = we_i & ~full_o & ~merge;

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        wr_addr <= '0;
    end else if (fifo_append) begin
        wr_addr <= wr_addr + 1'b1;
    end
end

// convert input to the larger bus size
logic [LINE_DW-1:0] exp_store_data;
logic [LINE_SEL_W-1:0] exp_store_sel;
logic [LINE_AW-1:0] exp_store_address;
logic [LINE_DW-1:0] merge_mask;

always_comb begin
    for (int i = 0; i < LINE_SEL_W; ++i) begin
        merge_mask[i*8 +: 8] = {8{exp_store_sel[i]}};
    end
end

fifo_line_t fifo_line_wdata;
assign fifo_line_wdata = merge ? merged_line
                         : '{data: exp_store_data, sel: exp_store_sel, address: exp_store_address};

logic [NUM_ELE_W-1:0] fifo_waddr;
assign fifo_waddr = merge ? merge_line_hit_idx
                                     : wr_addr_mem;

// writing to fifo
always_ff @(posedge clk_i) begin
    if (fifo_append | merge) begin
        mem[fifo_waddr] <= fifo_line_wdata;
    end
end

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        rd_addr <= '0;
    end else if (re) begin
        rd_addr <= rd_addr + 1'b1;
    end
end

// reading from fifo
// no delay read
assign rdata_o = mem[rd_addr_mem];

// assign status signals
assign fill_count_o = wr_addr - rd_addr;
assign full_o = (fill_count_o == {1'b1, {(NUM_ELE_W){1'b0}}});
assign empty_o = (fill_count_o == '0);

logic [NUM_ELEMS-1:0] valid_d, valid_q;

always_comb begin
    valid_d = valid_q;

    if (fifo_append) begin
        valid_d[wr_addr_mem] = 1'b1;
    end

    if (re) begin
        valid_d[rd_addr_mem] = '0;
    end
end

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        valid_q <= '0;
    end else begin
        valid_q <= valid_d;
    end
end

logic [LINE_SEL_W-1:0] check_sel;
logic [LINE_AW-1:0] check_address;
logic [OFFSET_BITS-1:0] check_address_offset;

assign check_address_offset = check_address_i[OFFSET_BITS-1:0];

// convert from sel and address for a wb bus of width DATA_W to a bus of width LINE_W
assign check_sel = (check_sel_i) << (SEL_W * check_address_offset);
assign check_address = check_address_i[ADDRESS_WIDTH-1:OFFSET_BITS];

// ----------------------------- Write Buffer Logic -----------------------------
// when a check comes in, check the tag address of all valid entries
logic [NUM_ELEMS-1:0] check_address_match;
logic [NUM_ELEMS-1:0] check_line_hit;
logic [NUM_ELE_W-1:0] check_line_hit_idx;
logic hit_d, hit_q;
logic [LINE_DW-1:0] hit_data_d, hit_data_q;

always_comb begin
    check_address_match = '0;

    /*
     * - addresses need to check
     * - read word needs to be included the written word of the entry
    */
    for (int i = 0; i < NUM_ELEMS; ++i) begin
        check_address_match[i] = (mem[i].address == check_address) &&
            ((mem[i].sel & check_sel) == check_sel);
    end
end

always_comb begin
    check_line_hit = '0;

    for (int i = 0; i < NUM_ELEMS; ++i) begin
        if (valid_q[i] & check_address_match[i]) begin
            check_line_hit[i] = 1'b1;
        end

    end
end

always_comb begin
    check_line_hit_idx = '0;

    for (int i = 0; i < NUM_ELEMS; ++i) begin
        if (check_line_hit[i]) begin
            check_line_hit_idx = i;
            break;
        end
    end
end

logic [ADDRESS_WIDTH-1:0] check_addr_q;

assign hit_d = |check_line_hit; // is any line hit
assign hit_data_d = (mem[check_line_hit_idx].data) ;

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        hit_q <= '0;
        hit_data_q <= '0;
        check_addr_q <= '0;
    end else begin
        hit_q <= hit_d;
        hit_data_q <= hit_data_d;
        check_addr_q <= check_address_i;
    end
end

assign hit_o = hit_q;
assign hit_data_o = hit_data_q >> (check_addr_q[OFFSET_BITS-1:0]) * DATA_W;

// coalescing part
logic [NUM_ELEMS-1:0] merge_line_match;
logic [NUM_ELEMS-1:0] merge_line_hit;

logic [OFFSET_BITS-1:0] store_address_offset;
assign store_address_offset = store_address_i[OFFSET_BITS-1:0];
assign merge = |merge_line_hit & we_i;

always_comb begin
    merge_line_match = '0;

    for (int i = 0; i < NUM_ELEMS; ++i) begin
        merge_line_match[i] = (mem[i].address == exp_store_address);
    end
end

always_comb begin
    merge_line_hit = '0;

    for (int i = 0; i < NUM_ELEMS; ++i) begin
        if (valid_q[i] & merge_line_match[i]) begin
            merge_line_hit[i] = 1'b1;
        end
    end
end

always_comb begin
    merge_line_hit_idx = '0;

    for (int i = 0; i < NUM_ELEMS; ++i) begin
        if (merge_line_hit[i]) begin
            merge_line_hit_idx = i;
            break;
        end
    end
end

assign exp_store_sel = store_sel_i << (SEL_W * store_address_offset);
assign exp_store_data = store_data_i << (DATA_W * store_address_offset);
assign exp_store_address = store_address_i[ADDRESS_WIDTH-1:OFFSET_BITS];

// merge the two entries
// overwrite place the written data into the fifo line, possibly overwriting some old write
assign merged_line.data = (mem[merge_line_hit_idx].data & ~merge_mask) | (merge_mask & exp_store_data);
assign merged_line.sel = mem[merge_line_hit_idx].sel | exp_store_sel;
assign merged_line.address = exp_store_address;

endmodule: write_buffer
