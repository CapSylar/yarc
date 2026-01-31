// contains the core with memories
// instantiated by testbenches

module core_with_mem
#(parameter string DMEMFILE = "", parameter string IMEMFILE = "",
    parameter bit INIT_DDR3_MEMORY = '0,  parameter string DDR3_MEMFILE = "") ();

import platform_pkg::*;
import ddr3_parameters_pkg::*;

// create clocks
localparam MAIN_CLK_PERIOD = 12.0ns;
localparam PIXEL_CLK_HALF_PERIOD = 39.6825ns / 2;
localparam PIXEL_CLK_5X_HALF_PERIOD = PIXEL_CLK_HALF_PERIOD / 5;

// clk generation
logic clk;
logic pixel_clk, pixel_clk_5x;
logic ddr3_clk, ref_clk, ddr3_clk_90;

// drive clock
initial
begin
    clk = 1;
    forever clk = #(MAIN_CLK_PERIOD/2) ~clk;
end

initial begin
    ddr3_clk = 1;
    ref_clk = 1;
end
always #(DDR3_CLK_PERIOD/2) ddr3_clk = ~ddr3_clk;
always #(CONTROLLER_REF_CLK/2) ref_clk = ~ref_clk;

initial begin
    ddr3_clk_90 = 1;
    #(DDR3_CLK_PERIOD/4);
    forever
        #(DDR3_CLK_PERIOD/2) ddr3_clk_90 = ~ddr3_clk_90;
end

initial
begin
    pixel_clk = 0;
    forever pixel_clk = #PIXEL_CLK_HALF_PERIOD ~pixel_clk;
end

initial
begin
    pixel_clk_5x = 0;
    forever pixel_clk_5x = #PIXEL_CLK_5X_HALF_PERIOD ~pixel_clk_5x;
end

logic rstn = '0;
logic rstn_t = '0;
always @(posedge clk)
begin
    rstn <= rstn_t;    
end

initial
begin
    rstn_t = 1'b0;
    repeat(5) @(posedge clk);
    rstn_t = 1'b1;

    repeat(5000000) @(posedge clk);
    // $finish;
end

wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) imem_wb_if();
wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) imem_rw_wb_if();

// Instruction Memory
dp_mem_wb #(.MEMFILE(IMEMFILE), .SIZE_POT_WORDS(IMEM_SIZE_WORDS_POT), .DATA_WIDTH(MAIN_WB_DW)) imem
(
    .clk_i(clk),
    .rstn_i(rstn),

    .wb_if1(imem_wb_if),

    .wb_if2(imem_rw_wb_if)
);

wishbone_if #(.ADDRESS_WIDTH(MAIN_WB_AW), .DATA_WIDTH(MAIN_WB_DW)) dmem_wb_if();

// Data Memory
sp_mem_wb #(.MEMFILE(DMEMFILE), .SIZE_POT_WORDS(DMEM_SIZE_WORDS_POT), .DATA_WIDTH(MAIN_WB_DW)) dmem
(
    .clk_i(clk),

    .wb_if(dmem_wb_if)
);

logic uart_tx, uart_rx;

// simulation Uart Rx
rxuart_printer
#(.CLKS_PER_BAUD(CLKS_PER_BAUD))
rxuart_printer_i
(
    .clk_i(clk),
    .reset_i(~rstn),

    .uart_rx_i(uart_tx)
);

// simulation uart tx
txuart_sender
#(.CLKS_PER_BAUD(CLKS_PER_BAUD))
txuart_sender_i
(
    .clk_i(clk),
    .reset_i(~rstn),

    .tx_uart_o(uart_rx)
);

wishbone_if #(.ADDRESS_WIDTH(SEC_WB_AW), .DATA_WIDTH(SEC_WB_DW)) ddr3_wb_if();

