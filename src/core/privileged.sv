`default_nettype none

module privileged
import riscv_pkg::*;
import csr_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    input wire stallM_i,

    input wire csr_readM_i,
    input wire csr_writeM_i,
    input wire [31:0] rs1ValueM_i,
    output wire [31:0] csr_rdataM_o,

    input wire [31:0] instructionM_i,

    // output some cs registers
    output logic [31:0] csr_mepc_o,
    output mtvec_t csr_mtvec_o,
    output mstatus_t csr_mstatus_o,
    output priv_lvl_e current_plvl_o,

    output irqs_t irq_pending_o,

    // mret, traps...
    input wire csr_mret_i,
    input wire is_trap_i,
    input var mcause_t mcause_i,
    input wire [31:0] exc_pc_i,
    // interrupts
    input wire irq_software_i,
    input wire irq_timer_i,
    input wire irq_external_i,

    // used by the performance counters
    input wire instr_ret_i
);

logic [11:0] csr_addressM;
// continue decoding the csr instruction
wire [31:0] csr_operandM = instructionM_i[14] ? 32'(instructionM_i[19:15]) : rs1ValueM_i ; // immediate or rs1;

logic [31:0] csr_to_writeM;

always_comb begin
    csr_to_writeM = '0;

    unique case (system_opc_t'(instructionM_i[14:12]))
        CSRRW, CSRRWI:
            csr_to_writeM = csr_operandM;
        CSRRS, CSRRSI:
            csr_to_writeM = csr_rdataM_o | csr_operandM;
        CSRRC, CSRRCI:
            csr_to_writeM = csr_rdataM_o & ~csr_operandM;
        default:;
    endcase
end

assign csr_addressM = instructionM_i[31:20];

wire csr_write_gatedM = csr_writeM_i & ~stallM_i;

// CS Register file
cs_registers cs_registers_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // read port
    .csr_re_i(csr_readM_i),
    .csr_raddr_i(csr_addressM),
    .csr_rdata_o(csr_rdataM_o),

    // write port
    .csr_we_i(csr_write_gatedM),
    .csr_waddr_i(csr_addressM),
    .csr_wdata_i(csr_to_writeM),

    // output some cs registers
    .csr_mepc_o(csr_mepc_o),
    .csr_mtvec_o(csr_mtvec_o),
    .csr_mstatus_o(csr_mstatus_o),
    .current_plvl_o(current_plvl_o),

    .irq_pending_o(irq_pending_o),

    // mret, traps...
    .csr_mret_i(csr_mret_i),
    .is_trap_i(is_trap_i),
    .mcause_i(mcause_i),
    .exc_pc_i(exc_pc_i),
    // interrupts
    .irq_software_i('0),
    .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),

    // used by the performance counters
    // .instr_ret_i(mem_wb_instr_valid && !mem_wb_stall)
    .instr_ret_i(1'b0)
);

endmodule

`default_nettype wire
