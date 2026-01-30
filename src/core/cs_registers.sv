// contains all CS registers
// Heavily inspired from Ibex Core (practically copied)

module cs_registers
import csr_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    // read port
    input wire csr_re_i,
    input wire [11:0] csr_addr_i,
    output logic [31:0] csr_rdata_o,

    // write port
    input wire csr_we_i,
    input wire csr_we_ungated_i,
    input wire [31:0] csr_wdata_i,

    // output some cs registers
    output logic [31:0] csr_mepc_o,
    output mtvec_t csr_mtvec_o,
    output mstatus_t csr_mstatus_o,
    output priv_lvl_e current_plvl_o,

    output irqs_t irq_pending_o,

    // mret, traps...
    input wire is_mret_i,
    input wire is_trap_i,
    input var mcause_t trap_mcause_i,
    input wire [31:0] trap_mepc_i,
    input wire [31:0] trap_mtval_i,

    // interrupts
    input wire irq_software_i,
    input wire irq_timer_i,
    input wire irq_external_i,

    // used by the performance counters
    input wire instr_ret_i,

    output logic illegal_csr_accessM_o
);

csr_t csr_addr;
assign csr_addr = csr_t'(csr_addr_i);

// current privilege level
priv_lvl_e current_plvl_d, current_plvl_q;

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (!rstn_i)
        current_plvl_q <= PRIV_LVL_M;
    else
        current_plvl_q <= current_plvl_d;
end

logic [31:0] misa_q;
logic [31:0] mvendorid_q;
logic [31:0] marchid_q;
logic [31:0] mimpid_q;

// CS Registers
// MISA: Machine ISA Register
localparam bit [31:0] MISA_VALUE = 
    (1 << 0)  |  // A
    (1 << 8)  |  // I
    (1 << 12) |  // M
    (1 << 20) |  // U
    (1 << 30);  // M-XLEN = 1 => 32-bit

csr #(.Width(32), .ResetValue(MISA_VALUE)) csr_misa
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i('0), // Read Only
    .wr_data_i('0),
    .rd_data_o(misa_q)
);

// MVENDORID: Machine Vendor ID Register
localparam bit [31:0] MVENDORID = '0; // Non-commercial implementation

csr #(.Width(32), .ResetValue(MVENDORID)) csr_mvendorid
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i('0), // Read Only
    .wr_data_i('0),
    .rd_data_o(mvendorid_q)
);

// MARCHID: Machine Architecture ID Register
localparam bit [31:0] ARCH_ID = 32'd0; // Microarchiture ID

csr #(.Width(32), .ResetValue(ARCH_ID)) csr_marchid
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i('0), // Read Only
    .wr_data_i('0),
    .rd_data_o(marchid_q)
);

// MIMPID: Machine Implementation ID Register
localparam bit [31:0] MIMP_ID = 32'd1;

csr #(.Width(32), .ResetValue(MIMP_ID)) csr_mimpid
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i('0), // Read Only
    .wr_data_i('0),
    .rd_data_o(mimpid_q)
);

// MHARTID: Hart ID Register
localparam logic [31:0] MHART_ID = 32'd0;

mstatus_t mstatus_d, mstatus_q;
logic mstatus_we;
parameter mstatus_t MSTATUS_RST_VALUE = '{
    mie: 1'b0,
    mpie: 1'b1,
    mpp: PRIV_LVL_U,
    mprv: 1'b0
};

// MSTATUS: Machine Status Register
csr #(.Width($bits(mstatus_t)), .ResetValue(MSTATUS_RST_VALUE)) csr_mstatus
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mstatus_we),
    .wr_data_i(mstatus_d),
    .rd_data_o(mstatus_q)
);

mtvec_t mtvec_d, mtvec_q;
logic mtvec_we;

// MTVEC: Machine Trap-Vector Base-Address Register
csr #(.Width($bits(mtvec_t)), .ResetValue('0)) csr_mtvec
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mtvec_we),
    .wr_data_i(mtvec_d),
    .rd_data_o(mtvec_q)
);

// MIP: Machine Interrupt Pending
irqs_t mip_d, mip_q, mip;
logic mip_we;

csr #(.Width($bits(irqs_t)), .ResetValue('0)) csr_mip
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mip_we),
    .wr_data_i(mip_d),
    .rd_data_o(mip_q)
);

