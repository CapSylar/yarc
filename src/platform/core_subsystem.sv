
module core_subsystem
    import core_pkg::*;
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
        input m_external_interrupt_i,

        output flush_icache_req_o,
        input flush_icache_ack_i,

        // JTAG lines
        input wire tck_i,
        input wire tms_i,
        input wire trst_ni,
        input wire td_i,
        output logic td_o
    );

    // Core Top
    core_top core_i
    (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        // Core WB LSU Interface
        .lsu_wb_if(lsu_wb_if),
        // Core WB Instruction Fetch interface
        .instr_fetch_wb_if(instr_fetch_wb_if),

        // interrupts
        .m_timer_interrupt_i(m_timer_interrupt_i),
        .m_software_interrupt_i(m_software_interrupt_i),
        .m_external_interrupt_i(m_external_interrupt_i),

        .flush_icache_req_o(flush_icache_req_o),
        .flush_icache_ack_i(flush_icache_ack_i)
    );

    /*
     * JTAG DEBUG
     */

    logic ndmreset;
    logic dm_debug_req;

    dm::dmi_req_t dmi_req;
    dm::dmi_resp_t dmi_resp;
    logic dmi_req_valid, dmi_req_ready;
    logic dmi_resp_ready, dmi_resp_valid;

    // debug unit slave interface
    logic                        dm_grant;
    logic                        dm_rvalid;
    logic                        dm_req;
    logic                        dm_we;
    logic [31:0]                 dm_addr;
    logic [31:0]                 dm_wdata;
    logic [31:0]                 dm_rdata;
    logic [3:0]                  dm_be;

    // debug unit master interface (system bus access)
    logic                        sb_req;
    logic [31:0]                 sb_addr;
    logic                        sb_we;
    logic [31:0]                 sb_wdata;
    logic [3:0]                  sb_be;
    logic                        sb_gnt;
    logic                        sb_rvalid;
    logic [31:0]                 sb_rdata;

    dmi_jtag dmi_jtag_i (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .testmode_i('0),

        .dmi_rst_no(), // NC
        .dmi_req_o(dmi_req),
        .dmi_req_valid_o(dmi_req_valid),
        .dmi_req_ready_i(dmi_req_ready),

        .dmi_resp_i(dmi_resp),
        .dmi_resp_ready_o(dmi_resp_ready),
        .dmi_resp_valid_i(dmi_resp_valid),

        .tck_i(tck_i),
        .tms_i(tms_i),
        .trst_ni(trst_ni),
        .td_i(td_i),
        .td_o(td_o),
        .tdo_oe_o()
    );

    localparam HARTINFO = {8'h0, 4'h2, 3'b0, 1'b1, dm::DataCount, dm::DataAddr};

    dm_top #(
        .NrHarts           ( 1                 ),
        .BusWidth          ( 32                )
    ) i_dm_top (

        .clk_i             ( clk_i             ),
        .rst_ni            ( rstn_i            ),
        .next_dm_addr_i    ( '0                ),
        .testmode_i        ( 1'b0              ),
        .ndmreset_o        ( ndmreset          ),
        .ndmreset_ack_i    ( '0                ),
        .dmactive_o        (                   ), // active debug session TODO
        .debug_req_o       ( dm_debug_req      ),
        .unavailable_i     ( '0                ),
        .hartinfo_i        ( HARTINFO          ),

        .slave_req_i       ( dm_req            ),
        .slave_we_i        ( dm_we             ),
        .slave_addr_i      ( dm_addr           ),
        .slave_be_i        ( dm_be             ),
        .slave_wdata_i     ( dm_wdata          ),
        .slave_rdata_o     ( dm_rdata          ),

        .master_req_o      ( sb_req            ),
        .master_add_o      ( sb_addr           ),
        .master_we_o       ( sb_we             ),
        .master_wdata_o    ( sb_wdata          ),
        .master_be_o       ( sb_be             ),
        .master_gnt_i      ( sb_gnt            ),
        .master_r_valid_i  ( sb_rvalid         ),
        .master_r_err_i    ( 1'b0              ),
        .master_r_other_err_i ( 1'b0           ),
        .master_r_rdata_i  ( sb_rdata          ),

        .dmi_rst_ni        ( rstn_i            ),
        .dmi_req_valid_i   ( dmi_req_valid     ),
        .dmi_req_ready_o   ( dmi_req_ready     ),
        .dmi_req_i         ( dmi_req           ),
        .dmi_resp_valid_o  ( dmi_resp_valid    ),
        .dmi_resp_ready_i  ( dmi_resp_ready    ),
        .dmi_resp_o        ( dmi_resp          )
    );

endmodule: core_subsystem
