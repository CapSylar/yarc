// dependancy and hazard detection unit
// TODO: document functionality

module controller
import riscv_pkg::*;
import csr_pkg::*;
(
    input clk_i,
    input rstn_i,

    // from IF
    input [31:0] if_pc_i,

    // ID stage
    input [4:0] rs1D_i,
    input [4:0] rs2D_i,
    input csr_readD_i,
    input csr_writeM_i,

    // ID/EX pipeline
    input [4:0] rs1E_i,
    input [4:0] rs2E_i,
    input [4:0] rdE_i,
    input id_ex_write_rd_i,
    input mem_oper_t id_ex_mem_oper_i,

    // EX stage
    input ex_new_pc_en_i,

    // from EX/MEM
    input [31:0] ex_mem_pc_i,
    input [4:0] rdM_i,
    input ex_mem_write_rd_i,
    input mem_oper_t ex_mem_mem_oper_i,
    input [31:0] ex_mem_alu_result_i,

    // from MEM/WB
    input [4:0] rdW_i,
    input mem_wb_write_rd_i,
    input mem_oper_t mem_wb_mem_oper_i,
    input [31:0] mem_wb_alu_result_i,
    input [31:0] mem_wb_lsu_rdata_i,
    input mem_stall_needed_i,
    input exc_t mem_trap_i,

    output logic [1:0] forward_rs1_o,
    output logic [1:0] forward_rs2_o,

    // forward from EX/MEM stage to EX stage
    output logic [31:0] forward_ex_mem_data_o,
    // forward from MEM/WB stage to EX stage
    output logic [31:0] forward_mem_wb_data_o,

    input if_id_instr_valid_i,
    input id_ex_instr_valid_i,
    input ex_mem_instr_valid_i,
    input mem_wb_instr_valid_i,

    // for interrupt handling
    input priv_lvl_e current_plvl_i,
    input var mstatus_t csr_mstatus_i,
    input var irqs_t irq_pending_i,

    // to fetch stage, to steer the pc
    output logic new_pc_en_o,
    output pc_sel_t pc_sel_o,

    // to cs registers
    output logic csr_mret_o,
    output mcause_t csr_mcause_o,
    output logic is_trap_o,
    output logic [31:0] exc_pc_o, // this will be saved in mepc

    // flush/stall to ID/EX
    output logic id_ex_flush_o,
    output logic id_ex_stall_o,

    // flush/stall to IF/EX
    output logic if_stall_o,
    output logic if_flush_o,

    // flush/stall to EX/MEM1
    output logic ex_mem_stall_o,
    output logic ex_mem_flush_o,

    // flush/stall to MEM2/WB
    output logic mem_wb_stall_o,
    output logic mem_wb_flush_o
);

// forwarding to the EX stage happens when we are writing to a register that is sourced
// by the instruction currently decoded, it will read a stale value in the decode stage

// we can't forward from the EX stage if the instruction will load from memory
// since the alu result is not the written value but the address to memory
wire ex_mem_forward_possible = (rs1E_i != 0) & (rs1E_i == rdM_i) & ex_mem_write_rd_i;
wire mem_wb_forward_possible = (rs1E_i != 0) & (rs1E_i === rdW_i) & mem_wb_write_rd_i;

// [0] forward from M stage, [1] forward from W stage
logic [1:0] forward_rs1;
logic [1:0] forward_rs2;
 
always_comb begin
    forward_rs1 = '0;
    forward_rs2 = '0;

    if (rs1E_i != 0) begin
        if ((rs1E_i == rdM_i) & ex_mem_write_rd_i) begin
            forward_rs1 = 2'b10;
        end else if ((rs1E_i == rdW_i) & mem_wb_write_rd_i) begin
            forward_rs1 = 2'b01;
        end

        if ((rs2E_i == rdM_i) & ex_mem_write_rd_i) begin
            forward_rs2 = 2'b10;
        end else if ((rs2E_i == rdW_i) & mem_wb_write_rd_i) begin
            forward_rs2 = 2'b01;
        end
    end
end

assign forward_rs1_o = forward_rs1;
assign forward_rs2_o = forward_rs2;

// Note: forwarding from the most recent stage takes priority
// consider this example where we could forward from EX/MEM and from MEM/WB
// add x3,x3,x4
// add x3,x3,x5
// add x3,x3,x4
// in this case all Rd is the same for the 3 instructions
// we must forward from the most recent stage which is EX/MEM
// since it contains the most up-to-date version of Rd

// data to be forwarded from EX/MEM1
assign forward_ex_mem_data_o = ex_mem_alu_result_i; // through here just for cleanliness

// 1- if the MEM stage loaded a value, we need this value to be forwarded not the alu result
// the alu result has been used as the address to load from in this case
// 2- if the MEM stage hasn't loaded, forward the alu result
// assign forward_mem2_wb_data_o = is_mem_oper_load(mem_wb_mem_oper_i) ? mem_wb_lsu_rdata_i : mem_wb_alu_result_i;
// data to be forwarded from MEM1/MEM2
assign forward_mem_wb_data_o = is_mem_oper_load(mem_wb_mem_oper_i) ? mem_wb_lsu_rdata_i
                                : mem_wb_alu_result_i; // through here just for cleanliness

// TODO: come on this doesn't belong here
logic csr_readE;
flopenrc #(1) execute_stage_pipe (clk_i, rstn_i, id_ex_flush_o, !id_ex_stall_o, csr_readD_i, csr_readE);

// Hazard Section

// handle use after load hazard
wire match_d_e = ((rs1D_i == rdE_i) | (rs2D_i == rdE_i)) & (rdE_i != 0);
wire mem_load_use_hzrd = is_mem_oper_load(id_ex_mem_oper_i) & match_d_e;
wire csr_load_use_hzrd = csr_readE & match_d_e;

