// write_back module

module write_back
import riscv_pkg::*;
(
    input clk_i,
    input rstn_i,
 
    // from MEM/WB
    input write_rd_i,
    input var result_src_e result_srcW_i,
    input [4:0] rd_addr_i,
    input [31:0] alu_result_i,
    input [31:0] lsu_rdata_i,
    input [31:0] csr_rdata_i,

    // WB -> Register file
    output logic regf_write_o,
    output logic [4:0] regf_waddr_o,
    output logic [31:0] regf_wdata_o
);

// assign outputs
assign regf_write_o = write_rd_i;
assign regf_waddr_o = rd_addr_i;

mux3 #(32) wb_data_mux (
    alu_result_i,
    lsu_rdata_i,
    csr_rdata_i,
    result_srcW_i,
    regf_wdata_o
);

endmodule: write_back