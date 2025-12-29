/*
    2023-2024 with love
 __     __               _____                 _______          
 \ \   / /              / ____|               |__   __|         
  \ \_/ /_ _ _ __ ___  | |     ___  _ __ ___     | | ___  _ __  
   \   / _` | '__/ __| | |    / _ \| '__/ _ \    | |/ _ \| '_ \ 
    | | (_| | | | (__  | |___| (_) | | |  __/    | | (_) | |_) |
    |_|\__,_|_|  \___|  \_____\___/|_|  \___|    |_|\___/| .__/ 
                                                         | |    
                                                         |_|    
*/

module core_top
import riscv_pkg::*;
import csr_pkg::*;
(
    input clk_i,
    input rstn_i,

    // Core WB LSU interface
    wishbone_if.MASTER lsu_wb_if,
    // Core WB Instruction fetch interface
    wishbone_if.MASTER instr_fetch_wb_if,

    // interrupts
    input m_timer_interrupt_i,
    input m_software_interrupt_i,
    input m_external_interrupt_i
);

// Signal definitions

// Driven by the Fetch stage
logic instr_validD;
logic [31:0] instrD;
logic [31:0] instrE;
logic [31:0] instrM;
logic [31:0] pcD;

// Driven by the Register file
logic [31:0] rs1_data, rs2_data;

// Driven by the CS Register file
logic [31:0] csr_rdataM, csr_rdataW;
logic [31:0] csr_mepc;
priv_lvl_e current_plvl;
mtvec_t csr_mtvec;
mcause_t trap_mcauseM;
mstatus_t csr_mstatus;
irqs_t irq_pending;

// Driven by the Decode stage
logic [4:0] rs1_addr, rs2_addr;
logic csr_readD;
logic [31:0] pcE, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
alu_oper1_src_t id_ex_alu_oper1_src;
alu_oper2_src_t id_ex_alu_oper2_src;
bnj_oper_t id_ex_bnj_oper;
logic instr_validE;
logic is_muldiv_instrE;
logic illegal_instrD;
alu_oper_t id_ex_alu_oper;
mem_oper_t mem_opD;
atomic_op_e atomic_opD;
logic csr_writeE;
logic write_rdD;
result_src_e result_srcE, result_srcW;
logic [4:0] rdD;
logic [4:0] id_ex_rs1_addr;
logic [4:0] id_ex_rs2_addr;
exc_t sys_instrE;
exc_t sys_instrM;
logic load_misaligned_trapM;
logic store_misaligned_trapM;

// Driven by the Ex stage
logic [31:0] rs1_forwarded_valueE;
logic [31:0] rs2_forwarded_valueE;
logic [31:0] alu_resultM;
logic [31:0] ex_mem1_alu_oper2;
mem_oper_t mem_opE;
mem_oper_t mem_opM;
atomic_op_e atomic_opM;
atomic_op_e atomic_opE;
logic write_rdM;
logic [4:0] rdM;
logic [4:0] rdE;
logic [31:0] branch_targetE;
logic branch_takenE;
logic [31:0] pcM;
logic instr_validM;
logic trapM, mretM;

// Driven by the Mem stage
logic lsu_req;
logic lsu_we;
logic lsu_lock;
logic [31:0] lsu_addr;
logic lsu_req_done;
logic [31:0] lsu_rdata;
logic [3:0] lsu_sel;
logic [31:0] lsu_wdata;
logic [31:0] rs1ValueM;
logic csr_writeM, csr_readM;
logic [31:0] muldiv_resultW;

// Driven by the WB stage
logic write_rdW;
logic instr_validW;
logic [4:0] rdW;
logic [31:0] mem_wb_alu_result;
logic [31:0] mem_wb_lsu_rdata;
logic is_fail_scW;
logic mem_stall_needed;
logic [31:0] rdValueW;

// Driven by the Wb stage
logic regf_write;
logic [4:0] regf_waddr;
logic [31:0] regf_wdata;

