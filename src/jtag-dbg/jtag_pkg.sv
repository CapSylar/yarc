// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * jtag_pkg.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 */

`timescale 1ns / 1ps

package jtag_pkg;
   // import rvdig_pkg::*;
   parameter int unsigned JTAG_SOC_INSTR_WIDTH                                 = 5;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_IDCODE                 = 5'b00001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DTMCSR                 = 5'b10000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DMIACCESS              = 5'b10001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_AXIREG                 = 5'b00100;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BBMUXREG               = 5'b00101;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_CONFREG                = 5'b00110;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_TESTMODEREG            = 5'b01000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BISTREG                = 5'b01001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BYPASS                 = 5'b11111;
   parameter int unsigned JTAG_SOC_IDCODE_WIDTH                                = 32;
   parameter int unsigned JTAG_SOC_BBMUXREG_WIDTH                              = 21;
   parameter int unsigned JTAG_SOC_CLKGATEREG_WIDTH                            = 11;
   parameter int unsigned JTAG_SOC_CONFREG_WIDTH                               = 16;
   parameter int unsigned JTAG_SOC_TESTMODEREG_WIDTH                           =  4;
   parameter int unsigned JTAG_SOC_BISTREG_WIDTH                               = 20;

   parameter int unsigned JTAG_CLUSTER_INSTR_WIDTH                             = 0;

   parameter int unsigned JTAG_IDCODE_WIDTH                                    = JTAG_SOC_IDCODE_WIDTH;
   parameter int unsigned JTAG_INSTR_WIDTH                                     = JTAG_SOC_INSTR_WIDTH;

   // debug causes
   localparam logic [2:0] CauseBreakpoint = 3'h1;
   localparam logic [2:0] CauseTrigger    = 3'h2;
   localparam logic [2:0] CauseRequest    = 3'h3;
   localparam logic [2:0] CauseSingleStep = 3'h4;

   parameter DMI_SIZE = 32+7+2;

   parameter C_ADD1 = 2'b10;
   parameter C_ADD2 = 4'b1001;

   parameter C_ADDI1 = 2'b01;
   parameter C_ADDI2 = 3'b000;

   parameter C_ANDI1 = 2'b01;
   parameter C_ANDI2 = 2'b10;
   parameter C_ANDI3 = 3'b100;

   parameter C_LUI1 = 2'b01;
   parameter C_LUI2 = 3'b011;

   parameter C_LW1 = 2'b00;
   parameter C_LW2 = 3'b010;

   parameter ADD1 = 7'b0110011;
   parameter ADD2 = 3'b000;
   parameter ADD3 = 7'b0000000;

   parameter ADDI1 = 7'b0010011;
   parameter ADDI2 = 3'b000; 

   parameter MUL1 = 7'b0110011;
   parameter MUL2 = 3'b000;
   parameter MUL3 = 7'b0000001;

   parameter DIV1 = 7'b0110011;
   parameter DIV2 = 3'b100;
   parameter DIV3 = 7'b0000001;

   parameter LW1 = 7'b0000011;
   parameter LW2 = 3'b010;

   parameter SW1 = 7'b0100011;
   parameter SW2 = 3'b010;

   parameter BEQ1 = 7'b1100011;
   parameter BEQ2 = 3'b000; 

   parameter BNE1 = 7'b1100011;
   parameter BNE2 = 3'b001;

   parameter JAL = 7'b1101111;

   parameter LUI = 7'b0110111;

   parameter OR1 = 7'b0110011;
   parameter OR2 = 3'b110;
   parameter OR3 = 7'b0000000;

   parameter AND1 = 7'b0110011;
   parameter AND2 = 3'b111;
   parameter AND3 = 7'b0000000; 

   parameter NOP = 16'b0000000000000001;

   parameter X0 = 5'b0;
   parameter X1 = 5'b00001;
   parameter X2 = 5'b00010;
   parameter X3 = 5'b00011;
   parameter X11 = 5'b01011;
   parameter X12 = 5'b01100;
   parameter X13 = 5'b01101;
   parameter X14 = 5'b01110;
   parameter X15 = 5'b01111;

   localparam integer unsigned NUM_TAPS = 2;
    
   typedef struct
   {
      logic clk;
      logic [31:0] pc;
      logic [31:0] instr;
      logic [31:0] dbg_exec_after_step;
   } dbg_cpu_access;

   task automatic jtag_wait_halfperiod(input int cycles);
      //don't use under 50 cycles
      #(50*cycles);
   endtask

   task automatic jtag_clock(
      input int cycles,
      ref logic s_tck
   );
      for(int i=0; i<cycles; i=i+1) begin
         s_tck = 1'b0;
         jtag_wait_halfperiod(1);
         s_tck = 1'b1;
         jtag_wait_halfperiod(1);
         s_tck = 1'b0;
      end
   endtask

   /*
      the jtag is aware that it is part of a bigger chain, as such, data being shifting in
      and out will be formatted accordingly

      size: size of the jtag register
      instr: address of the jtag register
      num_taps: number of jtag taps in the chain
      DR_TOTAL_SIZE: size of data shifted in and out of the chain, = size of this register + size of the bypass registers of all other taps (1bit * (num_taps-1))
      the total size of all selected data registers on the chain depends on the IR in all taps, in this case
      we assume that all others taps will have their IRs set to zero so we talk to the BYPASS registers of these taps

      IR_TOTAL_SIZE: size of all instruction registers of all taps on the chain = num_taps * 5bits in this case
   */

   class JTAG_reg #(int unsigned size = 32,
         logic [(JTAG_CLUSTER_INSTR_WIDTH+JTAG_SOC_INSTR_WIDTH)-1:0] instr = 'h0,
         int unsigned num_taps,
         int unsigned DR_TOTAL_SIZE = ((num_taps-1) * 1 + size), // size of the DR in the targeted TAP + size of all the others in BYPASS mode (1-bit each)
         int unsigned IR_TOTAL_SIZE = (num_taps * 5)
      );

      int unsigned tap_index; // holds the current tap index

      // In the shift IR case, prepares the data (address of the IR) shited in
      function logic[IR_TOTAL_SIZE-1:0] prep_ir_data(logic [size-1:0] instr);
         prep_ir_data = IR_TOTAL_SIZE'(instr);
         prep_ir_data = prep_ir_data << (tap_index*5);
      endfunction: prep_ir_data

      // In the shift DR case, prepares the data shifted in, adding appropriate padding
      function logic [DR_TOTAL_SIZE-1:0] prep_dr_data(logic [size-1:0] data);
         prep_dr_data = DR_TOTAL_SIZE'(data);
         prep_dr_data = prep_dr_data << tap_index;
      endfunction: prep_dr_data

      // following a capture Dr and Shift Dr, extracts the wanted data from the "word" shifted out
      function logic [size-1:0] get_dr_data(logic [DR_TOTAL_SIZE-1:0] data);
         get_dr_data = data[tap_index +: size];
      endfunction: get_dr_data

      function new(int tap_index);
         this.tap_index = tap_index;
      endfunction: new
      
      task idle(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 10
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
      endtask

      task update_and_goto_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 110
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         jtag_clock(1, s_tck);
      endtask

      task jtag_goto_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_IR : tms sequence 1100
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_DR : tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_UPDATE_DR_FROM_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //$display("I am at jtag_goto_UPDATE_DR_FROM_SHIFT_DR (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from SHIFT DR to UPDATE DR : tms sequence 11
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         // back to Idle : tms sequence 0
         s_tms   = 1'b0;
         //wait a bit
         jtag_clock(50, s_tck);
      endtask

      task jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(
         output logic [size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [DR_TOTAL_SIZE-1:0] temp;

         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from UPDATE DR to CAPTURE DR : tms sequence 10
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         //back to Idle: tms sequence 110
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         jtag_clock(6, s_tck);
         // go to SHIFT DR: tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         for(int i=0; i<DR_TOTAL_SIZE; i=i+1) begin
            if (i == (DR_TOTAL_SIZE-1))
               s_tms = 1'b1;
            s_tdi = 1'b0;
            jtag_clock(1, s_tck);
            temp[i] = s_tdo;
         end

         dataout = get_dr_data(temp);
      endtask

      // task jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(
      //    output logic [DMI_SIZE-1:0] dataout,
      //    ref logic s_tck,
      //    ref logic s_tms,
      //    ref logic s_trstn,
      //    ref logic s_tdi,
      //    ref logic s_tdo
      // );
      //    //$display("I am at jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA (%t)",$realtime);
      //    s_trstn = 1'b1;
      //    s_tdi   = 1'b1;
      //    // from UPDATE DR to CAPTURE DR : tms sequence 110
      //    s_tms   = 1'b1;
      //    jtag_clock(2, s_tck);
      //    s_tms   = 1'b0;
      //    jtag_clock(1, s_tck);
      //    // go to SHIFT DR
      //    s_tms   = 1'b0;
      //    jtag_clock(1, s_tck);
      //    s_tms   = 1'b0;
      //    for(int i=0; i<DMI_SIZE; i=i+1) begin
      //       if (i == (DMI_SIZE-1))
      //          s_tms = 1'b1;
      //       s_tdi = 1'b0;
      //       jtag_clock(1, s_tck);
      //       dataout[i] = s_tdo;
      //    end

      // endtask

      task jtag_shift_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         logic [IR_TOTAL_SIZE-1:0] prp_instr = prep_ir_data(instr);
         s_trstn = 1'b1;
         s_tms   = 1'b0;

         for(int i = 0 ; i < IR_TOTAL_SIZE ; ++i) begin
            if (i == (IR_TOTAL_SIZE-1))
                 s_tms = 1'b1;
            s_tdi = prp_instr[i];
            jtag_clock(1, s_tck);
         end
      endtask

      task jtag_shift_NBITS_SHIFT_DR (
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         const ref logic s_tdo
      );
         logic [DR_TOTAL_SIZE-1:0] dr_data = prep_dr_data(datain);
         logic [DR_TOTAL_SIZE-1:0] dr_dataout;

         s_trstn = 1'b1;
         s_tms   = 1'b0;

         for(int i=0; i<DR_TOTAL_SIZE; i=i+1) begin
            if (i == (DR_TOTAL_SIZE-1))
               s_tms = 1'b1;
            s_tdi = dr_data[i];
            jtag_clock(1, s_tck);
            dr_dataout[i] = s_tdo;
         end

         // extract the needed data
         dataout = get_dr_data(dr_dataout);
      endtask

      task shift_nbits_noex(
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<numbits; i=i+1) begin
            s_tdi = datain[i];
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end
      endtask

      task start_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      task goto_shift_state_n_shift(
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         const ref logic s_tdo
      );
           this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
           this.jtag_shift_NBITS_SHIFT_DR(datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
           // Note, does not return to idle
      endtask

      task setIR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      // NOTE: returns to idle when shifting ends
      task goto_shift_state_n_shift_n_idle(
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         const ref logic s_tdo
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_NBITS_SHIFT_DR(datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

   endclass

   // task automatic jtag_bypass_test(
   //    ref logic s_tck,
   //    ref logic s_tms,
   //    ref logic s_trstn,
   //    ref logic s_tdi,
   //    ref logic s_tdo
   // );
   //    automatic JTAG_reg #(.size(255), .instr({JTAG_SOC_BYPASS}), .num_taps(NUM_TAPS)) jtag_bypass = new(this.current_tap);
   //              logic [255:0] result_data;
   //    automatic logic [255:0] test_data = {     32'hDEADBEEF, 32'h0BADF00D, 32'h01234567, 32'h89ABCDEF,
   //                                              32'hAAAABBBB, 32'hCCCCDDDD, 32'hEEEEFFFF, 32'h00001111};
   //    jtag_bypass.setIR(s_tck, s_tms, s_trstn, s_tdi);
   //    jtag_bypass.goto_shift_state_n_shift_n_idle(test_data, result_data, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
   //    if (test_data[253:0] === result_data[254:1])
   //       $display("[JTAG] Bypass Test Passed (%t)", $realtime);
   //    else
   //    begin
   //       $display("[JTAG] Bypass Test Failed");
   //       $display("[JTAG]   LSB WORD TEST = %h (%t)",test_data[31:0], $realtime);
   //       $display("[JTAG]   LSB WORD RES  = %h (%t)",result_data[32:1], $realtime);
   //    end
   // endtask

   // class test_mode_if_t;

   //    task init(
   //       ref logic s_tck,
   //       ref logic s_tms,
   //       ref logic s_trstn,
   //       ref logic s_tdi
   //    );
   //       JTAG_reg #(.size(256), .instr({JTAG_SOC_CONFREG})) jtag_soc_dbg = new;
   //       jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
   //       $display("[test_mode_if] %t - Init", $realtime);
   //    endtask

      // task set_confreg(
      //    input  logic [8:0] confreg,
      //    output logic [8:0] dataout,
      //    ref logic s_tck,
      //    ref logic s_tms,
      //    ref logic s_trstn,
      //    ref logic s_tdi,
      //    ref logic s_tdo
      // );
      //    logic [8+1:0] confreg_int, dataout_int; //extra bit for bypass
      //    JTAG_reg #(.size(256), .instr({JTAG_SOC_CONFREG})) jtag_soc_dbg = new;

      //    confreg_int = {1'b0, confreg};

      //    jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
      //    jtag_soc_dbg.shift_nbits(9+1, confreg_int, dataout_int, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      //    jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
      //    dataout = dataout_int[8:0];
      //    $display("[test_mode_if] %t - Setting confreg to value %X.", $realtime, confreg);
      // endtask

      // task get_confreg(
      //    input logic [8:0] confreg,
      //    output bit  [8:0] rec,
      //    ref logic s_tck,
      //    ref logic s_tms,
      //    ref logic s_trstn,
      //    ref logic s_tdi,
      //    ref logic s_tdo
      // );
      //    logic [8+1:0] dataout; //extra bit for bypass
      //    JTAG_reg #(.size(256), .instr({JTAG_SOC_CONFREG})) jtag_soc_dbg = new;
      //    jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
      //    jtag_soc_dbg.shift_nbits(9+1, confreg, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      //    jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
      //    rec = dataout [8:0];
      //    // `DEBUG_MANAGER_INST.printf(STDOUT, 0, $sformatf("%s[TEST_MODE_IF] %s%t - %sGet confreg value = %X%s\n", `ESC_BLUE_BOLD, `ESC_WHITE, $realtime, `ESC_MAGENTA, rec, `ESC_DEFAULT));
      // endtask

   // endclass

   import dm::*;
   class debug_mode_if_t;

      virtual jtag_interface jtag;
      int num_taps;
      int trigger_count; // number of triggers the tests can use

      // the current tap we are talking to
      int current_tap; // not touched directly

      function void set_current_tap(int tap_num);
         this.current_tap = tap_num;
      endfunction: set_current_tap

      function new(int num_taps, virtual jtag_interface vif);
         this.jtag = vif;
         this.num_taps = num_taps;

         this.set_current_tap(0); // default
         this.trigger_count = 0;
      endfunction

   task jtag_idcode_test();

      logic [31:0] idcode;
      this.set_current_tap(0);
      this.init(0 , 6 /*number of triggers*/ ); // init
      this.jtag_get_idcode(idcode);
      $display("[JTAG] Tap ID CORE0: %h (%t)",idcode, $realtime);
   
      this.set_current_tap(1);
      this.init(0 , 6 /*number of triggers*/ ); // init
      this.jtag_get_idcode(idcode);
      $display("[JTAG] Tap ID CORE1: %h (%t)",idcode, $realtime);
   endtask

   // TODO:find a general solution for the number of taps situation
   task jtag_get_idcode(output logic [31:0] idcode);
      if (this.num_taps == 2) begin
         automatic JTAG_reg #(.size(JTAG_IDCODE_WIDTH), .instr({JTAG_SOC_IDCODE}), .num_taps(2)) jtag_idcode = new (this.current_tap);
         jtag_idcode.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         jtag_idcode.goto_shift_state_n_shift_n_idle('0, idcode, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
      end
      else begin
         automatic JTAG_reg #(.size(JTAG_IDCODE_WIDTH), .instr({JTAG_SOC_IDCODE}), .num_taps(1)) jtag_idcode = new (this.current_tap);
         jtag_idcode.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         jtag_idcode.goto_shift_state_n_shift_n_idle('0, idcode, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
      end
      
      
   endtask

   task automatic jtag_reset();
      this.jtag.tms   = 1'b0;
      this.jtag.tck   = 1'b0;
      this.jtag.trstn = 1'b0;
      this.jtag.tdi   = 1'b0;
      jtag_wait_halfperiod(2);
      this.jtag.trstn = 1'b1;
   endtask

   task automatic jtag_softreset();
      this.jtag.tms   = 1'b1;
      this.jtag.trstn = 1'b1;
      this.jtag.tdi   = 1'b0;
      jtag_clock(5, this.jtag.tck); //enter RST
      this.jtag.tms   = 1'b0;
      jtag_clock(1, this.jtag.tck); // back to IDLE
      $display("[JTAG] SoftReset Done(%t)",$realtime);
   endtask
   // TODO:find a general solution for the number of taps situation
      task init_dmi_access();
         
         if (this.num_taps == 2) begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DMIACCESS}), .num_taps(2)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end
         else begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DMIACCESS}), .num_taps(1)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end

      endtask
   // TODO:find a general solution for the number of taps situation
      task init_dtmcs();

         if (this.num_taps == 2) begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(2)) jtag_soc_dbg = new (this.current_tap);
         jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end
         else begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(1)) jtag_soc_dbg = new (this.current_tap);
         jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end

      endtask

      task dump_dm_info();

          typedef struct packed {
              logic [31:18] zero1;
              logic         dmihardreset;
              logic         dmireset;
              logic         zero0;
              logic [14:12] idle;
              logic [11:10] dmistat;
              logic [9:4]   abits;
              logic [3:0]   version;
          } dtmcs_t;

         dm::dmstatus_t  dmstatus;
         dtmcs_t dtmcs;

         $display("[JTAG] %t - Init", $realtime);
         this.init_dtmcs();

         this.read_dtmcs(dtmcs);

         $display("[JTAG] %t - Debug Module dtmcs %x: \n\
                             dmihardreset %x \n\
                             dmireset     %x \n\
                             idle         %x \n\
                             dmistat      %x \n\
                             abits        %x \n\
                             version      %x \n",
                  $realtime, dtmcs, dtmcs.dmihardreset, dtmcs.dmireset, dtmcs.idle,
             dtmcs.dmistat, dtmcs.abits, dtmcs.version);

         this.init_dmi_access();

         this.read_debug_reg(dm::DMStatus, dmstatus);

         $display("[JTAG] %t - Debug Module Debug Version: \n\
                 impebreak    %x\n\
                 allhavereset %x\n\
                 anyhavereset %x\n\
                 allrunning   %x\n\
                 anyrunning   %x\n\
                 allhalted    %x\n\
                 anyhalted    %x\n\
                 version      %x\n\
              ", $realtime, dmstatus.impebreak, dmstatus.allhavereset, dmstatus.anyhavereset,
             dmstatus.allrunning, dmstatus.anyrunning, dmstatus.allhalted, dmstatus.anyhalted,
             dmstatus.version);

      endtask


      task set_haltreq(input logic haltreq);

          logic [1:0]     dm_op;
          logic [6:0]     dm_addr;
          logic [31:0]    dm_data;
          dm::dmcontrol_t dmcontrol;

         // TODO: we probably don't need to rescan IR
         this.init_dmi_access();
         this.read_debug_reg(dm::DMControl, dmcontrol);

         dmcontrol.haltreq = haltreq;

         this.write_debug_reg(dm::DMControl, dmcontrol);
         //wait the core to be stalled
         dm_data = '0;
         while(dm_data[8] == 1'b0) begin //anyhalted
            this.set_dmi(
                  2'b01, //read
                  7'h11, //dmstatus
                  32'h0, //whatever
                  {dm_addr, dm_data, dm_op});
         end

      endtask

      task set_resumereq( input logic resumereq );

          logic [1:0]     dm_op;
          logic [6:0]     dm_addr;
          logic [31:0]    dm_data;
          dm::dmcontrol_t dmcontrol;

         // TODO: we probably don't need to rescan IR
         this.init_dmi_access();
         this.read_debug_reg(dm::DMControl, dmcontrol);

         dmcontrol.resumereq = resumereq;

         this.write_debug_reg(dm::DMControl, dmcontrol);

      endtask


      task halt_harts();

         dm::dmcontrol_t dmcontrol;
         dm::dmstatus_t  dmstatus;

         // stop the hart by setting haltreq
         this.read_debug_reg(dm::DMControl, dmcontrol);

         dmcontrol.haltreq = 1'b1;

         this.write_debug_reg(dm::DMControl, dmcontrol);

         // wait until hart is halted
         do begin
            this.read_debug_reg(dm::DMStatus, dmstatus);

         end while(dmstatus.allhalted != 1'b1);

         // clear haltreq
         dmcontrol.haltreq = 1'b0;
         this.write_debug_reg(dm::DMControl, dmcontrol);

      endtask


      task resume_harts();

         dm::dmcontrol_t dmcontrol;
         dm::dmstatus_t  dmstatus;

         // resume the hart by setting resumereq
         this.read_debug_reg(dm::DMControl, dmcontrol);

         dmcontrol.resumereq = 1'b1;

         this.write_debug_reg(dm::DMControl, dmcontrol);

         // wait until hart resumed
         do begin
            this.read_debug_reg(dm::DMStatus, dmstatus);

         end while(dmstatus.allresumeack != 1'b1);

         // clear resumereq
         dmcontrol.resumereq = 1'b0;
         this.write_debug_reg(dm::DMControl, dmcontrol);

      endtask

   // waits for allhalted in dmstatus to become set
   task wait_allhalted();

      dm::dmstatus_t dmstatus;
      do begin
            this.read_debug_reg(dm::DMStatus, dmstatus);
   end while(dmstatus.allhalted != 1'b1);
   endtask

   // sets tdata1 and tdata2 for trigger at tselect
   task set_trigger( logic [31:0] tselect , logic [31:0] tdata1 , logic [31:0] tdata2);
      write_reg_abstract_cmd(riscv::CSR_TSELECT, tselect);
      write_reg_abstract_cmd(riscv::CSR_TDATA1, tdata1);
      write_reg_abstract_cmd(riscv::CSR_TDATA2, tdata2);
   endtask

   // clears trigger at tselect
   task clear_trigger( logic [31:0] index );
      write_reg_abstract_cmd(riscv::CSR_TSELECT, index);
      // writing 0 to tdata1 results in a trigger that is disabled
      write_reg_abstract_cmd(riscv::CSR_TDATA1, 32'd0);
   endtask

   // clears all available triggers
   task clear_all_triggers();
      for ( int i = 0 ; i < this.trigger_count ; ++i )
         this.clear_trigger(i);
   endtask

   // get the first unused trigger in the list
   task get_first_free_trigger( output logic success , output logic [31:0] index );
      logic [31:0] read_value;
      success = 0;

      for ( int i = 0 ; i < this.trigger_count ; ++i )
      begin
         write_reg_abstract_cmd(riscv::CSR_TSELECT , i );
         read_reg_abstract_cmd(riscv::CSR_TDATA1, read_value);
         if ( read_value[2:0] == 3'd0 ) // match on instruction,load,store all disabled
         begin
            success = 1;
            index = i;
            break;
         end
      end
   endtask

   // automatically picks a free trigger
   // the index is then passed to disable trigger to free the corresponding trigger
   task set_breakpoint( input logic [31:0] instruction_address , output logic index , output logic success );
      get_first_free_trigger ( success , index );
      set_manual_breakpoint( index , instruction_address );
   endtask

   // automatically picks a free trigger
   // the index is then passed to disable trigger to free the corresponding trigger
   task set_watchpoint( input logic [31:0] match_address , logic is_store , output logic index , output logic success );
      get_first_free_trigger ( success , index );
      set_manual_watchpoint ( index , is_store , match_address );
   endtask

   // sets dpc = value
   task set_dpc( logic [31:0] value);
      this.write_reg_abstract_cmd(riscv::CSR_DPC, value);
   endtask

   task get_dpc  ( ref logic [31:0] read_value);
      this.read_reg_abstract_cmd(riscv::CSR_DPC, read_value);
   endtask

   // sets the trigger trigger_num to match on the virtual instruction address "instruction_address"
   task set_manual_breakpoint( logic [31:0] tselect , logic [31:0] instruction_address);
      //tdata1 in this case is mcontrol
      this.set_trigger( tselect , 32'h2804104C , instruction_address);
   endtask


   // sets the trigger trigger_num to match when loading/storing to the virtual address "match_address"
   task set_manual_watchpoint ( logic [31:0] tselect , logic is_store , logic [31:0] match_address);
      //tdata1 in this case is mcontrol (changes in case store or load breakpoint)
      if(is_store)
      begin
         this.set_trigger( tselect , 32'h2814104A, match_address);
      end
      else
      begin
         this.set_trigger( tselect , 32'h28141049 , match_address);
      end
   endtask

   // sets the step bit in DCSR
   task set_step_bit (logic value);

      riscv::dcsr_t       dcsr = 0;

      // set step flag in dcsr
      this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
      dcsr.step = value;
      this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
      this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

      assert(dcsr.step == value)
            else begin
               $error("Couldn't write to step in DCSR!");
            end;
   endtask

   // reads the allhalted flag from 
   task is_halted (ref logic read_value);

      dm::dmstatus_t  dmstatus;

         // check if the hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         read_value = dmstatus.allhalted;
   endtask

   // reads a general purpose register, gpr_num_i = 0 for x0 ... 31 for x31
   task read_gpr( input logic [15:0] gpr_num_i , output logic [31:0] data_o );
      read_reg_abstract_cmd( riscv::ABSTR_GPR + gpr_num_i , data_o );
   endtask

   // writes to a general purpose register, gpr_num_i = 0 for x0 ... 31 for x31
   task write_gpr( input logic [15:0] gpr_num_i , input logic [31:0] data_i );
      write_reg_abstract_cmd ( riscv::ABSTR_GPR + gpr_num_i , data_i );
   endtask

   // sets a breakpoint, resume, waits till the harts halt, then clears it
   task set_brk_hit_clear( input logic [31:0] instruction_address );
      logic [31:0] trig_index;
      logic success;

      this.set_breakpoint( instruction_address , trig_index , success );
      if ( success == 0 ) $display(" -%t- ERROR: error setting breakpoint", $realtime);
      this.resume_harts();
      this.wait_allhalted();
      this.clear_trigger( trig_index );
   endtask

      task writeArg (
         input logic arg,
         input logic [31:0] val
      );


          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         dm_addr = arg ? 7'd8 : 7'd4;

         this.set_dmi(
               2'b10,    //write
               dm_addr, //data0 or data1
               val,     //whatever
               {dm_addr, dm_data, dm_op});
      endtask

      task writePrgramBuff (
         input logic [2:0]  arg,
         input logic [31:0] val);

          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         dm_addr = 7'h20 + arg;

         this.set_dmi(
               2'b10,    //write
               dm_addr, //progbuffer_i
               val,     //whatever
               {dm_addr, dm_data, dm_op});

      endtask

      // wait for abstract command to finish, no error checking
      task wait_command (
         input logic [31:0] command);

         dm::abstractcs_t abstractcs;

         // wait until we get a result
         do begin
            this.read_debug_reg(dm::AbstractCS, abstractcs);
         end while(abstractcs.busy == 1'b1);

         assert(abstractcs.cmderr == dm::CmdErrNone)
             else $error("Access to register %x failed with error %x",
                         command[15:0],
                         abstractcs.cmderr);

         // if we got an error we need to clear it for the following accesses
         if (abstractcs.cmderr != dm::CmdErrNone) begin
            abstractcs = '{default:0, cmderr:abstractcs.cmderr};
            this.write_debug_reg(dm::AbstractCS, abstractcs);


            this.read_debug_reg(dm::AbstractCS, abstractcs);

            assert(abstractcs.cmderr == dm::CmdErrNone)
                else begin
                   $error("cmderr bit didn't get cleared");
                end
         end

      endtask


      task set_command (input logic [31:0] command);

          logic [1:0]  dm_op;
          logic [6:0]  dm_addr;
          logic [31:0] dm_data;

         this.set_dmi(
               2'b10,   //write
               7'h17,   //command
               command, //whatever
               {dm_addr, dm_data, dm_op}
            );

         this.wait_command(command);

      endtask
   // TODO:find a general solution for the number of taps situation
      task read_dtmcs(output logic [31:0] dtmcs);
      
         logic [31:0] dataout;
         
         if (this.num_taps == 2) begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(2)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.goto_shift_state_n_shift_n_idle('0, dataout, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
            dtmcs = dataout[31:0];
         end
         else begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(1)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.goto_shift_state_n_shift_n_idle('0, dataout, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
            dtmcs = dataout[31:0];
         end
         
      endtask
   // TODO:find a general solution for the number of taps situation
      task write_dtmcs(input logic [31:0] dtmcs);
      
         logic [31:0] dataout;

         if (this.num_taps == 2) begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(2)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.goto_shift_state_n_shift_n_idle({dtmcs, 1'b0}, dataout, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
         end
         else begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DTMCSR}), .num_taps(1)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.goto_shift_state_n_shift_n_idle({dtmcs, 1'b0}, dataout, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi, this.jtag.tdo);
         end
         

      endtask


      task test_read_sbcs();

         typedef struct packed {
            logic [31:29] sbversion;
            logic [28:23] zero0;
            logic         sbbusyerror;
            logic         sbbusy;
            logic         sbreadonaddr;
            logic [19:17] sbaccess;
            logic         sbautoincrement;
            logic         sbreadondata;
            logic [14:12] sberror;
            logic [11:5]  sbasize;
            logic         sbaccess128;
            logic         sbaccess64;
            logic         sbaccess32;
            logic         sbaccess16;
            logic         sbaccess8;
         } sbcs_t;

         sbcs_t sbcs;

         this.read_debug_reg(dm::SBCS, sbcs);


         $display("[JTAG] %t - Debug Module System Bus Access Control and Status: \n\
                 sbbusy          %x\n\
                 sbreadonaddr    %x\n\
                 sbaccess        %x\n\
                 sbautoincrement %x\n\
                 sbreadondata    %x\n\
                 sberror         %x\n\
                 sbasize         %x\n\
                 sbaccess32      %x\
              ", $realtime, sbcs.sbbusy, sbcs.sbreadonaddr, sbcs.sbaccess, sbcs.sbautoincrement,
                             sbcs.sbreadondata, sbcs.sberror, sbcs.sbasize, sbcs.sbaccess32);

         assert(sbcs.sbbusy == 1'b0)
             else $error("sb is busy even though we are idling");
         assert(sbcs.sberror == 2'b0)
             else $error("sb is in some error state");
         assert(sbcs.sbasize == 6'd32)
             else $error("sbasize is not XLEN=32");
         assert(sbcs.sbaccess32 == 1'b1)
             else $error("sbaccess32 is should be supported");
         assert(sbcs.sbaccess16 == 1'b0)
             else $error("sbaccess16 is signaled as supported");
         assert(sbcs.sbaccess8 == 1'b0)
             else $error("sbaccess8 is signaled as supported");

      endtask

      task test_read_abstractcs();

         dm::abstractcs_t abstractcs;

         read_debug_reg(dm::AbstractCS, abstractcs);
         $display("[JTAG] %t - Abstractcs is %x (progbufsize %x, busy %x, cmderr %x, datacount %x)",
                   $realtime, abstractcs, abstractcs.progbufsize, abstractcs.busy,
                   abstractcs.cmderr, abstractcs.datacount);

         assert(abstractcs.progbufsize == 5'h0)
             else $error("progbufsize is not 0");
         assert(abstractcs.datacount == 4'h2)
             else $error("datacount is not 2");

      endtask
   // TODO:find a general solution for the number of taps situation
      task set_dmi(
         input  logic [1:0]  op_i,
         input  logic [6:0]  address_i,
         input  logic [31:0] data_i,
         output logic [DMI_SIZE-1:0]  data_o
      );
         logic [DMI_SIZE-1:0] buffer;
         logic [DMI_SIZE-1:0]   buffer_riscv;

         if (this.num_taps == 2) begin
            JTAG_reg #(.size(DMI_SIZE), .instr({JTAG_SOC_DMIACCESS}), .num_taps(2)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);

            jtag_soc_dbg.goto_shift_state_n_shift({address_i,data_i,op_i}, buffer, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi , this.jtag.tdo);
            jtag_soc_dbg.jtag_goto_UPDATE_DR_FROM_SHIFT_DR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
            jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(buffer, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi , this.jtag.tdo);

            buffer_riscv = buffer[DMI_SIZE-1:0];

            //while(buffer_riscv[1:0] == 2'b11) begin
            //   //$display("buffer is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[8:2], buffer[DMI_SIZE-1:9], $realtime);
            //   jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
            //   buffer_riscv = buffer[DMI_SIZE:1];
            //end
            //$display("dataout is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[40:34],  buffer[33:2], $realtime);

            data_o[1:0]   = buffer_riscv[1:0];
            data_o[40:34] = buffer_riscv[40:34];
            data_o[33:2]  = buffer_riscv[33:2];
            jtag_soc_dbg.idle(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end
         else begin
            JTAG_reg #(.size(32), .instr({JTAG_SOC_DMIACCESS}), .num_taps(1)) jtag_soc_dbg = new (this.current_tap);
            jtag_soc_dbg.setIR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);

            jtag_soc_dbg.goto_shift_state_n_shift({address_i,data_i,op_i}, buffer, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi , this.jtag.tdo);
            jtag_soc_dbg.jtag_goto_UPDATE_DR_FROM_SHIFT_DR(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
            jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(buffer, this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi , this.jtag.tdo);

            buffer_riscv = buffer[DMI_SIZE-1:0];

            //while(buffer_riscv[1:0] == 2'b11) begin
            //   //$display("buffer is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[8:2], buffer[DMI_SIZE-1:9], $realtime);
            //   jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
            //   buffer_riscv = buffer[DMI_SIZE:1];
            //end
            //$display("dataout is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[40:34],  buffer[33:2], $realtime);

            data_o[1:0]   = buffer_riscv[1:0];
            data_o[40:34] = buffer_riscv[40:34];
            data_o[33:2]  = buffer_riscv[33:2];
            jtag_soc_dbg.idle(this.jtag.tck, this.jtag.tms, this.jtag.trstn, this.jtag.tdi);
         end
         

      endtask

      task dmi_reset();
         logic [31:0] buffer;
         init_dtmcs();

         this.read_dtmcs(buffer);
         buffer[16] = 1'b1;
         this.write_dtmcs(buffer);
         buffer[16] = 1'b0;
         this.write_dtmcs(buffer);
      endtask

      task set_dmactive(
         input logic dmactive
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;

         this.set_dmi(
               2'b10, //Write
               7'h10, //DMControl
               {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 10'b0, 10'b0, 2'b0, 1'b0, 1'b0, 1'b0, dmactive},
               {dm_addr, dm_data, dm_op}
            );

      endtask

      task set_hartsel(
         input logic [19:0] hartsel
      );

         dm::dmcontrol_t dmcontrol;

         this.read_debug_reg(dm::DMControl, dmcontrol);

         dmcontrol.hartsello = hartsel[9:0];
         dmcontrol.hartselhi = hartsel[19:10];

         this.write_debug_reg(dm::DMControl, dmcontrol);

      endtask


      // task set_sbreadonaddr(
      //    input logic sbreadonaddr,
      //    ref   logic s_tck,
      //    ref   logic s_tms,
      //    ref   logic s_trstn,
      //    ref   logic s_tdi,
      //    ref   logic s_tdo
      // );

      //    dm::sbcs_t sbcs;

      //    this.read_debug_reg(dm::SBCS, sbcs,
      //                        s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      //    sbcs.sbreadonaddr = sbreadonaddr;

      //    this.write_debug_reg(dm::SBCS, sbcs,
      //                         s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      // endtask

      // task set_sbautoincrement(
      //    input logic sbautoincrement,
      //    ref   logic s_tck,
      //    ref   logic s_tms,
      //    ref   logic s_trstn,
      //    ref   logic s_tdi,
      //    ref   logic s_tdo
      // );

      //    dm::sbcs_t sbcs;

      //    this.read_debug_reg(dm::SBCS, sbcs,
      //                        s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      //    sbcs.sbautoincrement = sbautoincrement;


      //    this.write_debug_reg(dm::SBCS, sbcs,
      //                         s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      // endtask

      // access (read) debug module register according to riscv-debug p. 71
      task read_debug_reg(
         input logic [6:0]   dmi_addr_i,
         output logic [31:0] data_o
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [6:0]         dmi_addr;

         // TODO: widen wait between Capture-DR and Update-DR when failing
         do begin
             this.set_dmi(
                   2'b01, //read
                   dmi_addr_i,
                   32'h0, // don't care
                   {dmi_addr, dmi_data, dmi_op});

             if (dmi_op == 2'h2) begin
                 $display("[JTAG] %t dmi previous operation failed, not handled", $realtime);
                 dmi_op = 2'h0; // TODO: for now we just force completion
             end

             if (dmi_op == 2'h3) begin
                 $display("[JTAG] %t retrying debug reg access", $realtime);
                 this.dmi_reset();
                 this.init_dmi_access();
             end

         end while (dmi_op != 2'h0);

         data_o = dmi_data;
      endtask

      // access (write) debug module register according to riscv-debug p. 71
      task write_debug_reg(
         input logic [6:0]   dmi_addr_i,
         input logic [31:0]  dmi_data_i
         );

         logic [1:0]     dmi_op;
         logic [31:0]    dmi_data;
         logic [6:0]     dmi_addr;
         dm::dmcontrol_t dmcontrol;
         int             dmsane;

         // According to riscv-debug p. 22 we are only allowed to write at most
         // one bit to resumereq, hartreset, ackhavereset,setresethaltreq and
         // clrresethaltreq. Others must be 0. This assert is for programming
         // errors.
         if(dmi_addr_i == dm::DMControl) begin
            dmcontrol = dmi_data_i;
            dmsane    = dmcontrol.resumereq + dmcontrol.hartreset +
                        dmcontrol.ackhavereset + dmcontrol.setresethaltreq +
                        dmcontrol.clrresethaltreq;

            assert (dmsane <= 1)
                else
                    $error("bad write to dmcontrol: only one of the following may be set to 1: resumereq %b,",
                           dmcontrol.resumereq,
                           "hartreset %b,", dmcontrol.hartreset,
                           "ackhavereset %b,", dmcontrol.ackhavereset,
                           "setresethaltreq %b,", dmcontrol.setresethaltreq,
                           "clrresethaltreq %b", dmcontrol.clrresethaltreq);
         end


         // TODO: widen wait between Capture-DR and Update-DR when failing
         do begin
             this.set_dmi(
                   2'b10, //write
                   dmi_addr_i,
                   dmi_data_i,
                   {dmi_addr, dmi_data, dmi_op}
             );
             if (dmi_op == 2'h2) begin
                 $display("[JTAG] %t dmi previous operation failed, not handled", $realtime);
                 dmi_op = 2'h0; // TODO: for now we just force completion
             end

             if (dmi_op == 2'h3) begin
                 $display("[JTAG] %t retrying debug reg access", $realtime);
                 this.dmi_reset();
                 this.init_dmi_access();
             end

         end while (dmi_op != 2'h0);

      endtask


      // access (read) csr, gpr by means of abstract command
      task read_reg_abstract_cmd(
         input logic [15:0]  regno_i,
         output logic [31:0] data_o
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         // load regno into data0
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno_i};
         this.set_command(
            dmi_command
         );

         this.read_debug_reg(
            dm::Data0,
            dmi_data
         );

         data_o = dmi_data;
      endtask


      // access (write) csr, gpr by means of abstract command
      task write_reg_abstract_cmd(
         input logic [15:0] regno_i,
         input logic [31:0] data_i
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         //write data_i into data0
         this.write_debug_reg(
             dm::Data0,
             data_i
         );

         // write data0 to regno_i
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno_i};
         this.set_command(dmi_command);

      endtask

      task write_memory_abstract_cmd(
         input logic [31:0] addr_i,
         input logic [31:0] data_i,
         input logic [2:0] aamsize_i
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         logic [1:0] target_specific = 0;
         logic write = 1;//1=write 0=read
         logic aampostincrement = 0;
         logic [2:0] aamsize = aamsize_i;// 0=8-bit 1=16-bit 2=32-bit 3=64-bit 4=128-bit
         logic aamvirtual = 0;
         logic [6:0] cmdtype = 2;// 2 for memory access 

         //write data_i into data0
         this.write_debug_reg(
             dm::Data0,
             data_i
         );

         //write addr_i into data1
         this.write_debug_reg(
             dm::Data1,
             addr_i
         );
         
         dmi_command = {cmdtype, aamvirtual, aamsize, aampostincrement, 2'd0, write, target_specific, 14'd0};
         this.set_command(
            dmi_command
         );

      endtask

      task read_memory_abstract_cmd(
         input logic [31:0] addr_i,
         input logic [2:0] aamsize_i,
         output logic [31:0] data_o
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         logic [1:0] target_specific = 0;
         logic write = 0;//1=write 0=read
         logic aampostincrement = 0;
         logic [2:0] aamsize = aamsize_i;// 0=8-bit 1=16-bit 2=32-bit 3=64-bit 4=128-bit
         logic aamvirtual = 0;
         logic [6:0] cmdtype = 2;// 2 for memory access 

         //write addr_i into data1
         this.write_debug_reg(
             dm::Data1,
             addr_i
         );

         dmi_command = {cmdtype, aamvirtual, aamsize, aampostincrement, 2'd0, write, target_specific, 14'd0};
         // read mem into data 0
         this.set_command(
            dmi_command
         );

         this.read_debug_reg(
            dm::Data0,
            data_o
         );

      endtask

      // Before starting an abstract command, haltreq=resumereq=ackhavereset=0
      // must be ensured, which is what this task asserts (see debug spec p.11).
      // We use this to catch programming mistakes, not to test functionality
      task assert_rdy_for_abstract_cmd(
      );

         dm::dmcontrol_t dmcontrol;
         this.read_debug_reg(dm::DMControl, dmcontrol);

         assert(dmcontrol.haltreq == 1'b0)
             else $error("haltreq is not zero");
         assert(dmcontrol.resumereq == 1'b0)
             else $error("resumereq is not zero");
         assert(dmcontrol.ackhavereset == 1'b0)
             else $error("ackhavereset is not zero");

      endtask

      // access csr, gpr by means of program buffer
      task read_reg_prog_buff(
         input logic [15:0]  regno_i,
         output logic [31:0] data_o
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         // load regno into data0
         dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno_i};
         this.set_command(
            dmi_command
         );

         this.read_debug_reg(
            dm::Data0,
            dmi_data
         );

         data_o = dmi_data;
      endtask


      task writeReadMem(
         input  logic [31:0] addr_i,
         input logic [31:0] value,
         ref logic [31:0] data_i
      );

      this.writeMem(addr_i, value);
      this.readMem(addr_i, data_i);

      endtask

      task readMem(
         input  logic [31:0] addr_i,
         output logic [31:0] data_o
      );

         read_memory_abstract_cmd(addr_i, 3'd2, data_o);

      endtask

      task writeMemSize(
         input  logic [31:0] addr_i,
         input  logic [31:0] data_i,
         input  logic [2:0] size
      );
         // 0=8-bit 1=16-bit 2=32-bit 3=64-bit 4=128-bit
         //NOTE sbreadonaddr must be 1
         write_memory_abstract_cmd(addr_i, data_i, size);

      endtask

      task writeMem(
         input  logic [31:0] addr_i,
         input  logic [31:0] data_i
      );

         //NOTE sbreadonaddr must be 1
         write_memory_abstract_cmd(addr_i, data_i, 3'd2);

      endtask


      // task load_L2(
      //    input int   num_stim,
      //    ref   logic [95:0] stimuli [100000:0],
      //    ref   logic s_tck,
      //    ref   logic s_tms,
      //    ref   logic s_trstn,
      //    ref   logic s_tdi,
      //    ref   logic s_tdo
      // );

      //    logic [1:0][31:0]   jtag_data;
      //    logic [31:0]        jtag_addr;
      //    logic [31:0]        spi_addr;
      //    logic [31:0]        spi_addr_old;
      //    logic               more_stim = 1;
      //    logic [1:0]         dm_op;
      //    logic [31:0]        dm_data;
      //    logic [6:0]         dm_addr;

      //    spi_addr        = stimuli[num_stim][95:64]; // assign address
      //    jtag_data[0]    = stimuli[num_stim][63:0];  // assign data

      //    this.set_sbreadonaddr(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      //    this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      //    $display("[JTAG] Loading L2 with debug module jtag interface");

      //    spi_addr_old = spi_addr - 32'h8;

      //    while (more_stim) begin // loop until we have no more stimuli

      //       jtag_addr = stimuli[num_stim][95:64];
      //       for (int i=0;i<256;i=i+2) begin
      //          spi_addr       = stimuli[num_stim][95:64]; // assign address
      //          jtag_data[0]   = stimuli[num_stim][31:0];  // assign data
      //          jtag_data[1]   = stimuli[num_stim][63:32]; // assign data

      //          if (spi_addr != (spi_addr_old + 32'h8))
      //             begin
      //                spi_addr_old = spi_addr - 32'h8;
      //                break;
      //             end
      //          else begin
      //             num_stim = num_stim + 1;
      //          end
      //          if (num_stim > $size(stimuli) || stimuli[num_stim]===96'bx ) begin // make sure we have more stimuli
      //             more_stim = 0;                    // if not set variable to 0, will prevent additional stimuli to be applied
      //             break;
      //          end
      //          spi_addr_old = spi_addr;

      //          this.set_dmi(
      //             2'b10,           //write
      //             7'h39,           //sbaddress0,
      //             spi_addr[31:0], //bootaddress
      //             {dm_addr, dm_data, dm_op},
      //             s_tck,
      //             s_tms,
      //             s_trstn,
      //             s_tdi,
      //             s_tdo
      //          );

      //          this.set_dmi(
      //             2'b10,           //write
      //             7'h3C,           //sbdata0,
      //             jtag_data[0],    //data
      //             {dm_addr, dm_data, dm_op},
      //             s_tck,
      //             s_tms,
      //             s_trstn,
      //             s_tdi,
      //             s_tdo
      //          );
      //          //$display("[JTAG] Loading L2 - Written %x at %x (%t)", jtag_data[0], spi_addr[31:0], $realtime);
      //          this.set_dmi(
      //             2'b10,             //write
      //             7'h39,             //sbaddress0,
      //             spi_addr[31:0]+4, //bootaddress
      //             {dm_addr, dm_data, dm_op},
      //             s_tck,
      //             s_tms,
      //             s_trstn,
      //             s_tdi,
      //             s_tdo
      //          );

      //          this.set_dmi(
      //             2'b10,           //write
      //             7'h3C,           //sbdata0,
      //             jtag_data[1],    //data
      //             {dm_addr, dm_data, dm_op},
      //             s_tck,
      //             s_tms,
      //             s_trstn,
      //             s_tdi,
      //             s_tdo
      //          );
      //       end
      //       $display("[JTAG] Loading L2 - Written up to %x (%t)", spi_addr[31:0]+4, $realtime);

      //    end
      //    this.set_sbreadonaddr(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      //    this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      // endtask

      // discover harts by writting all ones to hartsel and reading it back
      task test_discover_harts(
         output logic        error
      );

         dm::dmcontrol_t dmcontrol;
         dm::dmstatus_t  dmstatus;
         logic [9:0]     hartsello;

         int hartcount = 0;

         error = 1'b0;

         this.read_debug_reg(dm::DMControl, dmcontrol);
         dmcontrol.hartsello = 10'h3ff;
         dmcontrol.hartselhi = 10'h3ff;

         this.write_debug_reg(dm::DMControl, dmcontrol);

         this.read_debug_reg(dm::DMControl, dmcontrol);

         $display("[JTAG] %t hartsel bits usuable %x",
                  $realtime, {dmcontrol.hartselhi, dmcontrol.hartsello});

         // some simulators don't like direct indexing
         hartsello = dmcontrol.hartsello;
         assert(hartsello[0] === 1'b1)
             else $info("test assumes atleast one usuable bit in hartsel");

         for (int i = 0; i < {dmcontrol.hartselhi, dmcontrol.hartsello}; i++) begin
            set_hartsel(i);
            this.read_debug_reg(dm::DMStatus, dmstatus);

            if(dmstatus.anynonexistent === 1'b1) // no more harts
                break;

            if(dmstatus.anyunavail !== 1'b1) // selected hart not here
                hartcount++;

         end

         assert (hartcount === 1)
             else begin
                $error("bad number of available harts in system detected: expected %x, received %x",
                         1, hartcount);
                error = 1'b1;
             end

      endtask


     // access csr, gpr by means of abstract command
      task test_gpr_read_write_abstract(
         output logic        error
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         error = 1'b0;

         //write beefdead into data0
         this.writeArg(
            0,
            32'hbeefdead
         );

         //Copy data0 to each register from x2 to x31 (abstract command)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dmi_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};
               this.set_command(
                  dmi_data
               );
         end

         // write ffff_ffff in data0 (some random value so that we can determine
         // whether we really load something form the gprs into data0 or if its
         // just the value from before)
         this.writeArg(
            0,
            32'hffff_ffff
         );

         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dmi_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};
            this.set_command(
               dmi_data
            );
               // load regno into data0
            dmi_command = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, regno};
            this.set_command(
               dmi_command
            );


            // this command was tested separately to work
            // get out data0
            this.set_dmi(
               2'b01, //read
               7'h04, //data0
               32'h0, //whatever
               {dmi_addr, dmi_data, dmi_op}
            );

            assert(dmi_data === 'hbeefdead)
                else begin
                   $error("expected %x, received %x in gpr %x",
                          'hbeefdead, dmi_data, regno);
                   error = 1'b1;
                end
         end

      endtask

      // access csr, gpr by means of abstract command in this version we employ
      // our precise read and write commands which closely follow what is
      // recommended in the debug spec
      task test_gpr_read_write_abstract_high_level(
         output logic        error
      );

         logic [1:0]         dmi_op;
         logic [31:0]        dmi_data;
         logic [31:0]        dmi_command;
         logic [6:0]         dmi_addr;

         error = 1'b0;

         assert_rdy_for_abstract_cmd();

         //Copy data0 to each register from x2 to x31 (abstract command)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
             this.write_reg_abstract_cmd(
                 regno,
                 32'hbeefdead // TODO: want different values for regs
             );

         end

         // write ffff_ffff in data0 (some random value so that we can determine
         // whether we really load something form the gprs into data0 or if its
         // just the value from before)
         this.write_debug_reg(
             dm::Data0,
             32'hffff_ffff
         );

         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            read_reg_abstract_cmd(
               regno,
               dmi_data
            );
            assert(dmi_data === 'hbeefdead)
                else begin
                   $error("expected %x, received %x in gpr %x",
                          'hbeefdead, dmi_data, regno);
                   error = 1'b1;
                end
         end

      endtask


      task test_wfi_in_program_buffer(
         output logic error
      );

         logic [31:0]        dm_data;
         this.write_debug_reg(
            dm::ProgBuf0,
            riscv::wfi() //wfi
         );

         this.write_debug_reg(
            dm::ProgBuf0 + 1, //progrbuff1
            riscv::ebreak() //ebreak
         );
         //execute the program buffer
         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};

         this.set_command(
              dm_data
              );
         error = 1'b0;
      endtask


      task test_abstract_cmds_prog_buf(
         output logic error,
         input logic [31:0] address_i
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [6:0]         dm_addr;
         logic [31:0]        key_word = 32'hda41de;

         //write key_word in data0
         this.write_debug_reg(
            dm::Data0,
            key_word
         );

         assert_rdy_for_abstract_cmd();

         //Copy data0 to each register from x2 to x31 by means of Access Register abstract commands
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
            dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, regno};

               this.set_command(
                  dm_data
               );
            //$display("[JTAG] %t Access Register at regno %d",$realtime(), regno[4:0]);

         end

         //Put address_i is x1 by writing it to data0 and then Access Register
         this.write_debug_reg(
            dm::Data0,
            address_i
         );

         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, 16'h1001};
         this.set_command(
            dm_data
         );

         //increase every registers x2-x31 by 2-31  store them to *(x1++)
         for (logic [15:0] regno = 16'h1002; regno < 16'h1020; regno=regno+1) begin
               this.write_debug_reg(
                  dm::ProgBuf0,
                  { 7'h0, regno[4:0], regno[4:0], 3'b000, regno[4:0], 7'h13 } // addi xi, xi, i
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 1,
                  riscv::store(3'b010, regno[4:0], 5'h1, 12'h0) // sw xi, 0(x1)
                  //{ 7'h0, regno[4:0], 5'h1, 1'b0, 2'b10, 5'h0, 7'h23 },
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 2,
                  { 12'h4, 5'h1, 3'b000, 5'h1, 7'h13 } // addi x1, x1, 4
               );

               this.write_debug_reg(
                  dm::ProgBuf0 + 3,
                  riscv::ebreak() //ebreak
               );
               //execute the program buffer
               dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};

               this.set_command(
                  dm_data
               );
               //$display("[JTAG] %t Store of the value in reg %d",$realtime(), regno[4:0]);
         end

         //Now read them from memory the previous store values

         error = 1'b0;
         for (int incAddr = 2; incAddr < 32; incAddr=incAddr+1) begin
            this.readMem(address_i + (incAddr-2)*4, dm_data);
            // $display("[JTAG] %t Read %x from %x",$realtime(), dm_data, address_i + (incAddr-2)*4);
            assert(dm_data === key_word + incAddr)
                else begin
                   $error("read %x from %x instead of %x",
                          dm_data, address_i + (incAddr-2)*4, key_word + incAddr);
                   error = 1'b1;
                end
         end

      endtask


      task test_read_write_dpc(
         output logic error
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         logic [31:0]        saved;
         logic [6:0]         dm_addr;
         logic [31:0]        key_word;

         key_word = 32'hbeefdead & ~32'h1; // dpc lower bit always zero
         error = 1'b0;

         assert_rdy_for_abstract_cmd();

         this.read_reg_abstract_cmd(
             riscv::CSR_DPC,
             saved
         );

         this.write_reg_abstract_cmd(
             riscv::CSR_DPC,
             key_word
         );

         this.read_reg_abstract_cmd(
             riscv::CSR_DPC,
             dm_data
         );

         assert(key_word === dm_data)
             else begin
                $error("read %x instead of %x", dm_data, key_word);
                error = 1'b1;
             end;

         this.write_reg_abstract_cmd(
             riscv::CSR_DPC,
             saved
         );

      endtask

      task test_wfi_wakeup(
         output logic error,
         input logic [31:0] addr_i
      );

         logic [31:0]        dm_dpc;
         logic [31:0]        dm_dcsr;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // write short program to single step through
         this.writeMem(addr_i, riscv::wfi());  // wfi
         this.writeMem(addr_i + 4, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 });  // addi xi, xi, i
         this.writeMem(addr_i + 8, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i
         this.writeMem(addr_i + 12, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i
         this.writeMem(addr_i + 16, riscv::jal(5'd0,21'd0)  ); // J zero offset

         assert_rdy_for_abstract_cmd();

         // write dpc to addr_i so that we know where we resume
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i);

         // resume the core
         this.resume_harts();

         this.halt_harts();
         // The core should be in the WFI

         this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_dpc);

         // check if dpc, dcause and flag bits are ok
         assert(addr_i + 8 === dm_dpc) // did dpc increment?
                else begin
                   $error("dpc is %x, expected %x", dm_dpc, addr_i + 8);
                   error = 1'b1;
                end;

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dm_dcsr);

         $display("[JTAG] %t dcsr is %x", $realtime, dm_dcsr);

         // restore dpc to entry point
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i);

      endtask


      task test_single_stepping_no_memwrite(
         output logic error,
         input logic [31:0] addr_i
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;
         logic [6:0]         dm_addr;

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         assert_rdy_for_abstract_cmd();

         // set step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(dcsr.step == 1)
             else begin
                $error("couldn't enter single stepping mode");
                error = 1'b1;
             end;

         // write dpc to addr_i so that we know where we resume
         // this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i,
         //                             s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         // this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data, s_tck, s_tms,
         //                            s_trstn, s_tdi, s_tdo);

         for (int i = 1; i < 140; i++) begin
            // Make a single step. Like openocd we halt the hart manually even
            // though it might suffice to just check if allhalted is set.
            this.resume_harts();
            this.halt_harts();
            // this.block_until_any_halt(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

            this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
            assert(3'h4 === dcsr.cause) // is cause properly given as "step"?
                else begin
                   $error("debug cause is %x, expected %x", dcsr.cause, 3'h4);
                   error = 1'b1;
                end;
         end

         // clear step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

      endtask


      task test_single_stepping_abstract_cmd(
         output logic error,
         input logic [31:0] addr_i
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;
         logic [6:0]         dm_addr;

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // write short program to single step through
         this.writeMem(addr_i, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 });  // addi xi, xi, i
                     
         this.writeMem(addr_i + 4, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 });  // addi xi, xi, i
         this.writeMem(addr_i + 8, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i
         this.writeMem(addr_i + 12, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i
         this.writeMem(addr_i + 16, {20'b0, 5'b0, 7'b1101111}); // J zero offset

         assert_rdy_for_abstract_cmd();

         // set step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(dcsr.step == 1)
             else begin
                $error("couldn't enter single stepping mode");
                error = 1'b1;
             end;

         // write dpc to addr_i so that we know where we resume
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i);
         this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data);

         for (int i = 1; i < 4; i++) begin
            // Make a single step. Like openocd we halt the hart manually even
            // though it might suffice to just check if allhalted is set.
            this.resume_harts();
            this.halt_harts();
            // this.block_until_any_halt(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

            this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data);
            // check if dpc, dcause and flag bits are ok
            assert(addr_i + 4*i === dm_data) // did dpc increment?
                else begin
                   $error("dpc is %x, expected %x", dm_data, addr_i + 4);
                   error = 1'b1;
                end;
            this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
            assert(3'h4 === dcsr.cause) // is cause properly given as "step"?
                else begin
                   $error("debug cause is %x, expected %x", dcsr.cause, 3'h4);
                   error = 1'b1;
                end;
         end

         // clear step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

      endtask


      task test_single_stepping_edge_cases(
         output logic error,
         input logic [31:0] addr_i
      );

         logic [1:0]         dm_op;
         logic [31:0]        dm_data;
         riscv::dcsr_t       dcsr;
         dm::dmstatus_t      dmstatus;
         logic [6:0]         dm_addr;
         // records the sequence of expected pc changes
         int                 pc_offsets[];

         error = 1'b0;

        // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // write short program to single step through
         pc_offsets = {4, 8, 16, 20, 24, 28, 32};
         this.writeMem(addr_i + 0, riscv::nop());
         this.writeMem(addr_i + 4, riscv::nop());
         this.writeMem(addr_i + 8, riscv::branch(5'h0, 5'h0, 3'b0, 12'h4)); // branch to + 16);
         this.writeMem(addr_i + 12, riscv::nop());
         this.writeMem(addr_i + 16, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i);
         this.writeMem(addr_i + 20, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i);
         this.writeMem(addr_i + 24, riscv::wfi()); // step over wfi);
         this.writeMem(addr_i + 28, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi, i);
         this.writeMem(addr_i + 32, {20'b0, 5'b0, 7'b1101111}); // J zero offset


         assert_rdy_for_abstract_cmd();

         // set step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(dcsr.step == 1)
             else begin
                $error("couldn't enter single stepping mode");
                error = 1'b1;
             end;

         // write dpc to addr_i so that we know where we resume
         this.write_reg_abstract_cmd(riscv::CSR_DPC, addr_i);

         this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data);

         for (int i = 0; i < $size(pc_offsets); i++) begin
            // Make a single step. Like openocd we halt the hart manually even
            // though it might suffice to just check if allhalted is set.
            this.resume_harts();
            this.halt_harts();
            // this.block_until_any_halt(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

            this.read_reg_abstract_cmd(riscv::CSR_DPC, dm_data);
            // check if dpc, dcause and flag bits are ok
            assert(addr_i + pc_offsets[i] === dm_data) // did dpc increment?
                else begin
                   $error("dpc is %x, expected %x", dm_data, addr_i + pc_offsets[i]);
                   error = 1'b1;
                end;
            this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
            assert(CauseSingleStep === dcsr.cause) // is cause properly given as "step"?
                else begin
                   $error("debug cause is %x, expected %x", dcsr.cause, CauseSingleStep);
                   error = 1'b1;
                end;
         end

         // clear step flag in dcsr
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

      endtask


      task test_halt_resume(
         output logic error
      );
         dm::dmstatus_t dmstatus;
         error = 1'b0;

         // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // resume core and check flags
         this.resume_harts();

         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allrunning == 1'b1)
             else begin
                $error("allrunning flag is not set after resume request");
                error = 1'b1;
             end

         // halt core and check flags
         this.halt_harts();
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set after halt request");
                error = 1'b1;
             end

      endtask

      task test_debug_cause_values(
         output logic error,
         input logic [31:0] addr_i
      );
         dm::dmstatus_t dmstatus;
         riscv::dcsr_t  dcsr;

         error = 1'b0;


         // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         //Write while(1) to BEGIN_L2_INSTR
         this.writeMem(addr_i, {25'b0, 7'b1101111});

         // // check if debug cause is haltrequest
         this.resume_harts();
         this.halt_harts();
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(CauseRequest === dcsr.cause)
             else begin
                $error("debug cause is %x, expected %x", dcsr.cause, CauseRequest);
                error = 1'b1;
             end;

         // check if debug request is haltrequest
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

         this.resume_harts();
         this.wait_allhalted();
         //this.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(CauseSingleStep === dcsr.cause)
             else begin
                $error("debug cause is %x, expected %x", dcsr.cause, CauseSingleStep);
                error = 1'b1;
             end;

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.step = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

         // check if debug request is breakpoint
         this.writeMem(addr_i + 0, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi,
         this.writeMem(addr_i + 4, { 7'h0, 5'b1, 5'b1, 3'b000, 5'b1, 7'h13 }); // addi xi, xi,
         this.writeMem(addr_i + 8, riscv::ebreak());
         this.writeMem(addr_i + 12, {20'b0, 5'b0, 7'b1101111}); // J zero offset

         // force ebreak in m-mode to enter debug mode
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.ebreakm = 1;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         this.resume_harts();
         // TODO: delay here until entering park loop...
         // check halted?

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         assert(CauseBreakpoint === dcsr.cause)
             else begin
                $error("debug cause is %x, expected %x", dcsr.cause, CauseBreakpoint);
                error = 1'b1;
             end;

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
         dcsr.ebreakm = 0;
         this.write_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);
      
      
      endtask


      task test_ebreak_in_program_buffer(
         output logic error
      );

         logic [31:0]   dm_data;
         logic [31:0]   dpc_save, dpc;
         riscv::dcsr_t  dcsr_save, dcsr;
         dm::dmstatus_t dmstatus;

         error = 1'b0;

         // check if our hart is halted
         this.read_debug_reg(dm::DMStatus, dmstatus);
         assert(dmstatus.allhalted == 1'b1)
             else begin
                $error("allhalted flag is not set when entering test");
                error = 1'b1;
             end

         // save dpc, dcsr.cause
         this.read_reg_abstract_cmd(riscv::CSR_DPC, dpc_save);

         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr_save);

         // write to program buffer
         this.write_debug_reg(dm::ProgBuf0, riscv::nop());
         this.write_debug_reg(dm::ProgBuf0 + 1, riscv::ebreak());

         //execute the program buffer
         dm_data = {8'h0, 1'b0, 3'd2, 1'b0, 1'b1, 1'b0, 1'b0, 16'h0};
         this.set_command(dm_data);

         // check that dpc and dcsr.cause didn't change
         this.read_reg_abstract_cmd(riscv::CSR_DPC, dpc);
         this.read_reg_abstract_cmd(riscv::CSR_DCSR, dcsr);

         assert(dpc == dpc_save)
             else begin
                $error("dpc changed from %x to %x", dpc_save, dpc);
                error = 1'b1;
             end

         assert(dcsr.cause == dcsr_save.cause)
             else begin
                $error("dcsr changed from %x to %x", dcsr.cause, dcsr_save.cause);
                error = 1'b1;
             end

      endtask

      task test_bad_aarsize (
         output logic error
      );
         // assert busy == 0 and cmderr != 0,1
         logic [1:0] dm_op;
         logic [6:0] dm_addr;
         logic [31:0] dm_data;
         dm::abstractcs_t abstractcs;
         dm::ac_ar_cmd_t command;

         // abstract command with aarsize = 3
         command     = '{default:0, aarsize:3'd3, postexec:1'b0,
                         transfer:1'b1, write:1'b0, regno:16'h1002};

         this.set_dmi(
               2'b10,   //write
               dm::Command,
               {8'h0, command},
               {dm_addr, dm_data, dm_op}
            );

         do begin
            this.read_debug_reg(dm::AbstractCS, abstractcs);
         end while(abstractcs.busy == 1'b1);

         assert(abstractcs.busy == 1'b0 && abstractcs.cmderr == dm::CmdErrNotSupported)
             else begin
                $error("Abstract cmd with 64 bit is signaled as supported");
                error = 1'b1;
             end

         // try to clear the error bit
         abstractcs        = 0;
         abstractcs.cmderr = dm::CmdErrNotSupported;

         this.write_debug_reg(dm::AbstractCS, abstractcs);

         // test if it really got cleared
         this.read_debug_reg(dm::AbstractCS, abstractcs);

         assert(abstractcs.cmderr == dm::CmdErrNone)
             else begin
                $error("cmderr bit didn't get cleared");
                error = 1'b1;
             end

      endtask


      task test_read_write_csr (
         output logic error
      );

         dm::abstractcs_t abstractcs;
         logic [31:0]  regs [];
         logic [31:0] contents;

         this.read_reg_abstract_cmd(riscv::CSR_DPC, contents);
         $display("[JTAG] CSR_DPC=%x", contents);

         this.read_reg_abstract_cmd(riscv::CSR_MSTATUS, contents);
         $display("[JTAG] CSR_MSTATUS=%x", contents);

         this.read_reg_abstract_cmd(riscv::CSR_MISA, contents);
         $display("[JTAG] CSR_MISA=%x", contents);

      endtask

      // Should be called before using either dm tests or user tests
      task init(
         input int fc_core_id,
         input int trigger_count
      );
         init_dmi_access();
         set_dmactive(1'b1);
         set_hartsel(fc_core_id);
         this.trigger_count = trigger_count; // set the class-wide trigger count
      endtask

   // Called when UBI_AUTOTESTS_RUN = 0
   task run_user_test();
      // Write your test here
      $display("hello, world\n");
      // this.halt_harts();

   endtask
  endclass

endpackage

// Local Variables:
// verilog-indent-level: 3
// End:
