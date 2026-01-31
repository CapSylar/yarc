`default_nettype none

module lrsc
import core_pkg::*;
    (
        input wire clk_i,
        input wire rstn_i,

        input wire stallW_i,
        input wire flushW_i,

        input wire mem_oper_t mem_opM_i,
        input wire atomic_op_e atomic_opM_i,

        input wire [31:0] lsu_addr_i,

        output logic is_fail_scM_o,
        output logic is_fail_scW_o
    );

logic res_validM, res_validW;
logic [31:0] res_addrM, res_addrW;

wire is_lr = mem_opM_i.mem_rw[1] & atomic_opM_i == ATOMIC_LR;
wire is_sc = mem_opM_i.mem_rw[0] & atomic_opM_i == ATOMIC_LR;

wire store_addr_match;

assign store_addr_match = (lsu_addr_i == res_addrW);

always_comb begin
    res_validM = res_validW;

    unique case (1'b1)
        is_lr: res_validM = 1'b1;
        is_sc: res_validM = 1'b0;
        default:;
    endcase
end

assign res_addrM = is_lr ? lsu_addr_i : res_addrW;
assign is_fail_scM_o = is_sc & ~(store_addr_match & res_validW);

flopenrc #(32) res_addr_pipe  (clk_i, rstn_i, flushW_i, ~stallW_i, res_addrM, res_addrW);
flopenrc #(1) res_valid_pipe (clk_i, rstn_i, flushW_i, ~stallW_i, res_validM, res_validW);

flopenrc #(1) is_fail_sc_pipe (clk_i, rstn_i, flushW_i, ~stallW_i, is_fail_scM_o, is_fail_scW_o);

endmodule: lrsc

`default_nettype wire