// Driven by the Core Controller
logic [1:0] forward_rs1;
logic [1:0] forward_rs2;
logic [31:0] forward_ex_mem_data;
logic [31:0] forward_mem_wb_data;
logic stallD;
logic flushD;
logic flushE;
logic stallE;
logic flushM;
logic stallM;
logic mdu_busyE;
logic stallW;
logic flushW;
logic new_pc_en;
pc_sel_t pc_sel;

logic [31:0] exc_pc;

// Fetch Stage
wb_prefetch wb_prefetch_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // IMEM Wishbone interface
    .wb_if(instr_fetch_wb_if),

    .valid_o(instr_validD),
    .instr_o(instrD),
    .pc_o(pcD),

    .stall_i(stallD),
    .flush_cache_i(flushD),

    // target addresses
    .branch_target_i(branch_targetE),
    .csr_mepc_i(csr_mepc),
    .mtvec_i(csr_mtvec),
    .trap_mcauseM_i(trap_mcauseM),
    .pcE_i(pcE),

    .new_pc_en_i(new_pc_en),
    .pc_sel_i(pc_sel)
);

// Register file
reg_file reg_file_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // read port
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),

    .rs1_data_o(rs1_data),
    .rs2_data_o(rs2_data),

    // write port
    .write_i(regf_write),
    .waddr_i(regf_waddr),
    .wdata_i(regf_wdata)
);

datapath datapath_i (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .csr_readD_i(csr_readD),

    .csr_writeE_i(csr_writeE),
    .result_srcE_i(result_srcE),

    .pcD_i(pcD),
    .pcE_o(pcE),
    .pcM_o(pcM),

    .mem_opD_i(mem_opD),
    .atomic_opD_i(atomic_opD),

    .mem_opE_o(mem_opE),
    .mem_opM_o(mem_opM),
    .atomic_opE_o(atomic_opE),
    .atomic_opM_o(atomic_opM),

    .write_rdD_i(write_rdD),
    .write_rdM_o(write_rdM),
    .write_rdW_o(write_rdW),

    .instr_validD_i(instr_validD),
    .instr_validE_o(instr_validE),
    .instr_validM_o(instr_validM),
    .instr_validW_o(instr_validW),

    .rdD_i(rdD),
    .rdE_o(rdE),
    .rdM_o(rdM),
    .rdW_o(rdW),
    
    .stallE_i(stallE),
    .flushE_i(flushE),

    .stallM_i(stallM),
    .flushM_i(flushM),

    .stallW_i(stallW),
    .flushW_i(flushW),

    .instrD_i(instrD),
    .sys_instrE_i(sys_instrE),
    .instrE_o(instrE),
    .instrM_o(instrM),
    .sys_instrM_o(sys_instrM),

    .csr_readM_o(csr_readM),
    .csr_writeM_o(csr_writeM),

    .csr_rdataM_i(csr_rdataM),
    .csr_rdataW_o(csr_rdataW),
    .result_srcW_o(result_srcW)
);

privileged privileged_i 
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .stallE_i(stallE),
    .flushE_i(flushE),

    .stallM_i(stallM),
    .flushM_i(flushM),

    .stallW_i(stallW),

    .instr_validM_i(instr_validM),

    .csr_readM_i(csr_readM),
    .csr_writeM_i(csr_writeM),
    .rs1ValueM_i(rs1ValueM),
    .csr_rdataM_o(csr_rdataM),

    .instructionM_i(instrM),
    .lsu_addrM_i(alu_resultM),

    // output some cs registers
    .csr_mepc_o(csr_mepc),
    .csr_mtvec_o(csr_mtvec),
    .csr_mstatus_o(csr_mstatus),
    .current_plvl_o(current_plvl),
    .trap_mcauseM_o(trap_mcauseM),

    .irq_pending_o(irq_pending),

    // trap inputs
    .sys_instrM_i(sys_instrM),
    .load_misaligned_trapM_i(load_misaligned_trapM),
    .store_misaligned_trapM_i(store_misaligned_trapM),
    .illegal_instrD_i(illegal_instrD),

    // mret, traps...
    .exc_pc_i(exc_pc),
    // interrupts
    .m_timer_interrupt_i(m_timer_interrupt_i),
    .m_software_interrupt_i(m_software_interrupt_i),
    .m_external_interrupt_i(m_external_interrupt_i),

    // used by the performance counters
    .instr_ret_i(instr_validW && !stallW),

    .trapM_o(trapM),
    .mretM_o(mretM)
);

