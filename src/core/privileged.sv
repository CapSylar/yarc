`default_nettype none

module privileged
import riscv_pkg::*;
import csr_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    input wire stallE_i,
    input wire flushE_i,

    input wire stallM_i,
    input wire flushM_i,

    input wire csr_readM_i,
    input wire csr_writeM_i,
    input wire [31:0] rs1ValueM_i,
    output wire [31:0] csr_rdataM_o,

    input wire [31:0] instructionM_i,
    input wire [31:0] lsu_addrM_i,

    // output some cs registers
    output logic [31:0] csr_mepc_o,
    output mtvec_t csr_mtvec_o,
    output mstatus_t csr_mstatus_o,
    output priv_lvl_e current_plvl_o,

    output irqs_t irq_pending_o,

    // trap inputs
    input var exc_t sys_instrM_i,
    input wire load_misaligned_trapM_i,
    input wire store_misaligned_trapM_i,
    input wire illegal_instrD_i,
    input wire take_irq_i,

    // mret, traps...
    input wire csr_mret_i,
    input wire [31:0] exc_pc_i,
    // interrupts
    input wire irq_software_i,
    input wire irq_timer_i,
    input wire irq_external_i,
    input var irqs_t irq_pending_i,

    // used by the performance counters
    input wire instr_ret_i,

    output logic trapM_o
);

/*
 * CSR instruction decoding and read and write values generation
 */

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

logic illegal_instrE, illegal_instrM;

// delay illegal instruction trap
flopenrc #(1) illegal_instrE_pipe (clk_i, rstn_i, flushE_i, ~stallE_i, illegal_instrD_i, illegal_instrE);
flopenrc #(1) illegal_instrM_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, illegal_instrE, illegal_instrM);

/*
 * generate the trap signal
 */

wire trapM = (sys_instrM_i != NO_SYS) | load_misaligned_trapM_i | store_misaligned_trapM_i | illegal_instrM | take_irq_i;

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

/*
 * determine mcause
 */
mcause_t next_mcause;

always_comb begin

    next_mcause = '{
        irq: 1'b0,
        trap_code: sys_instrM_i[3:0]
    };

    // TODO: unacceptable code quality
    if (load_misaligned_trapM_i) begin
        next_mcause.irq = 1'b0;
        next_mcause.trap_code = 4'd4; // load address misaligned
    end else if (store_misaligned_trapM_i) begin
        next_mcause.irq = 1'b0;
        next_mcause.trap_code = 4'd6; // store/AMO address misaligned
    end else if (illegal_instrM) begin
        next_mcause.irq = 1'b0;
        next_mcause.trap_code = 4'd2; // illegal instruction trap
    end else if (take_irq_i) begin
        next_mcause.irq = 1'b1;
        next_mcause.trap_code = interrupt_code;
    end
end

/*
* determine mtval
*/

logic [31:0] next_mtval;

always_comb begin

    next_mtval = '0;

    if (load_misaligned_trapM_i | store_misaligned_trapM_i) begin
        next_mtval = lsu_addrM_i; // faulting address
    end
end

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

    // write ports used for traps

    // mret, traps...
    .mret_i(csr_mret_i),
    .is_trap_i(trapM),

   .trap_mcause_i(next_mcause),
   .trap_mepc_i(exc_pc_i),
   .trap_mtval_i(next_mtval),

    // interrupts
    .irq_software_i('0),
    .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),

    // used by the performance counters
    .instr_ret_i(1'b0)
);

assign trapM_o = trapM;

endmodule

`default_nettype wire
