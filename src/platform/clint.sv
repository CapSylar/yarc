// Sifive compatible CLINT

`default_nettype none

module clint
(
    input wire clk_i,
    input wire rstn_i,

    wishbone_if.SLAVE wb_if,

    output logic m_timer_interrupt_o,
    output logic m_software_interrupt_o
);

// MSIP 1-bit register @0
// MTIMECMP for hart0 @4000
// MTIME for hart0 @BFF8

localparam unsigned MSIP_OFFSET = '0;

localparam unsigned MTIMECMP_OFFSET = 'h4000 >> 2;
localparam unsigned MTIMECMPH_OFFSET = 'h4004 >> 2;

localparam unsigned MTIME_OFFSET = 'hBFF8 >> 2;
localparam unsigned MTIMEH_OFFSET = 'hBFFC >> 2;

wire is_addressed = wb_if.cyc & wb_if.stb;

logic msip;
logic [63:0] mtime_q, mtime_d;
logic [63:0] mtimecmp_q, mtimecmp_d;

logic [31:0] rdata_d, rdata_q;
logic ack_q;

wire [13:0] addr = wb_if.addr[13:0]; // the two LSBs are don't cares, 4-byte granularity

// combinational reads
always_comb
begin: read_logic
    rdata_d = '0;

    unique case (addr)
        MSIP_OFFSET: rdata_d = 32'(msip);

        MTIMECMP_OFFSET: rdata_d = mtime_q[31:0];
        MTIMECMPH_OFFSET: rdata_d = mtime_q[63:32];

        MTIME_OFFSET: rdata_d = mtimecmp_q[31:0];
        MTIMEH_OFFSET: rdata_d = mtimecmp_q[63:32];
        default:;
    endcase
end

logic msip_we;
logic mtimecmp_we;
logic mtime_we;

always_comb
begin: write_logic

    msip_we = '0;
    mtimecmp_we = '0;
    mtime_we = '0;

    if (is_addressed & wb_if.we)
        unique case(addr)
            MSIP_OFFSET: begin
                msip_we = 1'b1;
            end

            MTIMECMP_OFFSET, MTIMECMPH_OFFSET: begin
                mtimecmp_we = 1'b1;
            end

            MTIME_OFFSET, MTIMEH_OFFSET: begin
                mtime_we = 1'b1;
            end
            default:;
        endcase
end

// MSIP
wire write_bit = msip_we & wb_if.sel[0];
flopenrc #(1) msip_bit (clk_i, rstn_i, 1'b0, write_bit, wb_if.wdata[0], msip);

wire is_upper = wb_if.addr[0];

// MTIME
wire [7:0] wide_sel = is_upper ? {wb_if.sel, 4'b0} : {4'b0, wb_if.sel};
wire [63:0] wide_data = is_upper ? {wb_if.wdata, 32'b0} : {32'b0, wb_if.wdata};

logic [63:0] wide_mask;
always_comb begin
    for (int i = 0; i < 64; ++i) begin
        wide_mask[i] = wide_sel[i / 8];
    end
end

always_comb begin
    mtime_d = mtime_q;

    if (mtime_we) begin
        mtime_d = wide_data & wide_mask | mtime_q & ~wide_mask;
    end else begin
        mtime_d = mtime_q + 1'b1;
    end
end

flopr #(64) mtime_register (clk_i, rstn_i, mtime_d, mtime_q);

always_comb begin
    mtimecmp_d = mtimecmp_q;

    if (mtimecmp_we) begin
        mtimecmp_d = wide_data & wide_mask | mtimecmp_q & ~wide_mask;
    end
end

flopr #(64) mtimecmp_register (clk_i, rstn_i, mtimecmp_d, mtimecmp_q);

// wb logic
always_ff @(posedge clk_i)
begin
    if (!rstn_i)
    begin
        rdata_q <= '0;
        ack_q <= '0;
    end
    else
    begin
        rdata_q <= rdata_d;
        ack_q <= is_addressed;
    end
end

// assign outputs
assign wb_if.rdata = rdata_q;
assign wb_if.rty = '0;
assign wb_if.ack = ack_q;
assign wb_if.stall = '0;
assign wb_if.err = '0;

// interrupt output
assign m_timer_interrupt_o = (mtime_q >= mtimecmp_q);
assign m_software_interrupt_o = msip;

endmodule: clint

`default_nettype wire
