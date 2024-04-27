// contains the core with memories
// instantiated by testbenches

module core_with_mem
#(parameter string DMEMFILE = "", parameter string IMEMFILE = "") ();

import platform_pkg::*;
import ddr3_parameters_pkg::*;

// create clocks
localparam MAIN_CLK_PERIOD = 12.0ns;
// localparam PIXEL_CLK_HALF_PERIOD = 39.6825ns / 2;
// localparam PIXEL_CLK_5X_HALF_PERIOD = PIXEL_CLK_HALF_PERIOD / 5;

// clk generation
logic clk;
// logic pixel_clk, pixel_clk_5x;
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

// initial
// begin
//     pixel_clk = 0;
//     forever pixel_clk = #PIXEL_CLK_HALF_PERIOD ~pixel_clk;
// end

// initial
// begin
//     pixel_clk_5x = 0;
//     forever pixel_clk_5x = #PIXEL_CLK_5X_HALF_PERIOD ~pixel_clk_5x;
// end

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
    $finish;
end

wishbone_if #(.ADDRESS_WIDTH(32), .DATA_WIDTH(32)) imem_wb_if();

// Instruction Memory
sp_mem_wb #(.MEMFILE(IMEMFILE), .SIZE_POT_WORDS(IMEM_SIZE_WORDS_POT), .DATA_WIDTH(DATA_WIDTH)) imem
(
    .clk_i(clk),

    .cyc_i(imem_wb_if.cyc),
    .stb_i(imem_wb_if.stb),

    .we_i(imem_wb_if.we),
    .addr_i(imem_wb_if.addr[IMEM_SIZE_WORDS_POT-1:0]), // 4-byte addressable
    .sel_i(imem_wb_if.sel),
    .wdata_i(imem_wb_if.wdata),

    .rdata_o(imem_wb_if.rdata),
    .rty_o(imem_wb_if.rty),
    .ack_o(imem_wb_if.ack),
    .stall_o(imem_wb_if.stall),
    .err_o(imem_wb_if.err)
);

wishbone_if #(.ADDRESS_WIDTH(32), .DATA_WIDTH(32)) dmem_wb_if();

// Data Memory
sp_mem_wb #(.MEMFILE(DMEMFILE), .SIZE_POT_WORDS(DMEM_SIZE_WORDS_POT), .DATA_WIDTH(DATA_WIDTH)) dmem
(
    .clk_i(clk),

    .cyc_i(dmem_wb_if.cyc),
    .stb_i(dmem_wb_if.stb),

    .we_i(dmem_wb_if.we),
    .addr_i(dmem_wb_if.addr[DMEM_SIZE_WORDS_POT-1:0]), // 4-byte addressable
    .sel_i(dmem_wb_if.sel),
    .wdata_i(dmem_wb_if.wdata),

    .rdata_o(dmem_wb_if.rdata),
    .rty_o(dmem_wb_if.rty),
    .ack_o(dmem_wb_if.ack),
    .stall_o(dmem_wb_if.stall),
    .err_o(dmem_wb_if.err)
);

logic uart_tx;

// logic hdmi_clk;
// logic [2:0] hdmi_data;

// simulation Uart Rx
rxuart_printer
#(.CLKS_PER_BAUD(CLKS_PER_BAUD))
rxuart_printer_i
(
    .clk_i(clk),
    .reset_i(~rstn),

    .uart_rx_i(uart_tx)
);

// wishbone up converter 32-bits <-> 128-bits
wishbone_if #(.ADDRESS_WIDTH(32), .DATA_WIDTH(32)) ddr3_wb_if();
wishbone_if #(.ADDRESS_WIDTH(32), .DATA_WIDTH(128)) wide_ddr3_wb_if();

wbupsz #(.ADDRESS_WIDTH(32),
         .WIDE_DW(128),
         .SMALL_DW(32),
         .OPT_LITTLE_ENDIAN(1'b1),
         .OPT_LOWPOWER(1'b0))
wbupsz_i
(
    .i_clk(clk),
    .i_reset(~rstn),

    // incoming small port
    .i_scyc(ddr3_wb_if.cyc),
    .i_sstb(ddr3_wb_if.stb),
    .i_swe(ddr3_wb_if.we),
    .i_saddr(ddr3_wb_if.addr),
    .i_sdata(ddr3_wb_if.wdata),
    .i_ssel(ddr3_wb_if.sel),
    .o_sstall(ddr3_wb_if.stall),
    .o_sack(ddr3_wb_if.ack),
    .o_sdata(ddr3_wb_if.rdata),
    .o_serr(ddr3_wb_if.err),

    // outgoing larger bus size port
    .o_wcyc(wide_ddr3_wb_if.cyc),
    .o_wstb(wide_ddr3_wb_if.stb),
    .o_wwe(wide_ddr3_wb_if.we),
    .o_waddr(wide_ddr3_wb_if.addr),
    .o_wdata(wide_ddr3_wb_if.wdata),
    .o_wsel(wide_ddr3_wb_if.sel),
    .i_wstall(wide_ddr3_wb_if.stall),
    .i_wack(wide_ddr3_wb_if.ack),
    .i_wdata(wide_ddr3_wb_if.rdata),
    .i_werr(wide_ddr3_wb_if.err)
);

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
        logic [LANES-1:0] ddr3_dm;
        wire [(NUM_DQ_BITS*LANES)-1:0] dq;
        wire [(NUM_DQ_BITS*LANES)/8-1:0] dqs, dqs_n;

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
            .wb_if(wide_ddr3_wb_if),

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
            .rst_n(rstn),
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
        wb_sim_memory #(.DATA_WIDTH(128), .SIZE_POT_WORDS(25))
        wb_sim_memory_i
        (
            .clk_i(clk),

            .cyc_i(wide_ddr3_wb_if.cyc),
            .stb_i(wide_ddr3_wb_if.stb),

            .we_i(wide_ddr3_wb_if.we),
            .addr_i(wide_ddr3_wb_if.addr[$bits(wb_sim_memory_i.addr_i)-1:0]),
            .sel_i(wide_ddr3_wb_if.sel),
            .wdata_i(wide_ddr3_wb_if.wdata),
            
            .rdata_o(wide_ddr3_wb_if.rdata),
            .rty_o(wide_ddr3_wb_if.rty),
            .ack_o(wide_ddr3_wb_if.ack),
            .stall_o(wide_ddr3_wb_if.stall),
            .err_o(wide_ddr3_wb_if.err)
        );
    end
endgenerate

yarc_platform yarc_platform_i
(
    .clk_i(clk),
    .rstn_i(rstn),

    // Platform <-> DMEM
    .dmem_wb_if(dmem_wb_if),

    // Platform <-> IMEM
    .instr_fetch_wb_if(imem_wb_if),

    // Platform <-> DDR3
    .ddr3_wb_if(ddr3_wb_if),

    // Platform <-> Peripherals
    .led_status_o(),

    // Platform <-> UART
    .uart_rx_i(1'b1),
    .uart_tx_o(uart_tx)

    // Platform <-> HDMI
    // .pixel_clk_i(pixel_clk),
    // .pixel_clk_5x_i(pixel_clk_5x),
    // .hdmi_clk_o(hdmi_clk),
    // .hdmi_data_o(hdmi_data)
);

endmodule: core_with_mem