// Decode Stage
decode decode_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .instr_valid_i(instr_validD),

    // from csr unit
    .current_plvl_i(current_plvl),

    // register file <-> decode module
    // read port
    .regf_rs1_addr_o(rs1_addr),
    .regf_rs2_addr_o(rs2_addr),
    .rs1_data_i(rs1_data),
    .rs2_data_i(rs2_data),

    // csr unit <-> decode module
    // read port
    .csr_re_o(csr_readD),

    // from IF stage
    .instr_i(instrD), // instruction

    // ID/EX pipeline registers ************************************************

    // feedback into the pipeline register
    .stall_i(stallE), // keep the same content in the registers
    .flush_i(flushE), // zero the register contents

    // for direct use by the EX stage
    .rs1_data_o(id_ex_rs1_data),
    .rs2_data_o(id_ex_rs2_data),
    .imm_o(id_ex_imm),
    .alu_oper1_src_o(id_ex_alu_oper1_src),
    .alu_oper2_src_o(id_ex_alu_oper2_src),
    .bnj_oper_o(id_ex_bnj_oper),
    .alu_oper_o(id_ex_alu_oper),

    .is_muldiv_instrE_o(is_muldiv_instrE),

    // traps genererated by this block
    .illegal_instrD_o(illegal_instrD),

    // for the MEM stage
    .mem_opD_o(mem_opD),
    .atomic_opD_o(atomic_opD),
    // .csr_waddr_o(id_ex_csr_waddr),
    .csr_we_o(csr_writeE),

    // for the WB stage
    .write_rdD_o(write_rdD),
    .result_srcE_o(result_srcE),
    .rdD_o(rdD),

    // used by the hazard/forwarding logic
    .rs1_addr_o(id_ex_rs1_addr),
    .rs2_addr_o(id_ex_rs2_addr),

    .sys_instrE_o(sys_instrE)
);

// Execute Stage
execute execute_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from ID/EX
    .pc_i(pcE),
    .rs1_data_i(id_ex_rs1_data),
    .rs2_data_i(id_ex_rs2_data),
    .imm_i(id_ex_imm),
    .alu_oper1_src_i(id_ex_alu_oper1_src),
    .alu_oper2_src_i(id_ex_alu_oper2_src),
    .alu_oper_i(id_ex_alu_oper),
    .bnj_oper_i(id_ex_bnj_oper),
    .instrE_i(instrE),

    .rs1_forwarded_value_o(rs1_forwarded_valueE),
    .rs2_forwarded_value_o(rs2_forwarded_valueE),

    // EX/MEM pipeline registers
    .rs1ValueM_o(rs1ValueM),
    
    // feedback into the pipeline register
    .stallM_i(stallM), // keep the same content in the registers
    .flushM_i(flushM), // zero the register contents

    .alu_resultM_o(alu_resultM),
    .alu_oper2M_o(ex_mem1_alu_oper2),

    // branches and jumps
    .branch_takenE_o(branch_takenE),
    .branch_targetE_o(branch_targetE),

    // from forwarding logic
    .forward_rs1_i(forward_rs1),
    .forward_rs2_i(forward_rs2),

    .forward_ex_mem_data_i(forward_ex_mem_data),
    .forward_mem_wb_data_i(forward_mem_wb_data)
);

// multiply divide unit
mdu mdu_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .flushE_i(flushE),

    .stallM_i(stallM),
    .flushM_i(flushM),

    .mdu_busyE_o(mdu_busyE),

    .rs1_forwarded_value_i(rs1_forwarded_valueE),
    .rs2_forwarded_value_i(rs2_forwarded_valueE),

    .is_muldivE_i(is_muldiv_instrE),

    .instrE_i(instrE),
    .instrM_i(instrM),

    .resultW_o(muldiv_resultW)
);

