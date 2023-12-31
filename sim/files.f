// include directories
+incdir+${PRJ_DIR}/core/
+incdir+${PRJ_DIR}/core/includes/

// packages
${PRJ_DIR}/core/includes/riscv_pkg.sv
${PRJ_DIR}/core/includes/csr_pkg.sv
${PRJ_DIR}/platform/includes/platform_pkg.sv

// interfaces
${PRJ_DIR}/interfaces/wishbone_if.sv

// core
${PRJ_DIR}/core/core_top.sv
${PRJ_DIR}/core/decode.sv
${PRJ_DIR}/core/controller.sv
${PRJ_DIR}/core/execute.sv
${PRJ_DIR}/core/reg_file.sv
${PRJ_DIR}/core/simple_fetch.sv
${PRJ_DIR}/core/write_back.sv
${PRJ_DIR}/core/perf_counter.sv
${PRJ_DIR}/core/cs_registers.sv
${PRJ_DIR}/core/csr.sv
${PRJ_DIR}/core/stage_mem1.sv
${PRJ_DIR}/core/stage_mem2.sv
${PRJ_DIR}/core/lsu.sv

// platform
${PRJ_DIR}/platform/wb_interconnect.sv
${PRJ_DIR}/platform/timer.sv
${PRJ_DIR}/platform/led_driver.sv
${PRJ_DIR}/platform/yarc_platform.sv

// memories
${PRJ_DIR}/memories/*

// testbenches
${PRJ_DIR}/testbenches/*
