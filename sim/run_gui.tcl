
global env
set TOP $env(SIM_TOP)
set CORE ${TOP}/yarc_platform_i/core_i

add wave sim:${CORE}/clk_i;
add wave sim:${CORE}/rstn_i;

# ---------------------------------------------------------
add wave -divider {FETCH}
add wave -color Gold sim:${CORE}/simple_fetch_i/valid_o;
add wave -color Gold sim:${CORE}/simple_fetch_i/instr_o;
add wave -color Gold sim:${CORE}/simple_fetch_i/pc_o;
add wave sim:${CORE}/simple_fetch_i/stall_i;
add wave sim:${CORE}/simple_fetch_i/new_pc_en_i;
add wave sim:${CORE}/simple_fetch_i/pc_sel_i;
add wave sim:${CORE}/simple_fetch_i/branch_target_i;
add wave sim:${CORE}/simple_fetch_i/csr_mepc_i;
add wave sim:${CORE}/simple_fetch_i/mcause_i;
add wave sim:${CORE}/simple_fetch_i/mtvec_i;

add wave sim:${CORE}/simple_fetch_i/raddr_o;
add wave sim:${CORE}/simple_fetch_i/rdata_i;
add wave sim:${CORE}/simple_fetch_i/current_state;
add wave sim:${CORE}/simple_fetch_i/next_state;
add wave sim:${CORE}/simple_fetch_i/exc_target_addr;

# ---------------------------------------------------------
add wave -divider {REGISTER FILE}
add wave sim:${CORE}/reg_file_i/regf;
add wave sim:${CORE}/reg_file_i/rs1_addr_i;
add wave sim:${CORE}/reg_file_i/rs2_addr_i;
add wave sim:${CORE}/reg_file_i/write_i;
add wave sim:${CORE}/reg_file_i/waddr_i;
add wave sim:${CORE}/reg_file_i/wdata_i;
add wave -color Gold sim:${CORE}/reg_file_i/rs1_data_o;
add wave -color Gold sim:${CORE}/reg_file_i/rs2_data_o;

# ---------------------------------------------------------
add wave -divider {CS REGISTERS}
add wave sim:${CORE}/cs_registers_i/csr_re_i;
add wave sim:${CORE}/cs_registers_i/csr_raddr;
add wave sim:${CORE}/cs_registers_i/csr_rdata_o;

add wave sim:${CORE}/cs_registers_i/csr_we_i;
add wave sim:${CORE}/cs_registers_i/csr_waddr;
add wave sim:${CORE}/cs_registers_i/csr_wdata_i;

add wave sim:${CORE}/cs_registers_i/csr_mepc_o;
add wave sim:${CORE}/cs_registers_i/csr_mtvec_o;
add wave sim:${CORE}/cs_registers_i/csr_mstatus_o;
add wave sim:${CORE}/cs_registers_i/irq_pending_o;

# ret, traps...
add wave sim:${CORE}/cs_registers_i/csr_mret_i;
add wave sim:${CORE}/cs_registers_i/is_trap_i;
add wave sim:${CORE}/cs_registers_i/mcause_i;
add wave sim:${CORE}/cs_registers_i/exc_pc_i;

# interrupts
add wave sim:${CORE}/cs_registers_i/irq_software_i;
add wave sim:${CORE}/cs_registers_i/irq_timer_i;
add wave sim:${CORE}/cs_registers_i/irq_external_i;

add wave sim:${CORE}/cs_registers_i/current_plvl_q;
add wave sim:${CORE}/cs_registers_i/current_plvl_d;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mstatus_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mstatus_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mstatus_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mscratch_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mscratch_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mscratch_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mepc_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mepc_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mepc_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mie_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mie_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mie_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mip_d;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mtvec_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mtvec_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mtvec_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcause_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcause_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcause_q;

add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcountinhibit_wen;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcountinhibit_d;
add wave -group {CSRs} sim:${CORE}/cs_registers_i/mcountinhibit_q;

add wave -group {Perf Counters} sim:${CORE}/cs_registers_i/mhpmcounter;
add wave -group {Perf Counters} sim:${CORE}/cs_registers_i/mhpmcounter_we;
add wave -group {Perf Counters} sim:${CORE}/cs_registers_i/mhpmcounterh_we;
add wave -group {Perf Counters} sim:${CORE}/cs_registers_i/mhpmcounter_incr;

# ---------------------------------------------------------
add wave -divider {DECODE}
add wave sim:${CORE}/decode_i/current_plvl_i;
add wave sim:${CORE}/decode_i/pc_i;
add wave sim:${CORE}/decode_i/instr_i;
add wave sim:${CORE}/decode_i/stall_i;
add wave sim:${CORE}/decode_i/flush_i;
add wave sim:${CORE}/decode_i/regf_rs1_addr_o;
add wave sim:${CORE}/decode_i/regf_rs2_addr_o;
add wave sim:${CORE}/decode_i/rs1_data_i;
add wave sim:${CORE}/decode_i/rs2_data_i;

