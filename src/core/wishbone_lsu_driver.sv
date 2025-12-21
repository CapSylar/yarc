// Load Store Unit, Interract with the subsystem through Wishbone Pipeline B4

module wishbone_lsu_driver
import riscv_pkg::*;
(
    input clk_i,
    input rstn_i,

    // LSU <-> Data Port
    wishbone_if.MASTER wb_if,

    // <-> LSU unit
    input req_i,
    input we_i,
    input [31:0] addr_i,
    input [3:0] wsel_byte_i,
    input [31:0] wdata_i,

    output logic req_done_o,
    output logic [31:0] rdata_o,

    output logic req_stall_o // current request needs to be held
);

// count the number of pending acks that we must wait for before
// terminating the bus cycle
logic [1:0] ack_pending_d, ack_pending_q;

always_comb
begin
    ack_pending_d = ack_pending_q;

    if (wb_if.stb)
        ack_pending_d = ack_pending_d + 1'b1;

    if (wb_if.ack)
        ack_pending_d = ack_pending_d - 1'b1;
end

always_ff @(posedge clk_i)
begin
    if (!rstn_i)
        ack_pending_q <= '0;
    else
        ack_pending_q <= ack_pending_d;
end

logic wb_cyc;
logic wb_stb;
logic wb_lock;
logic wb_we;
logic [31:0] wb_addr;
logic [3:0] wb_sel;
logic [31:0] wb_wdata;

assign wb_lock = '0;

// wishbone master logic
typedef enum
{
    IDLE,
    BUS_REQ,
    BUS_WAIT
} wb_state_e;

wb_state_e current, next;

always_ff @(posedge clk_i)
    if (!rstn_i) current <= IDLE;
    else current <= next;

// next state logic
always_comb
begin : next_state

    next = current;
    req_stall_o = '0;
    wb_cyc = '0;
    wb_stb = 0;

    case (current)
        IDLE:
        begin
            if (req_i)
                next = BUS_REQ;
        end

        // actively requesting
        BUS_REQ:
        begin
            wb_cyc = 1'b1;
            wb_stb = 1'b1;

            if (wb_if.stall)
                req_stall_o = 1'b1;
            else if (!req_i)
                next = BUS_WAIT;
        end

        // only waiting for an ack to return
        BUS_WAIT:
        begin
            wb_cyc = 1'b1;

            if (req_i)
                next = BUS_REQ;
            else if (wb_if.ack && (ack_pending_d == '0)) // nothing left to wait for
                next = IDLE;
        end
    endcase
end

// drive the data/control out lines
always_comb
begin
    wb_we = '0;
    wb_addr = '0;
    wb_wdata = '0;
    wb_sel = '0;

    // in this case, we simply translate the request combinationally
    if (current == BUS_REQ)
    begin
        wb_we = we_i;
        wb_addr = addr_i;
        wb_wdata = wdata_i;
        wb_sel = we_i ? wsel_byte_i : 4'hf;
    end
end

// drive the request done signals
always_comb
begin
    req_done_o = '0;
    rdata_o = '0;

    if (wb_if.ack)
    begin
        req_done_o = 1'b1;
        rdata_o = wb_if.rdata;
    end
end

// assign signals to wishbone interface
assign wb_if.cyc = wb_cyc;
assign wb_if.stb = wb_stb;
assign wb_if.we = wb_we;
assign wb_if.addr = wb_addr[31:2];
assign wb_if.sel = wb_sel;
assign wb_if.wdata = wb_wdata;

endmodule: wishbone_lsu_driver
