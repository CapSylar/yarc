// stage_mem1 module

`default_nettype none

module lsu
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    // Load Store Unit
    output logic lsu_req_o,
    output logic [31:0] lsu_addr_o,
    output logic lsu_we_o,
    output logic lsu_lock_o,
    output logic [3:0] lsu_sel_o,
    output logic [31:0] lsu_wdata_o,
    input wire [31:0] lsu_rdata_i,
    input wire lsu_req_done_i,

    // from EX/MEM1
    input wire [31:0] alu_result_i,
    input wire [31:0] alu_oper2_i,
    input wire mem_oper_t mem_opM_i,
    input wire atomic_op_e atomic_opM_i,
    input wire trapM_i,

    input wire [31:0] instrM_i,
    // MEM1/MEM2 pipeline registers
    output logic [31:0] alu_result_o,
    output logic [31:0] lsu_rdata_o,
    output logic is_fail_scW_o,

    output logic lsu_stall_m_o,
    output logic load_misaligned_trapM_o,
    output logic store_misaligned_trapM_o,
    
    input wire stallW_i,
    input wire flushW_i
);

wire [31:0] addr = lsu_addr_o;
wire [31:0] to_write = alu_oper2_i;
logic [3:0] sel_byte;
logic [31:0] wdata;

wire is_amo = (atomic_opM_i == ATOMIC_AMO);

// detected unaligned addresses
wire is_half_unaligned = (mem_opM_i.mem_width == 2'b01) & (addr[0] == 1'b1);
wire is_word_unaligned = (mem_opM_i.mem_width == 2'b10) & (|addr[1:0]);

wire is_write = mem_opM_i.mem_rw[0];
wire is_read =  mem_opM_i.mem_rw[1];

wire misaligned_trap = is_half_unaligned | is_word_unaligned;
assign load_misaligned_trapM_o = misaligned_trap & is_read;
assign store_misaligned_trapM_o = misaligned_trap & is_write;

// format the write data
always_comb
begin
    sel_byte = '0;
    wdata = '0;

    case(mem_opM_i.mem_width)
        2'b00: // byte
        begin
            sel_byte = 4'b0001 << addr[1:0];
            wdata = to_write << (addr[1:0] * 8);
        end

        2'b01: // halfword
        begin
            sel_byte = 4'b0011 << (addr[1] * 2);
            wdata = to_write << (addr[1] * 16);
        end

        2'b10: // word
        begin
            sel_byte = 4'b1111;
            wdata = to_write;
        end

        default:
        begin end
    endcase
end

// extract byte

logic [7:0] selected_byte;
always_comb begin
    unique case (alu_result_i[1:0])
        2'b00: selected_byte = (lsu_rdata_i[(8*1)-1 -:8]);
        2'b01: selected_byte = (lsu_rdata_i[(8*2)-1 -:8]);
        2'b10: selected_byte = (lsu_rdata_i[(8*3)-1 -:8]);
        2'b11: selected_byte = (lsu_rdata_i[(8*4)-1 -:8]);
        default:;
    endcase
end

wire [31:0] extended_byte = mem_opM_i.is_load_unsigned ? 32'(selected_byte) : 32'(signed'(selected_byte));

// extract halfword

logic [15:0] selected_halfword;
always_comb begin
    unique case (alu_result_i[1])
        1'b0: selected_halfword = (lsu_rdata_i[(16*1)-1 -:16]);
        1'b1: selected_halfword = (lsu_rdata_i[(16*2)-1 -:16]);
        default:;
    endcase
end

wire [31:0] extended_halfword = mem_opM_i.is_load_unsigned ? 32'(selected_halfword) : 32'(signed'(selected_halfword));

logic [31:0] rdata;
// format the read data correctly
always_comb
begin : format_rdata
    rdata = '0;

    case(mem_opM_i.mem_width)
        2'b00:
        begin
            rdata = extended_byte;
        end
        2'b01:
        begin
            rdata = extended_halfword;
        end
        2'b10:
        begin
            rdata = lsu_rdata_i;
        end
        default:;
    endcase
end

// 0: no ops done, 1: one op done (read)
logic amo_state_d, amo_state_q;
logic done;

// when not to start a memory request
wire can_issue_req = ~(trapM_i | flushW_i);
logic is_fail_scM;
wire [1:0] gated_rw = {is_read , (is_write & ~is_fail_scM)};

typedef enum {IDLE, AMO_WRITE, WAITING_FOR_DONE} state_t;
state_t state, next;

flopr_type #(state_t, IDLE) state_flop (clk_i, rstn_i, next, state);

always_comb
begin
    next = state;

    lsu_req_o = 1'b0;
    lsu_we_o = 1'b0;
    amo_state_d = amo_state_q;
    done = 1'b0;

    unique case (state)
        IDLE: begin
            amo_state_d = '0;

            if (|gated_rw & can_issue_req) begin
                lsu_req_o = 1'b1;

                if (is_amo) begin
                    lsu_we_o = 1'b0;
                end else if (gated_rw[1]) begin
                    lsu_we_o = 1'b0;
                end else if (gated_rw[0]) begin
                    lsu_we_o = 1'b1;
                end

                next = WAITING_FOR_DONE;
            end
        end

        AMO_WRITE: begin
            lsu_req_o = 1'b1;
            lsu_we_o = 1'b1;

            next = WAITING_FOR_DONE;
        end

        WAITING_FOR_DONE: begin
            if (lsu_req_done_i) begin

                // update amo_state when amo
                amo_state_d = is_amo ? ~amo_state_q : amo_state_q;

                if (is_amo & amo_state_q | ~is_amo) begin
                    next = IDLE;
                    done = 1'b1;
                end else if (is_amo) begin
                    next = AMO_WRITE;
                end
            end
        end
    endcase
end

/*
 * Here I am using the fact that for now lsu req never responds in the same cycle
 */
assign lsu_stall_m_o = (|gated_rw) & ~done;

/*
 * Load reserved - Store conditional
 */

 lrsc lrsc_i (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .stallW_i(stallW_i),
    .flushW_i(flushW_i),

    .mem_opM_i(mem_opM_i),
    .atomic_opM_i(atomic_opM_i),

    .lsu_addr_i(lsu_addr_o),

    .is_fail_scM_o(is_fail_scM),
    .is_fail_scW_o(is_fail_scW_o)
 );

/*
 * Atomic Memory Operations
 */

logic [31:0] rdata_q; // last read data
flopenrc #(32) save_rdata_flop (clk_i, rstn_i, 1'b0, (lsu_req_done_i & ~lsu_we_o), rdata, rdata_q);

logic [31:0] amoalu_result;

amoalu amoalu_i (
    .loaded_value_i(rdata_q),
    .wdata_i(wdata),

    .instrM_i(instrM_i),
    .result_o(amoalu_result)
);

// lsu outputs
assign lsu_addr_o = alu_result_i;
assign lsu_wdata_o = is_amo ? amoalu_result : wdata;
assign lsu_sel_o = sel_byte;
assign lsu_lock_o = is_amo;

flopr #(1) amo_state_flop (clk_i, rstn_i, amo_state_d, amo_state_q);

// pipeline registers
flopenrc #(32) alu_result_reg   (clk_i, rstn_i, flushW_i, !stallW_i, alu_result_i, alu_result_o);
flopenrc #(32) lsu_rdata_reg    (clk_i, rstn_i, flushW_i, !stallW_i, (is_amo ? rdata_q : rdata), lsu_rdata_o);

endmodule: lsu

`default_nettype wire