add wave -color Gold sim:${CORE}/decode_i/pc_o;
add wave -color Gold sim:${CORE}/decode_i/rs1_data_o;
add wave -color Gold sim:${CORE}/decode_i/rs2_data_o;
add wave -color Gold sim:${CORE}/decode_i/imm_o;
add wave -color Gold sim:${CORE}/decode_i/csr_rdata_o;
add wave -color Gold sim:${CORE}/decode_i/alu_oper1_src_o;
add wave -color Gold sim:${CORE}/decode_i/alu_oper2_src_o;
add wave -color Gold sim:${CORE}/decode_i/bnj_oper_o;
add wave -color Gold sim:${CORE}/decode_i/alu_oper_o;
add wave -color Gold sim:${CORE}/decode_i/mem_oper_o;
add wave -color Gold sim:${CORE}/decode_i/csr_waddr_o;
add wave -color Gold sim:${CORE}/decode_i/csr_we_o;
add wave -color Gold sim:${CORE}/decode_i/wb_use_mem_o;
add wave -color Gold sim:${CORE}/decode_i/write_rd_o;
add wave -color Gold sim:${CORE}/decode_i/rd_addr_o;
add wave -color Gold sim:${CORE}/decode_i/rs1_addr_o;
add wave -color Gold sim:${CORE}/decode_i/rs2_addr_o;
add wave -color Turquoise sim:${CORE}/decode_i/trap_o;

# ---------------------------------------------------------
add wave -divider {EXECUTE}
add wave sim:${CORE}/execute_i/pc_i;
add wave sim:${CORE}/execute_i/rs1_data_i;
add wave sim:${CORE}/execute_i/rs2_data_i;
add wave sim:${CORE}/execute_i/imm_i;
add wave sim:${CORE}/execute_i/alu_oper1_src_i;
add wave sim:${CORE}/execute_i/alu_oper2_src_i;
add wave sim:${CORE}/execute_i/alu_oper_i;
add wave sim:${CORE}/execute_i/bnj_oper_i;
add wave sim:${CORE}/execute_i/is_csr_i;
add wave sim:${CORE}/execute_i/instr_valid_i;

add wave sim:${CORE}/execute_i/mem_oper_i;
add wave sim:${CORE}/execute_i/csr_waddr_i;
add wave sim:${CORE}/execute_i/csr_we_i;
add wave -color Turquoise sim:${CORE}/execute_i/trap_i;

add wave sim:${CORE}/execute_i/wb_use_mem_i;
add wave sim:${CORE}/execute_i/write_rd_i;
add wave sim:${CORE}/execute_i/rd_addr_i;

add wave sim:${CORE}/execute_i/new_pc_en_o;
add wave sim:${CORE}/execute_i/branch_target_o;

add wave -color Turquoise sim:${CORE}/execute_i/stall_i;
add wave -color Turquoise sim:${CORE}/execute_i/flush_i;

add wave -color Turquoise sim:${CORE}/execute_i/forward_ex_mem_rs1_i;
add wave -color Turquoise sim:${CORE}/execute_i/forward_ex_mem_rs2_i;
add wave -color Turquoise sim:${CORE}/execute_i/forward_ex_mem_data_i;
add wave -color Turquoise sim:${CORE}/execute_i/forward_mem_wb_rs1_i;
add wave -color Turquoise sim:${CORE}/execute_i/forward_mem_wb_rs2_i;
add wave -color Turquoise sim:${CORE}/execute_i/forward_mem_wb_data_i;

add wave -color Gold sim:${CORE}/execute_i/alu_result_o;
add wave -color Gold sim:${CORE}/execute_i/alu_oper2_o;
add wave -color Gold sim:${CORE}/execute_i/mem_oper_o;
add wave -color Gold sim:${CORE}/execute_i/csr_wdata_o;
add wave -color Gold sim:${CORE}/execute_i/csr_waddr_o;
add wave -color Gold sim:${CORE}/execute_i/csr_we_o;
add wave -color Gold sim:${CORE}/execute_i/is_csr_o;
add wave -color Turquoise sim:${CORE}/execute_i/trap_o;
add wave -color Gold sim:${CORE}/execute_i/pc_o;
add wave -color Gold sim:${CORE}/execute_i/instr_valid_o;

add wave -color Gold sim:${CORE}/execute_i/wb_use_mem_o;
add wave -color Gold sim:${CORE}/execute_i/write_rd_o;
add wave -color Gold sim:${CORE}/execute_i/rd_addr_o;