// this is detected in the decode stage
wire load_use_hzrd = mem_load_use_hzrd | csr_load_use_hzrd;

// For now, the cpu always predicts that the branch is not taken and continues
// On a mispredict, flush the 2 instruction after the branch and continue from the new PC

// Instruction fetch is stalled on:
// 1- Load use hazard
// 2- There is a CSR instruction in the pipeline

// handle interrupts
logic interrupt_en;
logic handle_irq;
// Global interrupt enable or In U mode since MIE is a don't care in U mode
assign interrupt_en = csr_mstatus_i.mie || current_plvl_i == PRIV_LVL_U;
assign handle_irq = interrupt_en & |irq_pending_i;

// determine the IRQ code with the highest priority
logic [3:0] interrupt_code;
always_comb
begin
    interrupt_code = '0;
    unique case (1'b1)
        irq_pending_i.m_software: interrupt_code = CSR_MSI_BIT;
        irq_pending_i.m_timer: interrupt_code = CSR_MTI_BIT;
        irq_pending_i.m_external: interrupt_code = CSR_MEI_BIT;
        default:;
    endcase
end

// any instruction still in the pipeline ?
wire pipeline_empty = !(id_ex_instr_valid_i ||
                        ex_mem_instr_valid_i ||
                        mem_wb_instr_valid_i);

wire trap_happened = (mem_trap_i != NO_TRAP);
logic take_irq, take_exception;

enum
{
    DECODE,
    IRQ_WAIT // waiting for pipeline to clear to goto interrupt
} state, next;

// next state logic
always_ff @(posedge clk_i)
    if (!rstn_i) state <= DECODE;
    else state <= next;

always_comb
begin: core_sm
    next = state;
    take_irq = '0;

    unique case (state)
    DECODE:
    begin
        if (handle_irq)
            next = IRQ_WAIT;
    end
    IRQ_WAIT:
    begin
        /* when the pipeline is empty, we have to recheck the interrupt pending status.
        It is possible that when we stalled if and waited for the in-flight instructions
        to retire, that an interrupt disabling instruction was among them, in this case, we wasted
        time and need to restart the pipeline as if nothing happened */

        /* an in-flight instruction disabled interrupts or a trap happened */
        if (!handle_irq || trap_happened)
            next = DECODE;
        else if (pipeline_empty)
        begin
            take_irq = 1'b1;
            next = DECODE;
        end
    end
    endcase
end

always_comb
begin: if_steering
    is_trap_o = '0;
    new_pc_en_o = '0;
    pc_sel_o = PC_JUMP;
    csr_mret_o = '0;

    // for exceptions
    exc_pc_o = ex_mem_pc_i;
    csr_mcause_o = '{
        irq: 1'b0,
        trap_code: mem_trap_i[3:0]
    };

    if (take_exception) begin
        // MRET
        if (mem_trap_i == MRET)
        begin
            new_pc_en_o = 1'b1;
            pc_sel_o = PC_MEPC;
            csr_mret_o = 1'b1; // triggers needed changes in cs_registers
        end
        else // regular exception
        begin
            new_pc_en_o = 1'b1;
            pc_sel_o = PC_TRAP;
            is_trap_o = 1'b1;
        end
    end else if (take_irq) begin

        pc_sel_o = PC_TRAP;
        new_pc_en_o = 1'b1;
        is_trap_o = 1'b1;

        exc_pc_o = if_pc_i;
        csr_mcause_o = '{
            irq: 1'b1,
            trap_code: interrupt_code
        };
    end else if (ex_new_pc_en_i) begin // branch or jump taken
    
        new_pc_en_o = 1'b1; 
    end else if (csr_writeM_i) begin
        // any CSR write causes a pipeline flush
        new_pc_en_o = 1'b1;
        pc_sel_o = PC_CSRW;
    end
end

// if stage N needs to stall, then so does stage N-1 and so on
// if a stall is caused by MEM1 or MEM2 we have to stall WB as well, to preserve any forwarding that is happending to EX from WB or MEM2 or MEM1
assign take_exception = trap_happened;

wire flush_causeD = csr_writeM_i;
wire flush_causeE = trap_happened | ex_new_pc_en_i | csr_writeM_i;
wire flush_causeM = trap_happened | csr_writeM_i;

wire stall_causeD = ((state == IRQ_WAIT) | load_use_hzrd)& ~flush_causeD;
wire stall_causeE = 1'b0; // can't stall in EX for now
wire stall_causeM = mem_stall_needed_i & ~flush_causeM;

// this is done to preserve forwarding paths, stalling W when M is stalled incurrs no penalty
wire stall_causeW = mem_stall_needed_i;

// remember, if N is stalled, so is N-1
assign if_stall_o = stall_causeD | id_ex_stall_o; 
assign id_ex_stall_o = stall_causeE | ex_mem_stall_o;
assign ex_mem_stall_o = stall_causeM | mem_wb_stall_o;
assign mem_wb_stall_o = stall_causeW;

// if a series of stages are stalled, then the first stage that is not stalled must be flushed
// find the first stage that is not stalled

wire first_unstalledE = ~id_ex_stall_o & if_stall_o;
wire first_unstalledM = ~ex_mem_stall_o & id_ex_stall_o;
wire first_unstalledW = ~mem_wb_stall_o & ex_mem_stall_o;

// create the final flush lines

assign if_flush_o = flush_causeD;
assign id_ex_flush_o = flush_causeE | first_unstalledE;
assign ex_mem_flush_o = flush_causeM | first_unstalledM;
assign mem_wb_flush_o = first_unstalledW;

endmodule: controller
