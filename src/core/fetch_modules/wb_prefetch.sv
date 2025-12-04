// A fetch module implementing the pipelined wishbone bus protocol to fetch instructions
// contains a fifo separating the fetching process from the processor interface

module wb_prefetch
import riscv_pkg::*;
import csr_pkg::*;
#(parameter bit [31:0] BOOT_PC = 'h8000_0000,
  parameter unsigned INSTR_BUFFER_SIZE_POT = 3) // POT = power of two
(
    input clk_i,
    input rstn_i,

    // fetch <-> wb interface
    wishbone_if.MASTER wb_if,

    // fetch <-> cpu interface
    output logic valid_o, // a valid instruction is presented
    output logic [31:0] instr_o, // the instruction, only valid when valid_o = 1
    output logic [31:0] pc_o, // program counter of the instruction presented to the cpu

    /* the cpu is currently stalled and has not accepted the instruction (if any) presented
    by the fetch unit  */
    input stall_i,

    /* the fetch unit flushes its state and refetches everything again */
    input flush_cache_i,

    /* new_pc_en_i is asserted on a branch/jump */
    input new_pc_en_i,
    input pc_sel_t pc_sel_i,

    // target addresses
    input [31:0] branch_target_i,
    input [31:0] csr_mepc_i,
    input [31:0] pcE_i,
    input var mtvec_t mtvec_i
);

logic stb;
logic [31:0] new_pc;
logic [31:0] exc_target_addr;
logic [31:0] arch_pc_q, arch_pc_d;
logic [31:0] fetch_pc_q, fetch_pc_d;

logic ff_wr, ff_rd ,ff_clear;
logic ff_full, ff_empty;
logic [INSTR_BUFFER_SIZE_POT:0] ff_fill_count;
logic [31:0] ff_rdata;

/* Number of useful request that we are waiting for, total number of pending request = req_pending_q + acks_to_ignore_q*/
logic [INSTR_BUFFER_SIZE_POT:0] req_pending_q, req_pending_d;

/* due to WB not having an abort line, if we did N request and now new_pc_en_i comes in and all the
made request are garbage, we can't just drop the current request and restart anew, we need to ignore the 
next N acks */
logic [INSTR_BUFFER_SIZE_POT:0] acks_to_ignore_q, acks_to_ignore_d;

wire [INSTR_BUFFER_SIZE_POT:0] max_ff_count = {1'b1, {(INSTR_BUFFER_SIZE_POT){1'b0}}};

wire wb_req_ok = stb && wb_if.cyc && !wb_if.stall; // wishbone request accepted by the slave

// instruction buffer fifo
sync_fifo
#(.BW(32), .FF_SIZE_POT(INSTR_BUFFER_SIZE_POT))
sync_fifo_i
(
    .clk_i(clk_i),
    .rstn_i(!ff_clear & rstn_i),

    // write port
    .wr_i(ff_wr),
    .data_i(wb_if.rdata),

    // read port
    .rd_i(ff_rd),
    .data_o(ff_rdata),

    // status
    .full_o(ff_full),
    .empty_o(ff_empty),
    .fill_count_o(ff_fill_count)
);

// calculate the expection target address from mtvec and mcause
always_comb
begin
    exc_target_addr = '0;
    unique case (mtvec_i.mode)
        MTVEC_DIRECT: exc_target_addr = {mtvec_i.base, 2'b00};

        // FIXME: doesn't work
        MTVEC_VECTORED: exc_target_addr = {mtvec_i.base + 30'(1'b0), 2'b00};
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
        PC_CSRW: new_pc = pcE_i;
        default:;
    endcase
end

// fifo has reached max elements minus one
wire ff_one_till_full = (req_pending_q + ff_fill_count == (max_ff_count-1));

enum {BOOT, REQUESTING, BUFFER_FULL} state, next;
always_ff @(posedge clk_i)
    if (!rstn_i) state <= BOOT;
    else         state <= next;

// wishbone fetch state machine
always_comb
begin: wb_sm
    next = state;
    
    fetch_pc_d = fetch_pc_q;

    stb = '0;

    unique case (state)
        BOOT:
        begin
            fetch_pc_d = BOOT_PC;
            next = REQUESTING;
        end
        REQUESTING:
        begin
            stb = 1'b1;

            if (new_pc_en_i)
                fetch_pc_d = new_pc;
            else if (!wb_if.stall) // keep the same requesting pc in this case
                fetch_pc_d = fetch_pc_d + 4;

            // only issue requests whose responses we have a place to store
            // else, we have to stop issuing requests
            if (ff_one_till_full && wb_req_ok && !ff_clear && !ff_rd)
                next = BUFFER_FULL;
        end
        BUFFER_FULL:
        begin
            if (new_pc_en_i)
                fetch_pc_d = new_pc;
            // no request here, wait for some fifo space to clear up
            if (ff_rd || ff_clear)
                next = REQUESTING;
        end
        default:;
    endcase
end

always_ff @(posedge clk_i)
begin
    if (!rstn_i)
    begin
        fetch_pc_q <= BOOT_PC;
    end
    else
    begin
        fetch_pc_q <= fetch_pc_d;
    end
end

assign ff_wr = wb_if.ack & (acks_to_ignore_q == '0);
assign ff_clear = new_pc_en_i | flush_cache_i;

always_comb
begin
    acks_to_ignore_d = acks_to_ignore_q;
    req_pending_d = req_pending_q;

    // handle the req_pending & acks_to_ignore counters
    if (wb_if.ack)
    begin
        if (acks_to_ignore_d != '0)
            acks_to_ignore_d = acks_to_ignore_d - 1;
        else
            req_pending_d = req_pending_d - 1;
    end
    
    if (wb_req_ok) // requesting
    begin
        req_pending_d = req_pending_d + 1;
    end

    if (new_pc_en_i)
    begin
        acks_to_ignore_d = req_pending_d;
        req_pending_d = '0;
    end
end

always_ff @(posedge clk_i)
begin
    if (!rstn_i)
    begin
        acks_to_ignore_q <= '0;
        req_pending_q <= '0;
    end
    else
    begin
        acks_to_ignore_q <= acks_to_ignore_d;
        req_pending_q <= req_pending_d;
    end
end

assign valid_o = ~ff_empty;

// cpu interface logic
always_comb
begin
    ff_rd = '0;
    arch_pc_d = arch_pc_q;

    if (valid_o && !stall_i) // the cpu has accepted the instruction presented
    begin
        ff_rd = 1'b1;
        arch_pc_d = arch_pc_q + 4;
    end

    if (new_pc_en_i)
    begin
        arch_pc_d = new_pc;
    end
end

always_ff @(posedge clk_i)
begin
    if (!rstn_i)
    begin
        arch_pc_q <= BOOT_PC;
    end
    else
    begin
        arch_pc_q <= arch_pc_d;
    end
end

assign pc_o = arch_pc_q;
assign instr_o = ff_rdata;

// assign wishbone interface outputs
assign wb_if.cyc = (state == REQUESTING) | (acks_to_ignore_q != '0) | (req_pending_q != 0);
assign wb_if.stb = stb;
assign wb_if.addr = fetch_pc_q[31:2];
assign wb_if.we = '0;
assign wb_if.sel = 4'hf;
assign wb_if.wdata = '0;

endmodule: wb_prefetch
