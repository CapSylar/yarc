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

    input wire stallE_i,
    input wire flushE_i,

    input wire stallM_i,
    input wire flushM_i,

    output logic csr_readM_o,
    output logic csr_writeM_o,

    input wire [31:0] csr_rdataM_i,
    output logic [31:0] csr_rdataW_o,
    output result_src_e result_srcW_o
);

localparam [31:0]            nop = 32'h00000013;                       // instruction for NOP

logic csr_readE;

// execute stage pipeline
flopenrc_type #(logic [31:0], nop) instructionE_pipe (clk_i, rstn_i, flushE_i, !stallE_i, instrD_i, instrE_o);
flopenrc #(1) csr_readD_pipe (clk_i, rstn_i, flushE_i, !stallE_i, csr_readD_i, csr_readE);
flopenrc_type #(exc_t, NO_SYS) sys_instrM_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, sys_instrE_i, sys_instrM_o);

// memory stage pipeline
flopenrc_type #(logic [31:0], nop) instructionM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, instrE_o, instrM_o);
// flopenrc #(32) rs1ValueD_pipe (clk_i, rstn_i, flushM_i, !stallM_i, rs1ValueE_i, rs1ValueM_o);
flopenrc #(1) csr_writeE_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_writeE_i, csr_writeM_o);
flopenrc #(1) csr_readE_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_readE, csr_readM_o);

result_src_e result_srcM;

// write back pipeline
flopenrc_type #(result_src_e, RESULT_ALU) result_srcM_pipe (clk_i, rstn_i, flushM_i, !stallM_i, result_srcE_i, result_srcM);
flopenrc_type #(result_src_e, nop) result_srcW_pipe (clk_i, rstn_i, flushM_i, !stallM_i, result_srcM, result_srcW_o);
flopenrc #(32) csr_rdataW_pipe (clk_i, rstn_i, flushM_i, !stallM_i, csr_rdataM_i, csr_rdataW_o);

endmodule

`default_nettype wire