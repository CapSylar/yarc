// dependancy and hazard detection unit

module controller
import riscv_pkg::*;
import csr_pkg::*;
(
    input clk_i,
    input rstn_i,

    // ID stage
    input [4:0] rs1D_i,
    input [4:0] rs2D_i,
    input csr_readD_i,
    input csr_writeM_i,

    // ID/EX pipeline
    input [4:0] rs1E_i,
    input [4:0] rs2E_i,
    input [4:0] rdE_i,
    input var mem_oper_t mem_operE_i,
    input is_muldiv_instrE_i,

    // EX stage
    input ex_new_pc_en_i,

    // from EX/MEM
    input mdu_busyE_i,
    input [31:0] ex_mem_pc_i,
    input [4:0] rdM_i,
    input ex_mem_write_rd_i,
    input [31:0] ex_mem_alu_result_i,

    // from MEM/WB
    input [4:0] rdW_i,
    input mem_wb_write_rd_i,
    input [31:0] rdvalueW_i,
    input mem_stall_needed_i,
    input wire trapM_i,
    input wire mretM_i,

    output logic [1:0] forward_rs1_o,
    output logic [1:0] forward_rs2_o,

    // forward from EX/MEM stage to EX stage
    output logic [31:0] forward_ex_mem_data_o,
    // forward from MEM/WB stage to EX stage
    output logic [31:0] forward_mem_wb_data_o,


    // to fetch stage, to steer the pc
    output logic new_pc_en_o,
    output pc_sel_t pc_sel_o,

    // to cs registers
    output logic [31:0] exc_pc_o, // this will be saved in mepc

    // flush/stall to ID/EX
    output logic flushE_o,
    output logic stallE_o,

    // flush/stall to IF/EX
    output logic stallD_o,
    output logic flushD_o,

    // flush/stall to EX/MEM1
    output logic stallM_o,
    output logic flushM_o,

    // flush/stall to MEM2/WB
    output logic stallW_o,
    output logic flushW_o
);

// forwarding to the EX stage happens when we are writing to a register that is sourced
// by the instruction currently decoded, it will read a stale value in the decode stage

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
    end

    if (rs2E_i != 0) begin
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
assign forward_mem_wb_data_o = rdvalueW_i;

// TODO: come on this doesn't belong here
logic csr_readE;
flopenrc #(1) execute_stage_pipe (clk_i, rstn_i, flushE_o, !stallE_o, csr_readD_i, csr_readE);

// Hazard Section

// handle use after load hazard
wire match_d_e = ((rs1D_i == rdE_i) | (rs2D_i == rdE_i)) & (rdE_i != 0);
wire mem_load_use_hzrd = mem_operE_i.mem_rw[1] & match_d_e;
wire csr_load_use_hzrd = csr_readE & match_d_e;
wire mul_div_use_hzrd = is_muldiv_instrE_i & match_d_e;

// this is detected in the decode stage
wire load_use_hzrd = mem_load_use_hzrd | csr_load_use_hzrd | mul_div_use_hzrd;

always_comb
begin: if_steering
    new_pc_en_o = '0;
    pc_sel_o = PC_JUMP;

    // for exceptions
    exc_pc_o = ex_mem_pc_i;

    if (trapM_i) begin
        new_pc_en_o = 1'b1;
        pc_sel_o = PC_TRAP;
    end else if (mretM_i) begin
        new_pc_en_o = 1'b1;
        pc_sel_o = PC_MEPC;
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

wire flush_causeD = csr_writeM_i;
wire flush_causeE = trapM_i | mretM_i | ex_new_pc_en_i | csr_writeM_i;
wire flush_causeM = trapM_i | mretM_i | csr_writeM_i;
wire flush_causeW = trapM_i;

wire stall_causeD = load_use_hzrd & ~flush_causeD;
wire stall_causeE = mdu_busyE_i & ~flush_causeE;
wire stall_causeM = mem_stall_needed_i & ~flush_causeM;

// this is done to preserve forwarding paths, stalling W when M is stalled incurrs no penalty
wire stall_causeW = mem_stall_needed_i & ~flush_causeW;

// remember, if N is stalled, so is N-1
assign stallD_o = stall_causeD | stallE_o; 
assign stallE_o = stall_causeE | stallM_o;
assign stallM_o = stall_causeM | stallW_o;
assign stallW_o = stall_causeW;

// if a series of stages are stalled, then the first stage that is not stalled must be flushed
// find the first stage that is not stalled

wire first_unstalledE = ~stallE_o & stallD_o;
wire first_unstalledM = ~stallM_o & stallE_o;
wire first_unstalledW = ~stallW_o & stallM_o;

// create the final flush lines

assign flushD_o = flush_causeD;
assign flushE_o = flush_causeE | first_unstalledE;
assign flushM_o = flush_causeM | first_unstalledM;
assign flushW_o = flush_causeW | first_unstalledW;

endmodule: controller
