// write_back module

module write_back
import core_pkg::*;
(
    input clk_i,
    input rstn_i,
 
    // from MEM/WB
    input write_rd_i,
    input var result_src_e result_srcW_i,
    input [4:0] rdW_i,

    // result sources
    input [31:0] alu_result_i,
    input [31:0] lsu_rdata_i,
    input [31:0] csr_rdata_i,
    input [31:0] muldiv_resultW_i,
    input wire is_fail_scW_i,

    output [31:0] rdValueW_o,

    // WB -> Register file
    output logic regf_write_o,
    output logic [4:0] regf_waddr_o,
    output logic [31:0] regf_wdata_o
);

// assign outputs
assign regf_write_o = write_rd_i;
assign regf_waddr_o = rdW_i;

mux5 #(32) wb_data_mux (
    alu_result_i,
    lsu_rdata_i,
    csr_rdata_i,
    muldiv_resultW_i,
    32'(is_fail_scW_i),
    result_srcW_i,
    rdValueW_o
);

assign regf_wdata_o = rdValueW_o;

endmodule: write_back