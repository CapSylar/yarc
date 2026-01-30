`default_nettype none

module datapath
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    input wire csr_readD_i,
    input wire csr_writeE_i,
    input var result_src_e result_srcE_i,

    input wire [31:0] pcD_i,
    output logic [31:0] pcE_o,
    output logic [31:0] pcM_o,

    input wire [31:0] instrD_i,

    output logic [31:0] instrE_o,
    input var sys_instr_t sys_instrE_i,
    output logic [31:0] instrM_o,
    output sys_instr_t sys_instrM_o,

    input var fence_t fenceE_i,
    output fence_t fenceM_o,
    
    input wire mem_oper_t mem_opD_i,
    input wire atomic_op_e atomic_opD_i,

    output mem_oper_t mem_opE_o,
    output mem_oper_t mem_opM_o,
    output atomic_op_e atomic_opE_o,
    output atomic_op_e atomic_opM_o,

    input wire write_rdD_i,
    output logic write_rdM_o,
    output logic write_rdW_o,

    input wire instr_validD_i,
    output logic instr_validE_o,
    output logic instr_validM_o,
    output logic instr_validW_o,

    input wire [4:0] rdD_i,
    output logic [4:0] rdE_o,
    output logic [4:0] rdM_o,
    output logic [4:0] rdW_o,
    
    input wire stallE_i,
    input wire flushE_i,

    input wire stallM_i,
    input wire flushM_i,

    input wire stallW_i,
    input wire flushW_i,

    output logic csr_readM_o,
    output logic csr_writeM_o,

    input wire [31:0] csr_rdataM_i,
    output logic [31:0] csr_rdataW_o,
    output result_src_e result_srcW_o
);

localparam [31:0]            NOP = 32'h00000013;                       // instruction for NOP

logic write_rdE;
logic csr_readE;

// execute stage pipeline
flopenrc_type #(logic [31:0], NOP) instructionE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, instrD_i, instrE_o);
flopenrc #(1) csr_readE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, csr_readD_i, csr_readE);
flopenrc #(1) instr_validE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, instr_validD_i, instr_validE_o);
flopenrc #(1) write_rdE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, write_rdD_i, write_rdE);
flopenrc #(5) rdE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, rdD_i, rdE_o);
flopenrc #(32) pcE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, pcD_i, pcE_o);
flopenrc_type #(mem_oper_t, '0) mem_opE_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, mem_opD_i, mem_opE_o);
flopenrc_type #(atomic_op_e, NO_ATOMIC) atomic_opE_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, atomic_opD_i, atomic_opE_o);

// memory stage pipeline
flopenrc_type #(sys_instr_t, NO_SYS) sys_instrM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, sys_instrE_i, sys_instrM_o); // FIXME: wrong flush* and stall* signals ? 
flopenrc_type #(logic [31:0], NOP) instructionM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, instrE_o, instrM_o);
flopenrc #(1) csr_writeE_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_writeE_i, csr_writeM_o);
flopenrc #(1) csr_readM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_readE, csr_readM_o);
flopenrc #(1) instr_validM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, instr_validE_o, instr_validM_o);
flopenrc #(1) write_rdM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, write_rdE, write_rdM_o);
flopenrc #(5) rdM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, rdE_o, rdM_o);
flopenrc #(32) pcM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, pcE_o, pcM_o);
result_src_e result_srcM;
flopenrc_type #(result_src_e, RESULT_ALU) result_srcM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, result_srcE_i, result_srcM);
flopenrc_type #(mem_oper_t, '0) mem_opM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, mem_opE_o, mem_opM_o);
flopenrc_type #(atomic_op_e, NO_ATOMIC) atomic_opM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, atomic_opE_o, atomic_opM_o);
flopenrc_type #(fence_t, NO_FENCE) fence_M_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, fenceE_i, fenceM_o);

// write back pipeline
flopenrc_type #(result_src_e, RESULT_ALU) result_srcW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, result_srcM, result_srcW_o);
flopenrc #(32) csr_rdataW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, csr_rdataM_i, csr_rdataW_o);
flopenrc #(1) instr_validW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, instr_validM_o, instr_validW_o);
flopenrc #(1) write_rdW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, write_rdM_o, write_rdW_o);
flopenrc #(5) rdW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, rdM_o, rdW_o);

endmodule

`default_nettype wire
