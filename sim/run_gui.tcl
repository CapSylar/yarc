
global env
set TOP sim:$env(SIM_TOP)
set PLATFORM ${TOP}/yarc_platform_i
set CORE ${PLATFORM}/core_i

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
# add wave ${CORE}/wb_prefetch_i/mcause_i;
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

add wave ${CORE}/stage_mem1_i/alu_result_i;
add wave ${CORE}/stage_mem1_i/alu_oper2_i;
add wave ${CORE}/stage_mem1_i/mem_oper_i;
add wave ${CORE}/stage_mem1_i/write_rd_i;
add wave ${CORE}/stage_mem1_i/rd_addr_i;

add wave -color Turquoise ${CORE}/stage_mem1_i/stall_i;
add wave -color Turquoise ${CORE}/stage_mem1_i/flush_i;

add wave -color Gold ${CORE}/stage_mem1_i/rd_addr_o;
add wave -color Gold ${CORE}/stage_mem1_i/alu_result_o;

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

# ----------------Instruction Cache----------------
set ICACHE ${PLATFORM}/instruction_cache_i
add wave -divider {Instruction Cache}
add wave -group {INSTR_CACHE CPU_IF} ${ICACHE}/cpu_if/*;
add wave -group {INSTR_CACHE MEM_IF} ${ICACHE}/mem_if/*;
add wave ${ICACHE}/valid_bits_we;
add wave ${ICACHE}/valid_bits_rdata;
add wave ${ICACHE}/tag_mem_we;
add wave ${ICACHE}/tag_mem_rdata;
add wave ${ICACHE}/data_mem_we;
add wave ${ICACHE}/data_mem_rdata;
add wave ${ICACHE}/valid_bits;
# add wave ${ICACHE}/tag_mem;
# add wave ${ICACHE}/data_mem;
add wave ${ICACHE}/*;

# ----------------Data Cache----------------
set DCACHE ${PLATFORM}/data_cache_i;
add wave -divider {Data Cache}
add wave -group {DATA_CACHE CPU_IF} ${DCACHE}/cpu_if/*;
add wave -group {DATA_CACHE MEM_IF} ${DCACHE}/mem_if/*;
add wave ${DCACHE}/valid_bits_we;
add wave ${DCACHE}/valid_bits_rdata;
add wave ${DCACHE}/tag_mem_we;
add wave ${DCACHE}/tag_mem_rdata;
add wave ${DCACHE}/data_mem_we;
add wave ${DCACHE}/data_mem_rdata;
add wave ${DCACHE}/valid_bits;
add wave ${DCACHE}/set_age;
add wave ${DCACHE}/*;
add wave ${DCACHE}/write_buffer_i/*;
add wave ${DCACHE}/write_buffer_i/mem;
add wave -divider {Skid Buffer}
add wave ${DCACHE}/skid_buffer_i/*;

# ---------------------------------------------------------
add wave -divider {Riscv Timer}
add wave ${PLATFORM}/mtimer_i/timer_int_o;
add wave ${PLATFORM}/mtimer_i/mtime_d;
add wave ${PLATFORM}/mtimer_i/mtime_q;
add wave ${PLATFORM}/mtimer_i/mtimecmp_d;
add wave ${PLATFORM}/mtimer_i/mtimecmp_q;

# ---------------------------------------------------------
# add wave -divider {Platform}
# add wave ${PLATFORM}/*;
add wave -divider {VIDEO core}
add wave ${PLATFORM}/video_core_i/*;
add wave ${PLATFORM}/video_core_i/video_core_ctrl_i/*;
add wave ${PLATFORM}/video_core_i/afifo_i/*;
add wave ${PLATFORM}/video_core_i/fifo_adapter_i/*;
add wave ${PLATFORM}/video_core_i/video_text_mode_i/text_mode_line_buffer_i/*;
add wave ${PLATFORM}/video_core_i/video_text_mode_i/text_mode_line_buffer_i/buffer;
add wave ${PLATFORM}/video_core_i/video_text_mode_i/vga_text_decoder_i/*;
add wave ${PLATFORM}/video_core_i/video_text_mode_i/*;
add wave ${PLATFORM}/video_core_i/hdmi_phy_i/*;
add wave ${PLATFORM}/video_core_i/hdmi_phy_i/*;

set ddr3_top ${TOP}/true_ddr3_model_sim/yarc_ddr3_top_i
set main_xbar ${PLATFORM}/main_xbar_i;
set fetch_intercon ${PLATFORM}/fetch_intercon_i;
set data_intercon ${PLATFORM}/data_intercon_i;
set periph_xbar ${PLATFORM}/periph_xbar_i;
set sec_xbar ${PLATFORM}/sec_xbar_i;

add wave -divider {Main Xbar}
add wave -group {LSU IN} -color Gold ${main_xbar}/lsu_wb_if/*;
# add wave -group {FETCH IN} -color Gold ${main_xbar}/instr_fetch_wb_if/*;
add wave -group {IMEM interface} -color Gold ${main_xbar}/slave_wb_if[0]/*;
add wave -group {DMEM WB Interface} -color Gold ${main_xbar}/slave_wb_if[1]/*;
add wave -group {FB WB Interface} -color Gold ${main_xbar}/slave_wb_if[2]/*;
add wave -group {Peripherals WB Interface} -color Gold ${main_xbar}/slave_wb_if[3]/*;

add wave -divider {Fetch Interconnect}
add wave -group {FETCH IN} -color Gold ${fetch_intercon}/cpu_fetch_if/*;
add wave -group {ICCM IF} -color Gold ${fetch_intercon}/iccm_if/*;
add wave -group {ICACHE IF} -color Gold ${fetch_intercon}/icache_if/*;

add wave -divider {Data Interconnect}
add wave -group {CPU LSU} -color Gold ${data_intercon}/cpu_if/*;
add wave -group {DCCM IF} -color Gold ${data_intercon}/dccm_if/*;
add wave -group {DCACHE IF} -color Gold ${data_intercon}/dcache_if/*;
add wave -group {MAIN MUX IF} -color Gold ${data_intercon}/main_mux_if/*;

add wave -divider {Peripheral Xbar}
add wave -group {MTIMER WB Interface} -color Gold ${periph_xbar}/slave_wb_if[0]/*;
add wave -group {LED DRIVER WB Interface} -color Gold ${periph_xbar}/slave_wb_if[1]/*;
add wave -group {WBUART WB Interface} -color Gold ${periph_xbar}/slave_wb_if[2]/*;
add wave -group {VIDEO Interface} -color Gold ${periph_xbar}/slave_wb_if[3]/*;

add wave -divider {Secondary Xbar}
add wave -group {Sec Xbar cpu input} ${sec_xbar}/cpu_wb_if/*;
add wave -group {Sec Xbar video input} ${sec_xbar}/video_wb_if/*;
add wave -group {Sec Xbar Icache input} ${sec_xbar}/instr_cache_wb_if/*;
add wave -group {Sec Xbar Dcache input} ${sec_xbar}/data_cache_wb_if/*;
add wave -group {Sec Xbar Output} ${sec_xbar}/slave_wb_if[0]/*;

# add wave -group {Framebuffer WB Interface} -color Gold ${PLATFORM}/slave_wb_if[2]/*;
# add wave -group {DDR3 Controller} -divider {DDR3 Controller}
# add wave -group {DDR3 Controller} ${ddr3_top}/i_controller_clk;
# add wave -group {DDR3 Controller} ${ddr3_top}/i_ddr3_clk;
# add wave -group {DDR3 Controller} ${ddr3_top}/i_ref_clk;
# add wave -group {DDR3 Controller} ${ddr3_top}/i_ddr3_clk_90;
# add wave -group {DDR3 Controller} ${ddr3_top}/i_rst_n;
add wave -group {DDR3 Controller} ${TOP}/ddr3_wb_if/*;
add wave -group {Simple WB Memory} ${TOP}/replace_with_wb_model/wb_sim_memory_i/*;
# add wave -group {Simple WB Memory} ${TOP}/replace_with_wb_model/wb_sim_memory_i/INIT_DDR3_MEMORY;
# add wave -group {Simple WB Memory} ${TOP}/replace_with_wb_model/wb_sim_memory_i/DDR3_MEMFILE;

# add wave -group {DDR3 External Interface} -divider {DDR3 External Interface}
# add wave -group {DDR3 External Interface} ${ddr3_top}/wb_if/*;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_clk_p;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_clk_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_reset_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_cke;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_cs_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_ras_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_cas_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_we_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_addr;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_ba_addr;
# add wave -group {DDR3 External Interface} ${ddr3_top}/io_ddr3_dq;
# add wave -group {DDR3 External Interface} ${ddr3_top}/io_ddr3_dqs;
# add wave -group {DDR3 External Interface} ${ddr3_top}/io_ddr3_dqs_n;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_dm;
# add wave -group {DDR3 External Interface} ${ddr3_top}/o_ddr3_odt;

# add wave -group {DDR3 External Interface} ${ddr3_top}/ddr3_top/o_wb_stall;
# add wave -group {DDR3 External Interface} ${ddr3_top}/ddr3_top/o_wb_ack;
# add wave -group {DDR3 External Interface} ${ddr3_top}/ddr3_top/o_wb_data;

# ---------------------------------------------------------
# disable creation of the transcript file
transcript off
run -all