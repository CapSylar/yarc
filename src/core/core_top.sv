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
    input irq_timer_i,
    input irq_external_i
);

// Signal definitions

// Driven by the Fetch stage
logic if_instr_valid;
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
mstatus_t csr_mstatus;
irqs_t irq_pending;

// Driven by the Decode stage
logic [4:0] rs1_addr, rs2_addr;
logic csr_readD;
logic [31:0] pcE, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
alu_oper1_src_t id_ex_alu_oper1_src;
alu_oper2_src_t id_ex_alu_oper2_src;
bnj_oper_t id_ex_bnj_oper;
logic id_ex_instr_valid;
logic illegal_instrD;
alu_oper_t id_ex_alu_oper;
mem_oper_t id_ex_mem_oper;
logic csr_writeE;
logic id_ex_write_rd;
result_src_e result_srcE, result_srcW;
logic [4:0] id_ex_rd_addr;
logic [4:0] id_ex_rs1_addr;
logic [4:0] id_ex_rs2_addr;
exc_t sys_instrE;
exc_t sys_instrM;
logic load_misaligned_trapM;
logic store_misaligned_trapM;
logic take_irqM;

// Driven by the Ex stage
logic [31:0] alu_resultM;
logic [31:0] ex_mem1_alu_oper2;
mem_oper_t ex_mem1_mem_oper;
logic ex_mem1_write_rd;
logic [4:0] ex_mem1_rd_addr;
logic [31:0] branch_target;
logic ex_new_pc_en;
logic [31:0] ex_mem1_pc;
logic ex_mem_instr_valid;
logic trapM;

// Driven by the Mem stage
logic lsu_req;
logic lsu_we;
logic [31:0] lsu_addr;
logic lsu_req_done;
logic [31:0] lsu_rdata;
logic [3:0] lsu_wsel_byte;
logic [31:0] lsu_wdata;
logic [31:0] rs1ValueM;
logic csr_writeM, csr_readM;

// Driven by the WB stage
logic mem_wb_write_rd;
logic mem_wb_instr_valid;
logic [4:0] mem_wb_rd_addr;
logic [31:0] mem_wb_alu_result;
logic [31:0] mem_wb_lsu_rdata;
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
logic if_stall;
logic if_flush;
logic flushE;
logic stallE;
logic ex_mem_flush;
logic ex_mem_stall;
logic stallW;
logic flushW;
logic new_pc_en;
pc_sel_t pc_sel;

// FIXME: MRET most probably does not work properly
logic is_mret = '0;
logic [31:0] exc_pc;

// Fetch Stage
wb_prefetch wb_prefetch_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // IMEM Wishbone interface
    .wb_if(instr_fetch_wb_if),

    .valid_o(if_instr_valid),
    .instr_o(instrD),
    .pc_o(pcD),

    .stall_i(if_stall),
    .flush_cache_i(if_flush),

    // target addresses
    .branch_target_i(branch_target),
    .csr_mepc_i(csr_mepc),
    .mtvec_i(csr_mtvec),
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
    
    .stallE_i(stallE),
    .flushE_i(flushE),

    .stallM_i(ex_mem_stall),
    .flushM_i(ex_mem_flush),

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

    .stallM_i(ex_mem_stall),
    .flushM_i(ex_mem_flush),

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

    .irq_pending_o(irq_pending),

    // trap inputs
    .sys_instrM_i(sys_instrM),
    .load_misaligned_trapM_i(load_misaligned_trapM),
    .store_misaligned_trapM_i(store_misaligned_trapM),
    .illegal_instrD_i(illegal_instrD),
    .take_irq_i(take_irqM),

    // mret, traps...
    .csr_mret_i(is_mret),
    .exc_pc_i(exc_pc),
    // interrupts
    .irq_software_i('0),
    .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),
    .irq_pending_i(irq_pending),

    // used by the performance counters
    .instr_ret_i(mem_wb_instr_valid && !stallW),

    .trapM_o(trapM)
);