add wave sim:${CORE}/execute_i/operand1;
add wave sim:${CORE}/execute_i/operand2;
# ---------------------------------------------------------
add wave -divider {LSU}
add wave sim:${CORE}/lsu_i/alu_result_i;
add wave sim:${CORE}/lsu_i/alu_oper2_i;
add wave sim:${CORE}/lsu_i/mem_oper_i;
add wave sim:${CORE}/lsu_i/trap_i;
add wave sim:${CORE}/lsu_i/wb_use_mem_i;
add wave sim:${CORE}/lsu_i/write_rd_i;
add wave sim:${CORE}/lsu_i/rd_addr_i;

add wave sim:${CORE}/lsu_i/lsu_en_o;
add wave sim:${CORE}/lsu_i/lsu_addr_o;
add wave sim:${CORE}/lsu_i/lsu_read_o;
add wave sim:${CORE}/lsu_i/lsu_rdata_i;
add wave sim:${CORE}/lsu_i/lsu_wsel_byte_o;
add wave sim:${CORE}/lsu_i/lsu_wdata_o;

add wave sim:${CORE}/lsu_i/csr_wdata_o;
add wave sim:${CORE}/lsu_i/csr_waddr_o;
add wave sim:${CORE}/lsu_i/csr_we_o;

add wave -color Gold sim:${CORE}/lsu_i/wb_use_mem_o;
add wave -color Gold sim:${CORE}/lsu_i/write_rd_o;
add wave -color Gold sim:${CORE}/lsu_i/rd_addr_o;
add wave -color Gold sim:${CORE}/lsu_i/alu_result_o;
add wave -color Gold sim:${CORE}/lsu_i/dmem_rdata_o;
add wave -color Turquoise sim:${CORE}/lsu_i/trap_o;

# ---------------------------------------------------------
add wave -divider {WRITE BACK}
add wave sim:${CORE}/write_back_i/use_mem_i;
add wave sim:${CORE}/write_back_i/write_rd_i;
add wave sim:${CORE}/write_back_i/rd_addr_i;
add wave sim:${CORE}/write_back_i/alu_result_i;
add wave sim:${CORE}/write_back_i/dmem_rdata_i;

add wave -color Gold sim:${CORE}/write_back_i/regf_write_o;
add wave -color Gold sim:${CORE}/write_back_i/regf_waddr_o;
add wave -color Gold sim:${CORE}/write_back_i/regf_wdata_o;

# ---------------------------------------------------------
add wave -divider {CONTROLLER}
add wave -color Turquoise sim:${CORE}/controller_i/forward_ex_mem_rs1_o;
add wave -color Turquoise sim:${CORE}/controller_i/forward_ex_mem_rs2_o;
add wave -color Turquoise sim:${CORE}/controller_i/forward_ex_mem_data_o;
add wave -color Turquoise sim:${CORE}/controller_i/forward_mem_wb_rs1_o;
add wave -color Turquoise sim:${CORE}/controller_i/forward_mem_wb_rs2_o;
add wave -color Turquoise sim:${CORE}/controller_i/forward_mem_wb_data_o;
add wave -color Turquoise sim:${CORE}/controller_i/id_ex_flush_o;
add wave -color Turquoise sim:${CORE}/controller_i/id_ex_stall_o;
add wave -color Turquoise sim:${CORE}/controller_i/if_id_stall_o;
add wave -color Turquoise sim:${CORE}/controller_i/if_id_flush_o;
add wave -color Turquoise sim:${CORE}/controller_i/ex_mem_flush_o;
add wave -color Turquoise sim:${CORE}/controller_i/ex_mem_stall_o;

add wave sim:${CORE}/controller_i/current_state;
add wave sim:${CORE}/controller_i/next_state;

add wave sim:${CORE}/controller_i/if_pc_i;
add wave sim:${CORE}/controller_i/if_id_instr_valid_i;
add wave sim:${CORE}/controller_i/if_id_pc_i;
add wave sim:${CORE}/controller_i/id_ex_instr_valid_i;
add wave sim:${CORE}/controller_i/id_ex_pc_i;
add wave sim:${CORE}/controller_i/ex_mem_instr_valid_i;
add wave sim:${CORE}/controller_i/ex_mem_pc_i;

add wave sim:${CORE}/controller_i/id_is_csr_i;
add wave sim:${CORE}/controller_i/ex_is_csr_i;
add wave sim:${CORE}/controller_i/mem_is_csr_i;

add wave sim:${CORE}/controller_i/new_pc_en_o;
add wave sim:${CORE}/controller_i/pc_sel_o;
add wave sim:${CORE}/controller_i/csr_mret_o;
add wave sim:${CORE}/controller_i/csr_mcause_o;
add wave sim:${CORE}/controller_i/is_trap_o;

# ------------------------Rest of TB signals-------------------------
add wave sim:*

# disable creation of the transcript file
transcript off
run -all