// mip is a mix of saved and driven bits
assign mip = '{
    s_software: mip_q.s_software,

    m_software: irq_software_i,
    m_timer:    irq_timer_i,
    m_external: irq_external_i
};

irqs_t mie_d, mie_q;
logic mie_we;

// MIE: Machine Interrupt Enable Register
csr #(.Width($bits(irqs_t)), .ResetValue('0)) csr_mie
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mie_we),
    .wr_data_i(mie_d),
    .rd_data_o(mie_q)
);

logic mcountinhibit_we;
logic [31:0] mcountinhibit_d, mcountinhibit_q;

// MCOUNTINHIBIT: Machine Counter-Inhibit CSR
csr #(.Width(32), .ResetValue('0)) csr_mcountinhibit
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mcountinhibit_we),
    .wr_data_i(mcountinhibit_d),
    .rd_data_o(mcountinhibit_q)
);

logic [63:0] mhpmcounter [32];
logic [31:0] mhpmcounter_we;
logic [31:0] mhpmcounterh_we;
logic [31:0] mhpmcounter_incr;

logic [4:0] mhpmcounter_idx; // read index

assign mhpmcounter_idx = csr_addr_i[4:0];

always_comb
begin
    mhpmcounter_incr[0] = 1'b1; // mcycle
    mhpmcounter_incr[1] = 1'b0; // nothing here
    mhpmcounter_incr[2] = instr_ret_i; // minstret
end

// MCYCLE: Machine Cycle Register
perf_counter csr_mcycle
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .inc_en_i(mhpmcounter_incr[0] & ~mcountinhibit_q[0]),
    
    .we_i(mhpmcounter_we[0]),
    .weh_i(mhpmcounterh_we[0]),
    .w_value_i(csr_wdata_i),
    .value_o(mhpmcounter[0])
);

// MINSTRET: Machine Instruction Retired Register
perf_counter csr_minstret
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .inc_en_i(mhpmcounter_incr[2] & ~mcountinhibit_q[2]),
    
    .we_i(mhpmcounter_we[2]),
    .weh_i(mhpmcounterh_we[2]),
    .w_value_i(csr_wdata_i),
    .value_o(mhpmcounter[2])
);

// TODO: Implement
// MCOUNTEREN: Machine Counter-Enable Register
// csr #(.Width(32), .ResetValue('0)) csr_mcounteren
// (
//     .clk_i(clk_i),
//     .rstn_i(rstn_i),
//     .wr_en_i(mcounteren_wen),
//     .wr_data_i(mcounteren_d),
//     .rd_data_o(mcounteren_q)
// );

logic mscratch_we;
logic [31:0] mscratch_d, mscratch_q;

// MSCRATCH: Machine Scratch Register
csr #(.Width(32), .ResetValue('0)) csr_mscratch
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mscratch_we),
    .wr_data_i(mscratch_d),
    .rd_data_o(mscratch_q)
);

logic [31:0] mepc_d, mepc_q;
logic mepc_we;

// MEPC: Machine Exception Program Counter
csr #(.Width(32), .ResetValue('0)) csr_mepc
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mepc_we),
    .wr_data_i(mepc_d),
    .rd_data_o(mepc_q)
);

mcause_t mcause_d, mcause_q;
logic mcause_we;

// MCAUSE: Machine Cause Register
csr #(.Width($bits(mcause_t)), .ResetValue('0)) csr_mcause
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mcause_we),
    .wr_data_i(mcause_d),
    .rd_data_o(mcause_q)
);

logic mtval_we;
logic [31:0] mtval_d, mtval_q;

// MTVAL: Machine Trap Value Register
csr #(.Width(32), .ResetValue('0)) csr_mtval
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(mtval_we),
    .wr_data_i(mtval_d),
    .rd_data_o(mtval_q)
);

/*
 * DCSR: Debug Control and Status Register
 */

logic dcsr_we;
dcsr_t dcsr_wdata, dcsr_rdata;

localparam dcsr_t DCSR_DEFAULT = '{
    xdebugver: 4,
    _reserved2: '0,
    ebreakm: '0,
    _reserved1: '0,
    ebreaks: '0,
    ebreaku: '0,
    stepie: '0,
    stopcount: '0,
    stoptime: '0,
    cause: '0,
    _reserved0: '0,
    mprven: '0,
    nmip: '0,
    step: '0,
    prv: '0
};

csr #(.Width($bits(dcsr_t)), .ResetValue(DCSR_DEFAULT)) csr_dcsr
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(dcsr_we),
    .wr_data_i(dcsr_wdata),
    .rd_data_o(dcsr_rdata)
);

/*
 * DPC: Debug PC
*/

logic dpc_we;
logic [31:0] dpc_wdata, dpc_rdata;

csr #(.Width(32), .ResetValue('0)) csr_dpc
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(dpc_we),
    .wr_data_i(dpc_wdata),
    .rd_data_o(dpc_rdata)
);

/*
 * Debug Scratch Register 0
*/

logic dscratch0_we;
logic [31:0] dscratch0_rdata;

csr #(.Width(32), .ResetValue('0)) csr_dscratch0
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(dscratch0_we),
    .wr_data_i(csr_wdata_i),
    .rd_data_o(dscratch0_rdata)
);

/*
 * Debug Scratch Register 1
*/

logic dscratch1_we;
logic [31:0] dscratch1_rdata;

csr #(.Width(32), .ResetValue('0)) csr_dscratch1
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .wr_en_i(dscratch1_we),
    .wr_data_i(csr_wdata_i),
    .rd_data_o(dscratch1_rdata)
);

logic [31:0] csr_rdata;
logic illegal_csr_read;

// read logic
always_comb begin: csr_read
    csr_rdata = '0;
    illegal_csr_read = 1'b0;

    // catch the pmps
    if (csr_addr >= CSR_PMPADDR0 && csr_addr <= CSR_PMPADDR15) begin
        // zeroes for now
    end else if (csr_addr >= CSR_PMPCFG0 && csr_addr <= CSR_PMPCFG3) begin
        // zeroes for now
    end else begin
        unique case (csr_addr)
            CSR_MISA: csr_rdata = misa_q;
            CSR_MVENDORID: csr_rdata = mvendorid_q;
            CSR_MHARTID: csr_rdata = MHART_ID;
            CSR_MIMPID: csr_rdata = mimpid_q;
            CSR_MARCHID: csr_rdata = marchid_q;

            CSR_MSCRATCH: csr_rdata = mscratch_q;
            CSR_MSTATUS:
            begin
                csr_rdata[CSR_MSTATUS_MIE_BIT] = mstatus_q.mie;
                csr_rdata[CSR_MSTATUS_MPIE_BIT] = mstatus_q.mpie;
                csr_rdata[CSR_MSTATUS_MPP_BIT_HIGH:CSR_MSTATUS_MPP_BIT_LOW] = mstatus_q.mpp;
                csr_rdata[CSR_MSTATUS_MPRV_BIT] = mstatus_q.mprv;
            end
            CSR_MSTATUSH: csr_rdata = '0;
            CSR_MTVEC: csr_rdata = mtvec_q;
            CSR_MTVAL: csr_rdata = mtval_q;
            CSR_MEPC: csr_rdata = mepc_q;
            CSR_MIE:
            begin
                csr_rdata[CSR_MSI_BIT] = mie_q.m_software;
                csr_rdata[CSR_MTI_BIT] = mie_q.m_timer;
                csr_rdata[CSR_MEI_BIT] = mie_q.m_external;
            end
            CSR_MIP:
            begin
                csr_rdata[CSR_MSI_BIT] = mip_d.m_software;
                csr_rdata[CSR_MTI_BIT] = mip_d.m_timer;
                csr_rdata[CSR_MEI_BIT] = mip_d.m_external;
            end
            CSR_MCAUSE:
            begin
                csr_rdata[CSR_MCAUSE_IRQ_BIT] = mcause_q.irq;
                csr_rdata[CSR_MCAUSE_CODE_BIT_HIGH:CSR_MCAUSE_CODE_BIT_LOW] = mcause_q.trap_code;
            end
            CSR_MCOUNTINHIBIT: csr_rdata = mcountinhibit_q;
            CSR_MCOUNTEREN: csr_rdata = '0;

            // Performance Counters
            CSR_MCYCLE, CSR_MINSTRET: // lower half
            begin
                csr_rdata = mhpmcounter[mhpmcounter_idx][31:0];
            end

            CSR_MCYCLEH, CSR_MINSTRETH: // upper half
            begin
                csr_rdata = mhpmcounter[mhpmcounter_idx][63:32];
            end

            CSR_DCSR: begin
                csr_rdata = dcsr_rdata;
            end

            CSR_DPC: begin
                csr_rdata = dpc_rdata;
            end

            CSR_DSCRATCH0: begin
                csr_rdata = dscratch0_rdata;
            end

            CSR_DSCRATCH1: begin
                csr_rdata = dscratch1_rdata;
            end

            default: illegal_csr_read = 1'b1;
        endcase
    end