localparam DDR3_TRUE_SIM = 1'b0;
generate
    if (DDR3_TRUE_SIM) begin: true_ddr3_model_sim

        wire clk_locked = 1'b1;
        // ddr3 phy interface definitons
        logic o_ddr3_clk_p;
        logic o_ddr3_clk_n;
        logic ck_en [1:0];
        logic cs_n [1:0];
        logic odt [1:0];
        logic ras_n;
        logic cas_n;
        logic we_n;
        logic reset_n;
        logic [ROW_BITS-1:0] addr;
        logic [BA_BITS-1:0] ba_addr;
        logic [BYTE_LANES-1:0] ddr3_dm;
        wire [(NUM_DQ_BITS*BYTE_LANES)-1:0] dq;
        wire [(NUM_DQ_BITS*BYTE_LANES)/8-1:0] dqs, dqs_n;

        // DDR3 Controller 
        yarc_ddr3_top #() yarc_ddr3_top_i
        (
            // clock and reset
            .i_controller_clk(clk),
            .i_ddr3_clk(ddr3_clk), //i_controller_clk has period of CONTROLLER_CLK_PERIOD, i_ddr3_clk has period of DDR3_CLK_PERIOD 
            .i_ref_clk(ref_clk),
            .i_ddr3_clk_90(ddr3_clk_90),
            .i_rst_n(rstn && clk_locked), 

            // Wishbone inputs
            .wb_if(ddr3_wb_if),

            // PHY Interface
            .o_ddr3_clk_p(o_ddr3_clk_p),
            .o_ddr3_clk_n(o_ddr3_clk_n),
            .o_ddr3_cke(ck_en[0]), // CKE
            .o_ddr3_cs_n(cs_n[0]), // chip select signal
            .o_ddr3_odt(odt[0]), // on-die termination
            .o_ddr3_ras_n(ras_n), // RAS#
            .o_ddr3_cas_n(cas_n), // CAS#
            .o_ddr3_we_n(we_n), // WE#
            .o_ddr3_reset_n(reset_n),
            .o_ddr3_addr(addr),
            .o_ddr3_ba_addr(ba_addr),
            .io_ddr3_dq(dq),
            .io_ddr3_dqs(dqs),
            .io_ddr3_dqs_n(dqs_n),
            .o_ddr3_dm(ddr3_dm)
        );

        // DDR3 simulation model
        ddr3_sim_model ddr3_sim_model_i(
            .rst_n(reset_n),
            .ck(o_ddr3_clk_p),
            .ck_n(o_ddr3_clk_n),
            .cke(ck_en[0]),
            .cs_n(cs_n[0]),
            .ras_n(ras_n),
            .cas_n(cas_n),
            .we_n(we_n),
            .dm_tdqs(ddr3_dm),
            .ba(ba_addr),
            .addr(addr),
            .dq(dq),
            .dqs(dqs),
            .dqs_n(dqs_n),
            .tdqs_n(),
            .odt(odt[0])
        );
        assign ck_en[1] = 1'b0;
        assign cs_n[1] = 1'b1;
        assign odt[1] = 1'b0; 

    end else begin: replace_with_wb_model
        wb_sim_memory #(.DATA_WIDTH(SEC_WB_DW), .SIZE_POT_WORDS(SEC_WB_AW),
            .INIT_MEM(INIT_DDR3_MEMORY), .MEMFILE(DDR3_MEMFILE))
        wb_sim_memory_i
        (
            .clk_i(clk),

            .cyc_i(ddr3_wb_if.cyc),
            .stb_i(ddr3_wb_if.stb),

            .we_i(ddr3_wb_if.we),
            .addr_i(ddr3_wb_if.addr[$bits(wb_sim_memory_i.addr_i)-1:0]),
            .sel_i(ddr3_wb_if.sel),
            .wdata_i(ddr3_wb_if.wdata),
            
            .rdata_o(ddr3_wb_if.rdata),
            .rty_o(ddr3_wb_if.rty),
            .ack_o(ddr3_wb_if.ack),
            .stall_o(ddr3_wb_if.stall),
            .err_o(ddr3_wb_if.err)
        );
    end
endgenerate

// JTAG lines

logic tck;
logic tms;
logic trst_n;
logic tdi;
logic tdo;

yarc_platform yarc_platform_i
(
    .clk_i(clk),
    .rstn_i(rstn),

    // Platform <-> DMEM
    .dmem_wb_if(dmem_wb_if),

    // Platform <-> IMEM
    .imem_wb_if(imem_wb_if),
    .imem_rw_wb_if(imem_rw_wb_if),

    // Platform <-> DDR3
    .fb_wb_if(ddr3_wb_if),

    // Platform <-> Peripherals
    .led_status_o(),

    // Platform <-> UART
    .uart_rx_i(uart_rx),
    .uart_tx_o(uart_tx),

    // Platform <-> HDMI
    .pixel_clk_i(pixel_clk),
    .pixel_rstn_i(rstn),
    .pixel_clk_5x_i(pixel_clk_5x),
    .hdmi_channel_o(),

    // JTAG lines
    .tck_i      (tck),
    .tms_i      (tms),
    .trst_ni    (trst_n),
    .td_i       (tdi),
    .td_o       (tdo)
);

jtag_sim jtag_sim_i(
    .tck_o(tck),
    .tms_o(tms),
    .trst_no(trst_n),
    .tdi_o(tdi),
    .tdo_i(tdo)
);

endmodule: core_with_mem
