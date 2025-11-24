// include directories
+incdir+${PRJ_DIR}/core/
+incdir+${PRJ_DIR}/core/includes/
+incdir+${PRJ_DIR}/ddr3_mem_controller/includes/

// packages
${PRJ_DIR}/core/includes/riscv_pkg.sv
${PRJ_DIR}/core/includes/csr_pkg.sv
${PRJ_DIR}/ddr3_mem_controller/ddr3_parameters_pkg.sv
${PRJ_DIR}/platform/includes/platform_pkg.sv

// generics
${PRJ_DIR}/generic/flop/flopenrc.sv
${PRJ_DIR}/generic/flop/flopenrc_type.sv
${PRJ_DIR}/generic/flop/flopr.sv
${PRJ_DIR}/generic/flop/flopr_type.sv
${PRJ_DIR}/generic/mux.sv

// peripherals
${PRJ_DIR}/peripherals/wbuart32/rtl/ufifo.v
${PRJ_DIR}/peripherals/wbuart32/rtl/rxuart.v
${PRJ_DIR}/peripherals/wbuart32/rtl/txuart.v
${PRJ_DIR}/peripherals/wbuart32/rtl/wbuart.v

${PRJ_DIR}/peripherals/video/video_pkg.sv
${PRJ_DIR}/peripherals/video/video_core_ctrl.sv
${PRJ_DIR}/peripherals/video/text_mode_line_buffer.sv
${PRJ_DIR}/peripherals/video/glyphmap.sv
${PRJ_DIR}/peripherals/video/attribute_map.sv
${PRJ_DIR}/peripherals/video/vga_text_decoder.sv
${PRJ_DIR}/peripherals/video/tmds_encoder.sv
${PRJ_DIR}/peripherals/video/serializer.sv
${PRJ_DIR}/peripherals/video/hdmi_phy.sv
${PRJ_DIR}/peripherals/video/video_text_mode.sv
${PRJ_DIR}/peripherals/video/video_core.sv

// interfaces
${PRJ_DIR}/interfaces/wishbone_if.sv

// utils
${PRJ_DIR}/utils/wb_connect.sv
${PRJ_DIR}/utils/sync_fifo.sv
${PRJ_DIR}/utils/fifo_adapter.sv
${PRJ_DIR}/utils/sfifo.v
${PRJ_DIR}/utils/reg_bw.sv
${PRJ_DIR}/utils/afifo.v
${PRJ_DIR}/utils/async_fifo.sv
${PRJ_DIR}/utils/skid_buffer.sv

// testbench utils
${PRJ_DIR}/utils/simulation/clk_gen.sv

// fetch modules
// ${PRJ_DIR}/core/simple_fetch.sv
${PRJ_DIR}/core/fetch_modules/wb_prefetch.sv

// core
${PRJ_DIR}/core/core_top.sv
${PRJ_DIR}/core/decode.sv
${PRJ_DIR}/core/controller.sv
${PRJ_DIR}/core/execute.sv
${PRJ_DIR}/core/reg_file.sv
${PRJ_DIR}/core/write_back.sv
${PRJ_DIR}/core/perf_counter.sv
${PRJ_DIR}/core/cs_registers.sv
${PRJ_DIR}/core/csr.sv
${PRJ_DIR}/core/stage_mem1.sv
${PRJ_DIR}/core/lsu.sv

// platform
${PRJ_DIR}/bus_components/addrdecode.v
${PRJ_DIR}/bus_components/skidbuffer.v
${PRJ_DIR}/bus_components/wbxbar.v
${PRJ_DIR}/bus_components/wbupsz.v
${PRJ_DIR}/bus_components/wb_interconnect.sv
${PRJ_DIR}/platform/mtimer.sv
${PRJ_DIR}/platform/led_driver.sv
${PRJ_DIR}/platform/main_xbar.sv
${PRJ_DIR}/platform/sec_xbar.sv
${PRJ_DIR}/platform/periph_xbar.sv
${PRJ_DIR}/platform/fetch_intercon.sv
${PRJ_DIR}/platform/data_intercon.sv
${PRJ_DIR}/platform/yarc_platform.sv

// memories
${PRJ_DIR}/memories/dp_mem_wb.sv
${PRJ_DIR}/memories/sp_mem_wb.sv
${PRJ_DIR}/memories/tdp_mem.sv
${PRJ_DIR}/memories/sdp_mem.sv
${PRJ_DIR}/memories/sdp_mem_with_sel.sv

// caches
${PRJ_DIR}/caches/data_cache/write_buffer_if.sv
${PRJ_DIR}/caches/data_cache/plru.sv
${PRJ_DIR}/caches/data_cache/write_buffer.sv
${PRJ_DIR}/caches/instruction_cache.sv
${PRJ_DIR}/caches/data_cache/data_cache.sv

// ddr3 controller files
${PRJ_DIR}/ddr3_mem_controller/ddr3_controller.v
${PRJ_DIR}/ddr3_mem_controller/ddr3_phy.v
${PRJ_DIR}/ddr3_mem_controller/ddr3_top.v
${PRJ_DIR}/ddr3_mem_controller/yarc_ddr3_top.sv
${PRJ_DIR}/ddr3_mem_controller/sim_files/ddr3_sim_model.sv
${PRJ_DIR}/ddr3_mem_controller/sim_files/wb_sim_memory.sv

// testbenches
${PRJ_DIR}/peripherals/wbuart32/rtl/rxuartlite.v
${PRJ_DIR}/peripherals/wbuart32/rtl/txuartlite.v
${PRJ_DIR}/testbenches/rxuart_printer.sv
${PRJ_DIR}/testbenches/txuart_sender.sv
${PRJ_DIR}/testbenches/core_with_mem.sv
${PRJ_DIR}/testbenches/verilator_top.sv
