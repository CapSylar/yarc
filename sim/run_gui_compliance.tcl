
global env
set TOP sim:$env(SIM_TOP)
set CORE ${TOP}/core_i

add wave ${CORE}/clk_i;
add wave ${CORE}/rstn_i;

# ---------------------------------------------------------
add wave -divider {FETCH}
add wave -color Gold ${CORE}/wb_prefetch_i/valid_o;
add wave -color Gold ${CORE}/wb_prefetch_i/instr_o;
add wave -color Gold ${CORE}/wb_prefetch_i/pc_o;
add wave ${CORE}/wb_prefetch_i/stall_i;
add wave ${CORE}/wb_prefetch_i/flush_cache_i;
add wave ${CORE}/wb_prefetch_i/new_pc_en_i;
add wave ${CORE}/wb_prefetch_i/pc_sel_i;
add wave ${CORE}/wb_prefetch_i/branch_target_i;
add wave ${CORE}/wb_prefetch_i/csr_mepc_i;
add wave ${CORE}/wb_prefetch_i/mcause_i;
add wave ${CORE}/wb_prefetch_i/mtvec_i;

add wave -group {FETCH WISHBONE} -color Gold ${CORE}/wb_prefetch_i/wb_if/*;

add wave ${CORE}/wb_prefetch_i/state;
add wave ${CORE}/wb_prefetch_i/next;
add wave ${CORE}/wb_prefetch_i/fetch_pc_d;
add wave ${CORE}/wb_prefetch_i/fetch_pc_q;
add wave ${CORE}/wb_prefetch_i/arch_pc_d;
add wave ${CORE}/wb_prefetch_i/arch_pc_q;
add wave ${CORE}/wb_prefetch_i/exc_target_addr;

add wave ${CORE}/wb_prefetch_i/*;
add wave ${CORE}/wb_prefetch_i/sync_fifo_i/*;

# ---------------------------------------------------------
add wave -divider {REGISTER FILE}
add wave ${CORE}/reg_file_i/regf;
add wave ${CORE}/reg_file_i/rs1_addr_i;
add wave ${CORE}/reg_file_i/rs2_addr_i;
add wave ${CORE}/reg_file_i/write_i;
add wave ${CORE}/reg_file_i/waddr_i;
add wave ${CORE}/reg_file_i/wdata_i;
add wave -color Gold ${CORE}/reg_file_i/rs1_data_o;
add wave -color Gold ${CORE}/reg_file_i/rs2_data_o;

# ---------------------------------------------------------

set CS_REGISTERS_PATH ${CORE}/privileged_i/cs_registers_i;

add wave -divider {CS REGISTERS}
add wave ${CS_REGISTERS_PATH}/csr_re_i;
add wave ${CS_REGISTERS_PATH}/csr_raddr;
add wave ${CS_REGISTERS_PATH}/csr_rdata_o;

add wave ${CS_REGISTERS_PATH}/csr_we_i;
add wave ${CS_REGISTERS_PATH}/csr_waddr;
add wave ${CS_REGISTERS_PATH}/csr_wdata_i;

add wave ${CS_REGISTERS_PATH}/csr_mepc_o;
add wave ${CS_REGISTERS_PATH}/csr_mtvec_o;
add wave ${CS_REGISTERS_PATH}/csr_mstatus_o;
add wave ${CS_REGISTERS_PATH}/irq_pending_o;

# ret, traps...
add wave ${CS_REGISTERS_PATH}/is_trap_i;

# interrupts
add wave ${CS_REGISTERS_PATH}/irq_software_i;
add wave ${CS_REGISTERS_PATH}/irq_timer_i;
add wave ${CS_REGISTERS_PATH}/irq_external_i;

add wave ${CS_REGISTERS_PATH}/current_plvl_q;
add wave ${CS_REGISTERS_PATH}/current_plvl_d;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mstatus_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mstatus_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mstatus_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mscratch_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mscratch_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mscratch_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mepc_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mepc_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mepc_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mie_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mie_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mie_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mip_d;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mtvec_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mtvec_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mtvec_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcause_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcause_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcause_q;

add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcountinhibit_we;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcountinhibit_d;
add wave -group {CSRs} ${CS_REGISTERS_PATH}/mcountinhibit_q;

add wave -group {Perf Counters} ${CS_REGISTERS_PATH}/mhpmcounter;
add wave -group {Perf Counters} ${CS_REGISTERS_PATH}/mhpmcounter_we;
add wave -group {Perf Counters} ${CS_REGISTERS_PATH}/mhpmcounterh_we;
add wave -group {Perf Counters} ${CS_REGISTERS_PATH}/mhpmcounter_incr;

# ---------------------------------------------------------
add wave -divider {DECODE}
add wave ${CORE}/decode_i/current_plvl_i;
add wave ${CORE}/decode_i/pc_i;
add wave ${CORE}/decode_i/instr_i;
add wave ${CORE}/decode_i/stall_i;
add wave ${CORE}/decode_i/flush_i;
add wave ${CORE}/decode_i/regf_rs1_addr_o;
add wave ${CORE}/decode_i/regf_rs2_addr_o;
add wave ${CORE}/decode_i/rs1_data_i;
add wave ${CORE}/decode_i/rs2_data_i;

add wave -color Gold ${CORE}/decode_i/pc_o;
add wave -color Gold ${CORE}/decode_i/rs1_data_o;
add wave -color Gold ${CORE}/decode_i/rs2_data_o;
add wave -color Gold ${CORE}/decode_i/imm_o;
# add wave -color Gold ${CORE}/decode_i/csr_rdata_o;
add wave -color Gold ${CORE}/decode_i/alu_oper1_src_o;
add wave -color Gold ${CORE}/decode_i/alu_oper2_src_o;
add wave -color Gold ${CORE}/decode_i/bnj_oper_o;
add wave -color Gold ${CORE}/decode_i/alu_oper_o;
add wave -color Gold ${CORE}/decode_i/mem_oper_o;
# add wave -color Gold ${CORE}/decode_i/csr_waddr_o;
# add wave -color Gold ${CORE}/decode_i/csr_we_o;
add wave -color Gold ${CORE}/decode_i/write_rd_o;
add wave -color Gold ${CORE}/decode_i/rd_addr_o;
add wave -color Gold ${CORE}/decode_i/rs1_addr_o;
add wave -color Gold ${CORE}/decode_i/rs2_addr_o;

# ---------------------------------------------------------
add wave -divider {EXECUTE}
add wave ${CORE}/execute_i/pc_i;
add wave ${CORE}/execute_i/rs1_data_i;
add wave ${CORE}/execute_i/rs2_data_i;
add wave ${CORE}/execute_i/imm_i;
add wave ${CORE}/execute_i/alu_oper1_src_i;
add wave ${CORE}/execute_i/alu_oper2_src_i;
add wave ${CORE}/execute_i/alu_oper_i;
add wave ${CORE}/execute_i/bnj_oper_i;
add wave ${CORE}/execute_i/instr_valid_i;

add wave ${CORE}/execute_i/mem_oper_i;

add wave ${CORE}/execute_i/write_rd_i;
add wave ${CORE}/execute_i/rd_addr_i;

add wave ${CORE}/execute_i/new_pc_en_o;
add wave ${CORE}/execute_i/branch_target_o;

add wave -color Turquoise ${CORE}/execute_i/stall_i;
add wave -color Turquoise ${CORE}/execute_i/flush_i;

add wave -color Turquoise ${CORE}/execute_i/forward_rs1_i;
add wave -color Turquoise ${CORE}/execute_i/forward_rs2_i;

add wave -color Turquoise ${CORE}/execute_i/forward_ex_mem_data_i;
add wave -color Turquoise ${CORE}/execute_i/forward_mem_wb_data_i;

add wave -color Gold ${CORE}/execute_i/alu_result_o;
add wave -color Gold ${CORE}/execute_i/alu_oper2_o;
add wave -color Gold ${CORE}/execute_i/mem_oper_o;
add wave -color Gold ${CORE}/execute_i/pc_o;
add wave -color Gold ${CORE}/execute_i/instr_valid_o;

add wave -color Gold ${CORE}/execute_i/write_rd_o;
add wave -color Gold ${CORE}/execute_i/rd_addr_o;

add wave ${CORE}/execute_i/operand1;
add wave ${CORE}/execute_i/operand2;

add wave -group {ALL EXECUTE} ${CORE}/execute_i/*;
# ---------------------------------------------------------
add wave -divider {MEM}
add wave ${CORE}/stage_mem1_i/lsu_req_o;
add wave ${CORE}/stage_mem1_i/lsu_addr_o;
add wave ${CORE}/stage_mem1_i/lsu_we_o;
add wave ${CORE}/stage_mem1_i/lsu_rdata_i;
add wave ${CORE}/stage_mem1_i/lsu_wsel_byte_o;
add wave ${CORE}/stage_mem1_i/lsu_wdata_o;
add wave ${CORE}/stage_mem1_i/lsu_req_stall_i;

add wave ${CORE}/stage_mem1_i/alu_result_i;
add wave ${CORE}/stage_mem1_i/alu_oper2_i;
add wave ${CORE}/stage_mem1_i/mem_oper_i;
add wave ${CORE}/stage_mem1_i/write_rd_i;
add wave ${CORE}/stage_mem1_i/rd_addr_i;

# add wave ${CORE}/stage_mem1_i/csr_wdata_i;
# add wave ${CORE}/stage_mem1_i/csr_waddr_i;
# add wave ${CORE}/stage_mem1_i/is_csr_i;
# add wave ${CORE}/stage_mem1_i/csr_we_i;

add wave -color Turquoise ${CORE}/stage_mem1_i/stall_i;
add wave -color Turquoise ${CORE}/stage_mem1_i/flush_i;

# add wave -color Gold ${CORE}/stage_mem1_i/is_csr_o;
# add wave -color Gold ${CORE}/stage_mem1_i/csr_we_o;
# add wave -color Gold ${CORE}/stage_mem1_i/csr_wdata_o;
# add wave -color Gold ${CORE}/stage_mem1_i/csr_waddr_o;

add wave -color Gold ${CORE}/stage_mem1_i/write_rd_o;
add wave -color Gold ${CORE}/stage_mem1_i/rd_addr_o;
add wave -color Gold ${CORE}/stage_mem1_i/alu_result_o;
add wave -color Gold ${CORE}/stage_mem1_i/mem_oper_o;

add wave ${CORE}/stage_mem1_i/*;

# ---------------------------------------------------------
add wave -group {LSU WISHBONE} -color Gold ${CORE}/lsu_i/wb_if/*;

add wave -group {LSU} ${CORE}/lsu_i/req_i;
add wave -group {LSU} ${CORE}/lsu_i/we_i;
add wave -group {LSU} ${CORE}/lsu_i/addr_i;
add wave -group {LSU} ${CORE}/lsu_i/wsel_byte_i;
add wave -group {LSU} ${CORE}/lsu_i/wdata_i;
add wave -group {LSU} ${CORE}/lsu_i/req_done_o;
add wave -group {LSU} ${CORE}/lsu_i/rdata_o;
add wave -group {LSU} ${CORE}/lsu_i/req_stall_o;

add wave -group {LSU} ${CORE}/lsu_i/current;
add wave -group {LSU} ${CORE}/lsu_i/next;
add wave -group {LSU} ${CORE}/lsu_i/ack_pending_d;
add wave -group {LSU} ${CORE}/lsu_i/ack_pending_q;

# ---------------------------------------------------------
add wave -divider {WRITE BACK}
add wave ${CORE}/write_back_i/write_rd_i;
add wave ${CORE}/write_back_i/result_srcW_i;
add wave ${CORE}/write_back_i/rd_addr_i;
add wave ${CORE}/write_back_i/alu_result_i;
add wave ${CORE}/write_back_i/lsu_rdata_i;
add wave ${CORE}/write_back_i/csr_rdata_i;

add wave -color Gold ${CORE}/write_back_i/regf_write_o;
add wave -color Gold ${CORE}/write_back_i/regf_waddr_o;
add wave -color Gold ${CORE}/write_back_i/regf_wdata_o;

# ---------------------------------------------------------
add wave -divider {CONTROLLER}
add wave -color Turquoise ${CORE}/controller_i/forward_rs1_o;
add wave -color Turquoise ${CORE}/controller_i/forward_rs2_o;
add wave -color Turquoise ${CORE}/controller_i/forward_ex_mem_data_o;
add wave -color Turquoise ${CORE}/controller_i/forward_mem_wb_data_o;
add wave -color Turquoise ${CORE}/controller_i/id_ex_flush_o;
add wave -color Turquoise ${CORE}/controller_i/id_ex_stall_o;
add wave -color Turquoise ${CORE}/controller_i/if_stall_o;
add wave -color Turquoise ${CORE}/controller_i/if_flush_o;
add wave -color Turquoise ${CORE}/controller_i/ex_mem_flush_o;
add wave -color Turquoise ${CORE}/controller_i/ex_mem_stall_o;
add wave -color Turquoise ${CORE}/controller_i/mem_wb_flush_o;
add wave -color Turquoise ${CORE}/controller_i/mem_wb_stall_o;

add wave ${CORE}/controller_i/state;
add wave ${CORE}/controller_i/next;

add wave ${CORE}/controller_i/new_pc_en_o;
add wave ${CORE}/controller_i/pc_sel_o;
add wave ${CORE}/controller_i/exc_pc_o;

add wave ${CORE}/controller_i/*;

add wave -divider {PRIVILEGED}
add wave ${CORE}/privileged_i/*;

# ---------------------------------------------------------
# disable creation of the transcript file
transcript off
run -all