end

wire illegal_csr_write = (csr_addr == CSR_MISA) | 
                         (csr_addr == CSR_MVENDORID) | 
                         (csr_addr == CSR_MHARTID) | 
                         (csr_addr == CSR_MIMPID) |
                         (csr_addr == CSR_MARCHID);

// write logic
always_comb begin: csr_write

    current_plvl_d = current_plvl_q;

    mscratch_we = 1'b0;
    mscratch_d = csr_wdata_i;

    mstatus_we = 1'b0;
    mstatus_d = mstatus_q;

    mtvec_we = 1'b0;
    mtvec_d = mtvec_q;

    mtval_we = 1'b0;
    mtval_d = mtval_q;

    mie_we = 1'b0;
    mie_d = mie_q;

    mip_we = 1'b0;
    mip_d = mip_q;

    mepc_we = 1'b0;
    mepc_d = mepc_q;

    mcause_we = 1'b0;
    mcause_d = mcause_q;

    mcountinhibit_we = 1'b0;
    mcountinhibit_d = mcountinhibit_q;

    mhpmcounter_we = '0;
    mhpmcounterh_we = '0;

    dcsr_we = '0;
    dpc_we = '0;
    dscratch0_we = '0;
    dscratch1_we = '0;

    /*
     * no need to detect non-matching entries since is csr_we is 1
     * then csr_re is 1 and we do the detection in the other case statement
     */

    // CSR read and writes from CSRRW/S/C instructions
    if (csr_we_i)
    begin
        unique case (csr_addr)
            CSR_MSCRATCH: mscratch_we = 1'b1;
            CSR_MSTATUS:
            begin
                mstatus_we = 1'b1;
                mstatus_d = '{
                    mie: csr_wdata_i[CSR_MSTATUS_MIE_BIT],
                    mpie: csr_wdata_i[CSR_MSTATUS_MPIE_BIT],
                    mpp: priv_lvl_e'(csr_wdata_i[CSR_MSTATUS_MPP_BIT_HIGH:CSR_MSTATUS_MPP_BIT_LOW]),
                    mprv: csr_wdata_i[CSR_MSTATUS_MPRV_BIT]
                };

            end
            CSR_MTVEC:
            begin
                mtvec_we = 1'b1;
                mtvec_d = mtvec_t'(csr_wdata_i);
            end
            CSR_MTVAL:
            begin
                mtval_we = 1'b1;
                mtval_d = csr_wdata_i;
            end
            CSR_MIE:
            begin
                mie_we = 1'b1;
                mie_d = '{
                    s_software: csr_wdata_i[CSR_SSI_BIT],
                    m_software: csr_wdata_i[CSR_MSI_BIT],
                    m_timer: csr_wdata_i[CSR_MTI_BIT],
                    m_external: csr_wdata_i[CSR_MEI_BIT]
                };
            end
            CSR_MIP:
            begin
                mip_we =  1'b1;
                mip_d = '{
                    s_software: csr_wdata_i[CSR_SSI_BIT],
                    m_software: '0,
                    m_timer: '0,
                    m_external: '0
                };
            end
            CSR_MEPC:
            begin
                mepc_we = 1'b1;
                mepc_d = {csr_wdata_i[31:2], 2'b00}; // IALIGN=32
            end
            CSR_MCAUSE:
            begin
                mcause_we = 1'b1;
                mcause_d = '{
                    irq: csr_wdata_i[CSR_MCAUSE_IRQ_BIT],
                    trap_code: csr_wdata_i[CSR_MCAUSE_CODE_BIT_HIGH:CSR_MCAUSE_CODE_BIT_LOW]
                };

            end
            CSR_MCOUNTINHIBIT:
            begin
                mcountinhibit_we = 1'b1;
                mcountinhibit_d = {29'd0, csr_wdata_i[2], 1'b0, csr_wdata_i[0]};
            end
            
            // performance counters
            CSR_MCYCLE, CSR_MINSTRET:
            begin
                mhpmcounter_we[mhpmcounter_idx] = 1'b1;
            end

            CSR_MCYCLEH, CSR_MINSTRETH:
            begin
                mhpmcounterh_we[mhpmcounter_idx] = 1'b1;
            end

            CSR_DCSR: begin
                dcsr_we = 1'b1;
                dcsr_wdata = '{
                    // readonly
                    xdebugver: dcsr_rdata[CSR_DCSR_XDEBUGVER_BIT_HIGH: CSR_DCSR_XDEBUGVER_BIT_LOW],
                    _reserved0: '0,
                    _reserved1: '0,
                    _reserved2: '0,

                    // writeable fields
                    ebreakm:  csr_wdata_i[CSR_DCSR_EBREAKM_BIT],
                    ebreaks:  csr_wdata_i[CSR_DCSR_EBREAKS_BIT],
                    ebreaku:  csr_wdata_i[CSR_DCSR_EBREAKU_BIT],
                    stepie:   csr_wdata_i[CSR_DCSR_STEPIE_BIT],
                    stopcount:csr_wdata_i[CSR_DCSR_STOPCOUNT_BIT],
                    stoptime: csr_wdata_i[CSR_DCSR_STOPTIME_BIT],
                    cause:    csr_wdata_i[CSR_DCSR_CAUSE_BIT_HIGH: CSR_DCSR_CAUSE_BIT_LOW],
                    mprven:   csr_wdata_i[CSR_DCSR_MPRVEN_BIT],
                    nmip:     csr_wdata_i[CSR_DCSR_NMIP_BIT],
                    step:     csr_wdata_i[CSR_DCSR_STEP_BIT],
                    prv:      csr_wdata_i[CSR_DCSR_PRV_BIT_HIGH: CSR_DCSR_PRV_BIT_LOW]
                };
            end

            CSR_DPC: begin
                dpc_we = 1'b1;
                dpc_wdata = csr_wdata_i;
            end

            CSR_DSCRATCH0: begin
                dscratch0_we = 1'b1;
            end

            CSR_DSCRATCH1: begin
                dscratch1_we = 1'b1;
            end
            default;
        endcase
    end

    /*
     * internal updates
     */

    unique case (1'b1)
        is_mret_i:
        begin
            current_plvl_d = mstatus_q.mpp;

            mstatus_we = 1'b1;
            mstatus_d.mie = mstatus_q.mpie;

            if (mstatus_q.mpp != PRIV_LVL_M)
                mstatus_d.mprv = '0;

            mstatus_d.mpie = '0;
            mstatus_d.mpp = PRIV_LVL_U;
        end
        is_trap_i:
        begin
            // all traps cause the core to transition to M-mode
            current_plvl_d = PRIV_LVL_M;

            // save the current privilege mode inside mpp
            mstatus_we = 1'b1;
            mstatus_d.mpp = current_plvl_q;
            // the interrutps are now globally disabled
            mstatus_d.mie = 1'b0;
            // save the old interrupt enable
            mstatus_d.mpie = mstatus_q.mie;

            // update mcause
            mcause_we = 1'b1;
            mcause_d = trap_mcause_i;

            // update mepc
            mepc_we = 1'b1;
            mepc_d = trap_mepc_i;

            mtval_we = 1'b1;
            mtval_d = trap_mtval_i;
        end
        default:;
    endcase
end

// assign outputs
assign csr_rdata_o = csr_rdata;
assign csr_mepc_o = mepc_q;
assign csr_mtvec_o = mtvec_q;
assign csr_mstatus_o = mstatus_q;
assign current_plvl_o = current_plvl_q;
assign irq_pending_o = mip & mie_q;

assign illegal_csr_accessM_o = (illegal_csr_read & csr_re_i) | (illegal_csr_write & csr_we_ungated_i);

endmodule: cs_registers