// Decode Stage
decode decode_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .instr_valid_i(if_instr_valid),

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
    .pc_i(pcD), // pc of the instruction

    // ID/EX pipeline registers ************************************************

    // feedback into the pipeline register
    .stall_i(stallE), // keep the same content in the registers
    .flush_i(flushE), // zero the register contents

    // for direct use by the EX stage
    .pc_o(pcE), // forwarded from IF/ID
    .rs1_data_o(id_ex_rs1_data),
    .rs2_data_o(id_ex_rs2_data),
    .imm_o(id_ex_imm),
    .alu_oper1_src_o(id_ex_alu_oper1_src),
    .alu_oper2_src_o(id_ex_alu_oper2_src),
    .bnj_oper_o(id_ex_bnj_oper),
    .alu_oper_o(id_ex_alu_oper),
    .instr_valid_o(id_ex_instr_valid),

    // traps genererated by this block
    .illegal_instrD_o(illegal_instrD),

    // for the MEM stage
    .mem_oper_o(id_ex_mem_oper),
    // .csr_waddr_o(id_ex_csr_waddr),
    .csr_we_o(csr_writeE),

    // for the WB stage
    .write_rd_o(id_ex_write_rd),
    .result_srcE_o(result_srcE),
    .rd_addr_o(id_ex_rd_addr),

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
    .instr_valid_i(id_ex_instr_valid),
    .mem_oper_i(id_ex_mem_oper),

    // forward to the WB stage
    .write_rd_i(id_ex_write_rd),
    .rd_addr_i(id_ex_rd_addr),

    // EX/MEM pipeline registers
    .rs1ValueM_o(rs1ValueM),
    
    // feedback into the pipeline register
    .stall_i(ex_mem_stall), // keep the same content in the registers
    .flush_i(ex_mem_flush), // zero the register contents

    .alu_result_o(alu_resultM),
    .alu_oper2_o(ex_mem1_alu_oper2),
    .mem_oper_o(ex_mem1_mem_oper),
    // .is_csr_o(ex_mem_is_csr),
    .pc_o(ex_mem1_pc),
    .instr_valid_o(ex_mem_instr_valid),

    // for WB stage exclusively
    .write_rd_o(ex_mem1_write_rd),
    .rd_addr_o(ex_mem1_rd_addr),

    // branches and jumps
    .new_pc_en_o(ex_new_pc_en),
    .branch_target_o(branch_target),

    // from forwarding logic
    .forward_rs1_i(forward_rs1),
    .forward_rs2_i(forward_rs2),

    .forward_ex_mem_data_i(forward_ex_mem_data),
    .forward_mem_wb_data_i(forward_mem_wb_data)
);

// MEM1 Stage (Setting up Memory request
stage_mem1 stage_mem1_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // MEM1 <-> LSU
    // read port
    .lsu_req_o(lsu_req),
    .lsu_addr_o(lsu_addr),
    .lsu_we_o(lsu_we),
    // write port
    .lsu_wsel_byte_o(lsu_wsel_byte),
    .lsu_wdata_o(lsu_wdata),
    .lsu_req_done_i(lsu_req_done),
    .lsu_rdata_i(lsu_rdata),

    // from EX/MEM
    .alu_result_i(alu_resultM),
    .alu_oper2_i(ex_mem1_alu_oper2),
    .mem_oper_i(ex_mem1_mem_oper),

    .instr_valid_i(ex_mem_instr_valid),
    .trapM_i(trapM),

    // for WB stage exclusively
    .write_rd_i(ex_mem1_write_rd),
    .rd_addr_i(ex_mem1_rd_addr),

    // MEM/WB pipeline registers
    .instr_valid_o(mem_wb_instr_valid),
    .write_rd_o(mem_wb_write_rd),
    .rd_addr_o(mem_wb_rd_addr),
    .alu_result_o(mem_wb_alu_result),
    .lsu_rdata_o(mem_wb_lsu_rdata),

    .lsu_stall_m_o(mem_stall_needed),
    .load_misaligned_trapM_o(load_misaligned_trapM),
    .store_misaligned_trapM_o(store_misaligned_trapM),

    .stall_i(stallW),
    .flush_i(flushW)
);

