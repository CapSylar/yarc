
module jtag_sim(

        output logic tck_o,
        output logic tms_o,
        output logic trst_no,
        output logic tdi_o,
        input wire tdo_i
    );

    jtag_interface jtag_inst();
    jtag_pkg::debug_mode_if_t dm;

    assign tck_o = jtag_inst.tck;
    assign tms_o = jtag_inst.tms;
    assign tdi_o = jtag_inst.tdi;
    assign trst_no = jtag_inst.trstn;
    assign jtag_inst.tdo = tdo_i;

    initial begin

        // reset some signals
        jtag_inst.tck = 0;
        jtag_inst.tms = 0;
        jtag_inst.trstn = 1'b1;
        jtag_inst.tdi = 0;

        $display("jtag debug is now running");

        dm = new(1 , jtag_inst);

        dm.jtag_reset();
        dm.jtag_softreset();

        //test TAP Controller
        dm.jtag_idcode_test();
        dm.halt_harts();

        $display("halted!");
    end

endmodule
