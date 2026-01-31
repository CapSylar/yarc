// cpu fetch module, interfaces with the simple simulation memories
// assumes a memory with synchronous reading

module simple_fetch
import core_pkg::*;
import csr_pkg::*;
#(parameter bit [31:0] BOOT_PC = 'h8000_0000)
(
    input clk_i,
    input rstn_i,

    // FETCH <-> wishbone interface
    wishbone_if.MASTER wb_if,

    // CPU <-> fetch interface
    output logic valid_o, // a valid instruction is presented
    output logic [31:0] instr_o, // the instruction, only valid when valid_o = 1
    output logic [31:0] pc_o, // program counter of the instruction presented to the cpu

    input stall_i, // is the cpu stalled ?
    input flush_i, // flushes and re-fetches all instructions after pc_o

    input new_pc_en_i, // load a new pc
    input pc_sel_t pc_sel_i, // which pc to load from the addresses below

    // target addresses
    input [31:0] branch_target_i,
    input [31:0] csr_mepc_i,
    input var mcause_t mcause_i, // comes from the controller, not csr module
    input var mtvec_t mtvec_i
);

logic [31:0] raddr_q, raddr_d;
logic [31:0] arch_pc_q, arch_pc_d;

logic [31:0] new_pc;
logic [31:0] instr_buffer_q, instr_buffer_d;
logic present_buffer;
logic stb, cyc;

logic [2:0] out_acks_q, out_acks_d; // outstanding acks

always_comb
begin
    out_acks_d = out_acks_q;

    // if inc and dec at the same time, the counter stays the same
    if (cyc & stb & !wb_if.stall) // a wb request is accepted
        out_acks_d = out_acks_d + 1'b1;
    
    if (wb_if.ack)
        out_acks_d = out_acks_d - 1'b1;
end

always_ff @(posedge clk_i)
    if (!rstn_i) out_acks_q <= '0;
    else         out_acks_q <= out_acks_d;

// calculate the expection target address from mtvec and mcause
logic [31:0] exc_target_addr;
always_comb
begin
    exc_target_addr = '0;

    case (mtvec_i.mode)
        MTVEC_DIRECT: exc_target_addr = {mtvec_i.base, 2'b00};
        MTVEC_VECTORED: exc_target_addr = {mtvec_i.base + mcause_i.trap_code, 2'b00};
        default:;
    endcase
end

// determine the new pc
always_comb
begin
    new_pc = '0;
    unique case (pc_sel_i)
        PC_JUMP: new_pc = branch_target_i;
        PC_MEPC: new_pc = csr_mepc_i;
        PC_TRAP: new_pc = exc_target_addr;
        default:;
    endcase
end

// fetch state machine
enum {BOOT, REQUESTING, WAIT_ZERO_OUTSTANDING, STALLED} current_state, next_state;

// next state logic
always_ff @(posedge clk_i)
    if (!rstn_i) current_state <= BOOT;
    else current_state <= next_state;

always_comb
begin : pfetch_sm
    next_state = current_state;

    cyc = '0;
    stb = '0;
    valid_o = '0;
    raddr_d = raddr_q;
    present_buffer = '0;
    instr_buffer_d = instr_buffer_q;

    unique case (current_state)
        BOOT:
        begin
            raddr_d = BOOT_PC;
            next_state = REQUESTING;
        end

        REQUESTING:
        begin
            cyc = 1'b1;
            stb = 1'b1;

            if (wb_if.ack)
                valid_o = 1'b1;

            // if wishbone can't take requests anymore, keep the current request asserted
            if (wb_if.stall)
                raddr_d = raddr_q;
            else
                raddr_d = raddr_q + 4;

            if (flush_i)
            begin
                raddr_d = arch_pc_q + 4; // re-fetch the pc after the pc_o
                next_state = WAIT_ZERO_OUTSTANDING;
            end
            else if (stall_i)
            begin
                raddr_d = arch_pc_q + 4;
                next_state = STALLED;
                instr_buffer_d = wb_if.rdata; // save it
            end
        end

        WAIT_ZERO_OUTSTANDING:
        begin
            cyc = 1'b1;

            // wait for any outstanding transaction to finish
            // then restart the pipeline

            if (out_acks_q == '0 && !flush_i && !stall_i)
                next_state = REQUESTING;
        end

        STALLED:
        begin
            cyc = 1'b1;

            valid_o = 1'b1;
            present_buffer = 1'b1;

            if (!stall_i)
                next_state = WAIT_ZERO_OUTSTANDING;
        end
    endcase

    if (new_pc_en_i)
    begin
        // logic that override the next_state logic
        // should respond to a new_pc_en request irrespective of the state we are currently in
        next_state = WAIT_ZERO_OUTSTANDING;
        raddr_d = new_pc;
    end
end

always_ff @(posedge clk_i)
begin
    if (!rstn_i)
    begin
        raddr_q <= '0;
        arch_pc_q <= '0;
        instr_buffer_q <= '0;
    end
    else
    begin
        raddr_q <= raddr_d;
        instr_buffer_q <= instr_buffer_d;

        if (!stall_i)
            arch_pc_q <= arch_pc_d;
    end
end

assign arch_pc_d = raddr_q;

// assign outputs
assign pc_o = arch_pc_q;

always_comb
begin
    instr_o = '0;

    if (present_buffer)
        instr_o = instr_buffer_q;
    else if (wb_if.ack)
        instr_o = wb_if.rdata;
end

// assign wishbone interface outputs
assign wb_if.cyc = cyc;
assign wb_if.stb = stb;
assign wb_if.addr = raddr_q;
assign wb_if.we = '0;
assign wb_if.sel = 4'hf;
assign wb_if.wdata = '0;

endmodule :simple_fetch