// Load Store Unit
lsu lsu_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // <-> Data Port
    .wb_if(lsu_wb_if),

    // <-> LSU unit
    .req_i(lsu_req),
    .we_i(lsu_we),
    .addr_i(lsu_addr),
    .wsel_byte_i(lsu_wsel_byte),
    .wdata_i(lsu_wdata),

    .req_done_o(lsu_req_done),
    .rdata_o(lsu_rdata),
    .req_stall_o()
);

// Write-back Stage
write_back write_back_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from MEM/WB
    .result_srcW_i(result_srcW),
    .write_rd_i(mem_wb_write_rd),
    .rd_addr_i(mem_wb_rd_addr),
    .alu_result_i(mem_wb_alu_result),
    .lsu_rdata_i(mem_wb_lsu_rdata),
    .csr_rdata_i(csr_rdataW),

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

    // from IF
    .if_pc_i(pcD),

    // from ID stage
    .rs1D_i(rs1_addr),
    .rs2D_i(rs2_addr),
    .csr_readD_i(csr_readD),
    .csr_writeM_i(csr_writeM),

    // from ID/EX pipeline
    .rs1E_i(id_ex_rs1_addr),
    .rs2E_i(id_ex_rs2_addr),
    .rdE_i(id_ex_rd_addr),
    .id_ex_write_rd_i(id_ex_write_rd),
    .id_ex_mem_oper_i(id_ex_mem_oper),

    // from EX stage
    .ex_new_pc_en_i(ex_new_pc_en),

    // from EX/MEM
    .ex_mem_pc_i(ex_mem1_pc),
    .rdM_i(ex_mem1_rd_addr),
    .ex_mem_write_rd_i(ex_mem1_write_rd),
    .ex_mem_mem_oper_i(ex_mem1_mem_oper),
    .ex_mem_alu_result_i(alu_resultM),

    // from MEM/WB
    .rdW_i(mem_wb_rd_addr),
    .mem_wb_write_rd_i(mem_wb_write_rd),
    .rdvalueW_i(rdValueW),
    .mem_stall_needed_i(mem_stall_needed),
    .trapM_i(trapM),
    .sys_instrM_i(sys_instrM),

    // forwarding control signals
    .forward_rs1_o(forward_rs1),
    .forward_rs2_o(forward_rs2),

    .forward_ex_mem_data_o(forward_ex_mem_data),
    .forward_mem_wb_data_o(forward_mem_wb_data),

    .if_id_instr_valid_i(if_instr_valid),
    .id_ex_instr_valid_i(id_ex_instr_valid),
    .ex_mem_instr_valid_i(ex_mem_instr_valid),
    .mem_wb_instr_valid_i(mem_wb_instr_valid),

    // to cs registers
    // .is_trap_o(is_trap),
    .take_irqM_o(take_irqM),
    .exc_pc_o(exc_pc),

    // for interrupt handling
    .current_plvl_i(current_plvl),
    .csr_mstatus_i(csr_mstatus),
    .irq_pending_i(irq_pending),

    // to fetch stage, to steer the pc
    .new_pc_en_o(new_pc_en),
    .pc_sel_o(pc_sel),

    // hazard lines to ID/EX
    .id_ex_flush_o(flushE),
    .id_ex_stall_o(stallE),

    // hazard lines to IF
    .if_stall_o(if_stall),
    .if_flush_o(if_flush),

    // flush/stall to EX/MEM1
    .ex_mem_stall_o(ex_mem_stall),
    .ex_mem_flush_o(ex_mem_flush),

    // flush/stall to MEM2/WB
    .mem_wb_stall_o(stallW),
    .mem_wb_flush_o(flushW)
);

endmodule : core_top