
/*
    __   __                    ______  _         _     __                         
    \ \ / /                    | ___ \| |       | |   / _|                        
     \ V /   __ _  _ __   ___  | |_/ /| |  __ _ | |_ | |_   ___   _ __  _ __ ___  
      \ /   / _` || '__| / __| |  __/ | | / _` || __||  _| / _ \ | '__|| '_ ` _ \ 
      | |  | (_| || |   | (__  | |    | || (_| || |_ | |  | (_) || |   | | | | | |
      \_/   \__,_||_|    \___| \_|    |_| \__,_| \__||_|   \___/ |_|   |_| |_| |_|

      - contains:
        - core
        - mtimer
*/                                                                                  

module yarc_platform
import platform_pkg::*;
(
    input clk_i,
    input rstn_i,

    // Platform <-> DMEM
    wishbone_if.MASTER dmem_wb_if,

    // Platform <-> IMEM
    wishbone_if.MASTER imem_wb_if,
    wishbone_if.MASTER imem_rw_wb_if,

    // Platform <-> Framebuffer memory
    wishbone_if.MASTER fb_wb_if,

    // Platform <-> Peripherals
    output logic [7:0] led_status_o,

    // uart lines
    input logic uart_rx_i,
    output logic uart_tx_o,

    input pixel_clk_i,
    input pixel_rstn_i,
    input pixel_clk_5x_i,

    // hdmi lines
	output logic [3:0] hdmi_channel_o,

    // JTAG lines
    input wire tck_i,
    input wire tms_i,
    input wire trst_ni,
    input wire td_i,
    output logic td_o
);

wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) instr_fetch_wb_if();
wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) icache_wb_if();

// fetch side interconnect
fetch_intercon fetch_intercon_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .cpu_fetch_if(instr_fetch_wb_if),

    .iccm_if(imem_wb_if),

    .icache_if(icache_wb_if)
);

wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) mem_instr_cache_wb_if();
wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) mem_data_cache_wb_if();

logic flush_icache_req, flush_icache_ack;

// Instruction Cache for DDR3 Memory
instruction_cache #(.NUM_SETS_LOG2(INSTR_CACHE_NUM_SETS_LOG2)) // 512 sets => 1024 cache lines
instruction_cache_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .flush_req_i(flush_icache_req),
    .flush_ack_o(flush_icache_ack),

    .cpu_if(icache_wb_if),

    .mem_if(mem_instr_cache_wb_if)
);

wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) lsu_wb_if();
wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) dcache_wb_if();
wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) data_intercon_to_main_mux();

// data side interconnect
data_intercon data_intercon_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .cpu_if(lsu_wb_if),

    .dccm_if(dmem_wb_if),

    .dcache_if(dcache_wb_if),

    .main_mux_if(data_intercon_to_main_mux)
);

data_cache #(.NUM_SETS_LOG2(DATA_CACHE_NUM_SETS_LOG2) ,.WRITE_BUFFER_DEPTH_LOG2(WRITE_BUFFER_DEPTH_LOG2))
data_cache_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .cpu_if(dcache_wb_if),

    .mem_if(mem_data_cache_wb_if)
);

// Main wbxbar slaves
wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) main_slave_wb_if [MAIN_XBAR_NUM_SLAVES]();

main_xbar main_xbar_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // masters
    .lsu_wb_if(data_intercon_to_main_mux),

    // slaves
    .slave_wb_if(main_slave_wb_if)
);

// imem
wb_connect imem_connect (.wb_if_i(main_slave_wb_if[MAIN_XBAR_IMEM_SLAVE_IDX]), .wb_if_o(imem_rw_wb_if));

// Peripheral wxbar
wishbone_if #(.ADDRESS_WIDTH(PERIPH_WB_AW), .DATA_WIDTH(PERIPH_WB_DW)) periph_slave_wb_if [PERIPH_XBAR_NUM_SLAVES]();

periph_xbar periph_xbar_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .master_wb_if(main_slave_wb_if[MAIN_XBAR_PERIPHERAL_SLAVE_IDX]),
    .slave_wb_if(periph_slave_wb_if)
);

// interrupt lines
logic m_timer_interrupt;
logic m_software_interrupt;

// mtimer
clint clint_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .wb_if(periph_slave_wb_if[PERIPH_XBAR_MTIMER_SLAVE_IDX]),

    .m_timer_interrupt_o(m_timer_interrupt),
    .m_software_interrupt_o(m_software_interrupt)
);

// led driver
led_driver led_driver_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .wb_if(periph_slave_wb_if[PERIPH_XBAR_LED_DRIVER_SLAVE_IDX]),
    
    .led_status_o(led_status_o)
);

logic uart_int;

uart_top uart_top_i (

    .wb_clk_i(clk_i),
    .wb_rst_i(~rstn_i),

    .wb_cyc_i(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].cyc),
    .wb_stb_i(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].stb),
    .wb_we_i (periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].we),
    .wb_adr_i({periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].addr[2:0], 2'b0}),
    .wb_dat_i(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].wdata),
    .wb_sel_i(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].sel),

    .wb_ack_o(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].ack),
    .wb_dat_o(periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].rdata),

    .stx_pad_o(uart_tx_o),
    .srx_pad_i(uart_rx_i),

    .rts_pad_o(),
    .cts_pad_i(1'b0),
    .dtr_pad_o(),
    .dsr_pad_i(1'b0),
    .ri_pad_i(1'b0),
    .dcd_pad_i(1'b0),

    .int_o(uart_int)
);

assign periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].stall = 
    periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].stb & ~periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].ack;

// zero out the rest of the control lines
assign periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].err = '0;
assign periph_slave_wb_if[PERIPH_XBAR_WBUART_SLAVE_IDX].rty = '0;

wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) video_fb_wb_if();
wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) cpu_fb_wb_if();
wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) sec_xbar_slaves_if[SEC_XBAR_NUM_SLAVES]();

video_core
#(
)
video_core_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .pixel_clk_i(pixel_clk_i),
    .pixel_rstn_i(pixel_rstn_i),
    .pixel_clk_5x_i(pixel_clk_5x_i),

    .config_if(periph_slave_wb_if[PERIPH_XBAR_VIDEO_SLAVE_IDX]),
    .fetch_if(video_fb_wb_if),

    .hdmi_channel_o(hdmi_channel_o)
);

sec_xbar sec_xbar_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .cpu_wb_if(main_slave_wb_if[MAIN_XBAR_FB_SLAVE_IDX]),
    .video_wb_if(video_fb_wb_if),
    .instr_cache_wb_if(mem_instr_cache_wb_if),
    .data_cache_wb_if(mem_data_cache_wb_if),

    .slave_wb_if(sec_xbar_slaves_if)
);

wb_connect fb_connect (.wb_if_i(sec_xbar_slaves_if[SEC_XBAR_FB_SLAVE_IDX]), .wb_if_o(fb_wb_if));

// Core Top
core_subsystem subsystem_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // Core WB LSU Interface
    .lsu_wb_if(lsu_wb_if),
    // Core WB Instruction Fetch interface
    .instr_fetch_wb_if(instr_fetch_wb_if),

    // interrupts
    .m_timer_interrupt_i(m_timer_interrupt),
    .m_software_interrupt_i(m_software_interrupt),
    .m_external_interrupt_i(uart_int),

    .flush_icache_req_o(flush_icache_req),
    .flush_icache_ack_i(flush_icache_ack),

    .tck_i(tck_i),
    .tms_i(tms_i),
    .trst_ni(trst_ni),
    .td_i(td_i),
    .td_o(td_o)
);

endmodule: yarc_platform
