`default_nettype none

module datapath
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    input wire csr_readD_i,
    input wire csr_writeE_i,
    input var result_src_e result_srcE_i,

    input wire [31:0] instrD_i,

    output logic [31:0] instrE_o,
    input var exc_t sys_instrE_i,
    output logic [31:0] instrM_o,
    output exc_t sys_instrM_o,
    
    input wire mem_oper_t mem_opD_i,
    input wire atomic_op_e atomic_opD_i,

    output mem_oper_t mem_opE_o,
    output mem_oper_t mem_opM_o,
    output atomic_op_e atomic_opM_o,
    
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

logic csr_readE;
atomic_op_e atomic_opE;

// execute stage pipeline
flopenrc_type #(logic [31:0], NOP) instructionE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, instrD_i, instrE_o);
flopenrc #(1) csr_readD_pipe (clk_i, rstn_i, flushE_i, !stallE_i, csr_readD_i, csr_readE);
flopenrc_type #(mem_oper_t, '0) mem_opE_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, mem_opD_i, mem_opE_o);
flopenrc_type #(atomic_op_e, NO_ATOMIC) atomic_opE_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, atomic_opD_i, atomic_opE);

// memory stage pipeline
flopenrc_type #(exc_t, NO_SYS) sys_instrM_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, sys_instrE_i, sys_instrM_o); // FIXME: wrong flush* and stall* signals ? 
flopenrc_type #(logic [31:0], NOP) instructionM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, instrE_o, instrM_o);
flopenrc #(1) csr_writeE_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_writeE_i, csr_writeM_o);
flopenrc #(1) csr_readE_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_readE, csr_readM_o);
result_src_e result_srcM;
flopenrc_type #(result_src_e, RESULT_ALU) result_srcM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, result_srcE_i, result_srcM);
flopenrc_type #(mem_oper_t, '0) mem_opM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, mem_opE_o, mem_opM_o);
flopenrc_type #(atomic_op_e, NO_ATOMIC) atomic_opM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, atomic_opE, atomic_opM_o);

// write back pipeline
flopenrc_type #(result_src_e, RESULT_ALU) result_srcW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, result_srcM, result_srcW_o);
flopenrc #(32) csr_rdataW_pipe (clk_i, rstn_i, flushW_i, !stallW_i, csr_rdataM_i, csr_rdataW_o);

endmodule

`default_nettype wire
