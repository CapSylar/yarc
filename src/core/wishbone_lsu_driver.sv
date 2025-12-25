// Load Store Unit, Interract with the subsystem through Wishbone Pipeline B4

`default_nettype none

module wishbone_lsu_driver
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    // LSU <-> Data Port
    wishbone_if.MASTER wb_if,

    // <-> LSU unit
    input wire req_i,
    input wire we_i,
    input wire lock_i,
    input wire [31:0] addr_i,
    input wire [3:0] wsel_byte_i,
    input wire [31:0] wdata_i,

    output logic req_done_o,
    output logic [31:0] rdata_o
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
logic saved_we;
logic save;
logic [31:0] wb_addr;
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
    save = '0;
    wb_cyc = '0;
    wb_stb = 0;

    case (current)
        IDLE:
        begin
            if (req_i) begin
                save = 1'b1;
                next = BUS_REQ;
            end
        end

        // actively requesting
        BUS_REQ:
        begin
            wb_cyc = 1'b1;
            wb_stb = 1'b1;

            // we only check for ack on the next cycle
            // so be careful, single cycle responses are thus not handled
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
    wb_addr = '0;
    wb_wdata = '0;

    // in this case, we simply translate the request combinationally
    if (current == BUS_REQ)
    begin
        wb_addr = addr_i;
        wb_wdata = wdata_i;
    end
end

flopenrc #(1) wb_we_pipe (clk_i, rstn_i, 1'b0, save, we_i, saved_we);

// drive the request done signals
assign rdata_o = wb_if.rdata;
assign req_done_o = wb_if.ack;

// assign signals to wishbone interface
assign wb_if.cyc =   wb_cyc;
assign wb_if.stb =   wb_stb;
assign wb_if.we =    saved_we;
assign wb_if.addr =  wb_addr[31:2];
assign wb_if.sel =   saved_we ? wsel_byte_i : 4'hf;
assign wb_if.wdata = wb_wdata;

endmodule: wishbone_lsu_driver

`default_nettype wire