// LSU 
lsu lsu_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // MEM1 <-> LSU
    // read port
    .lsu_req_o(lsu_req),
    .lsu_addr_o(lsu_addr),
    .lsu_we_o(lsu_we),
    .lsu_lock_o(lsu_lock),
    // write port
    .lsu_sel_o(lsu_sel),
    .lsu_wdata_o(lsu_wdata),
    .lsu_req_done_i(lsu_req_done),
    .lsu_rdata_i(lsu_rdata),

    // from EX/MEM
    .alu_result_i(alu_resultM),
    .alu_oper2_i(ex_mem1_alu_oper2),
    .mem_opM_i(mem_opM),
    .atomic_opM_i(atomic_opM),

    .trapM_i(trapM),
    .instrM_i(instrM),

    // MEM/WB pipeline registers
    .alu_result_o(mem_wb_alu_result),
    .lsu_rdata_o(mem_wb_lsu_rdata),
    .is_fail_scW_o(is_fail_scW),

    .lsu_stall_m_o(mem_stall_needed),
    .load_misaligned_trapM_o(load_misaligned_trapM),
    .store_misaligned_trapM_o(store_misaligned_trapM),

    .stallW_i(stallW),
    .flushW_i(flushW)
);

// Load Store Unit
wishbone_lsu_driver wishbone_lsu_driver_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // <-> Data Port
    .wb_if(lsu_wb_if),

    // <-> LSU unit
    .req_i(lsu_req),
    .we_i(lsu_we),
    .lock_i(lsu_lock),
    .addr_i(lsu_addr),
    .sel_byte_i(lsu_sel),
    .wdata_i(lsu_wdata),

    .req_done_o(lsu_req_done),
    .rdata_o(lsu_rdata)
);

// Write-back Stage
write_back write_back_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from MEM/WB
    .result_srcW_i(result_srcW),
    .write_rd_i(write_rdW),
    .rdW_i(rdW),
    .alu_result_i(mem_wb_alu_result),
    .lsu_rdata_i(mem_wb_lsu_rdata),
    .csr_rdata_i(csr_rdataW),
    .muldiv_resultW_i(muldiv_resultW),
    .is_fail_scW_i(is_fail_scW),

    .rdValueW_o(rdValueW),

    // WB -> Register file
    .regf_write_o(regf_write),
    .regf_waddr_o(regf_waddr),
    .regf_wdata_o(regf_wdata)
);

// Dependency detection unit
controller controller_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from ID stage
    .rs1D_i(rs1_addr),
    .rs2D_i(rs2_addr),
    .csr_readD_i(csr_readD),
    .csr_writeM_i(csr_writeM),

    // from ID/EX pipeline
    .rs1E_i(id_ex_rs1_addr),
    .rs2E_i(id_ex_rs2_addr),
    .rdE_i(rdE),
    .mem_operE_i(mem_opE),
    .atomic_opE_i(atomic_opE),
    .is_muldiv_instrE_i(is_muldiv_instrE),

    // from EX stage
    .branch_takenE_i(branch_takenE),

    // from EX/MEM
    .mdu_busyE_i(mdu_busyE),
    .pcM_i(pcM),
    .rdM_i(rdM),
    .write_rdM_i(write_rdM),
    .ex_mem_alu_result_i(alu_resultM),

    // from MEM/WB
    .rdW_i(rdW),
    .write_rdW_i(write_rdW),
    .rdvalueW_i(rdValueW),
    .mem_stall_needed_i(mem_stall_needed),
    .trapM_i(trapM),
    .mretM_i(mretM),

    // forwarding control signals
    .forward_rs1_o(forward_rs1),
    .forward_rs2_o(forward_rs2),

    .forward_ex_mem_data_o(forward_ex_mem_data),
    .forward_mem_wb_data_o(forward_mem_wb_data),

    // to cs registers
    .exc_pc_o(exc_pc),

    // to fetch stage, to steer the pc
    .new_pc_en_o(new_pc_en),
    .pc_sel_o(pc_sel),

    .stallD_o(stallD),
    .flushD_o(flushD),

    .flushE_o(flushE),
    .stallE_o(stallE),

    .stallM_o(stallM),
    .flushM_o(flushM),

    .stallW_o(stallW),
    .flushW_o(flushW)
);

endmodule : core_top