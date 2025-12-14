`default_nettype none

module divider
import riscv_pkg::*;
(   
    input wire clk_i,
    input wire rstn_i,

    input wire flushE_i,

    input wire stallM_i,
    input wire flushM_i,

    input wire is_div_i,
    input wire is_signed_i,

    input wire [31:0] input_a_i,
    input wire [31:0] input_b_i,

    output logic busyE_o,

    output logic [31:0] quotientM_o,
    output logic [31:0] remainderM_o
);

localparam XLEN = 32;

logic [XLEN*2-1:0] op_vector_d, op_vector_q; // operation vector

logic load;
logic work;
logic save_inputs;

logic [5:0] turn_counter_d, turn_counter_q;

logic [XLEN-1:0] dividend_d, dividend_q;
logic [XLEN-1:0] divisor_d, divisor_q;

logic neg_dividendE, diff_signsE;
logic neg_dividendM, diff_signsM;

wire is_div_zeroE = (input_b_i == '0);
wire is_div_zero = (divisor_q == '0);

assign neg_dividendE = (is_signed_i & !is_div_zeroE) & input_a_i[31];
wire neg_divisor =     (is_signed_i & !is_div_zeroE) & input_b_i[31];
assign diff_signsE =   (is_signed_i & !is_div_zeroE) & input_a_i[31] ^ input_b_i[31];

// negate an input in the case of a signed division and the input is negative
assign dividend_d = (neg_dividendE) ? (~input_a_i + 1'b1) : input_a_i;
assign divisor_d = (neg_divisor) ? (~input_b_i + 1'b1) : input_b_i;

wire start = is_div_i & ~stallM_i;

enum {IDLE, LOAD, WORKING, DONE} state, next;

always_ff@(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i)        state <= IDLE;
    else if (flushE_i)  state <= IDLE;
    else                state <= next;
end

always_comb begin
    next = state;

    work = 1'b0;
    load = 1'b0;
    save_inputs = 1'b0;

    turn_counter_d = turn_counter_q;

    unique case (state) 
        IDLE: begin
            turn_counter_d = '0;

            if (start) begin

                save_inputs = 1'b1;
                next = LOAD;
            end
        end
        
        LOAD: begin
            work = 1'b1;
            load = 1'b1;
            
            if (is_div_zero) begin
                next = DONE;
            end else begin
                next = WORKING;
            end
        end

        WORKING: begin
            work = 1'b1;
            turn_counter_d = turn_counter_q + 1'b1;
            
            if (turn_counter_q[5]) begin
                work = 1'b0;
                next = DONE;
            end
        end

        DONE: begin
            // TODO: check stall here
            next = IDLE;
        end
    endcase
end

logic [XLEN*2-1:0] next_round_op_vec;
assign op_vector_d = load ? (is_div_zero ? {dividend_q, {32{1'b1}}} : {32'b0, dividend_q}) : next_round_op_vec;

flopenrc #(XLEN*2) pipe_op_vector (clk_i, rstn_i, 1'b0, work, op_vector_d, op_vector_q);

// division step
logic [XLEN*2-1:0] op_vector_shifted;
assign op_vector_shifted = op_vector_q << 1;

logic [XLEN-1:0] quotientE, remainderE;
logic [XLEN-1:0] quotientM, remainderM;
assign {remainderE, quotientE} = op_vector_q;

wire [XLEN:0] neg = ({1'b0, (op_vector_shifted[XLEN*2 -1 -: 32])} - {1'b0, divisor_q});

wire [XLEN-1:0] updated_w = neg[XLEN-1:0];
wire result_neg = neg[XLEN];

// if result is not negative then we shift a one in
wire restore = result_neg;
assign next_round_op_vec = restore ? op_vector_shifted : {updated_w, op_vector_shifted[XLEN-1:0] | 1'b1};

flopr #(6) pipe_counter (clk_i, rstn_i, turn_counter_d, turn_counter_q);

flopenrc #(XLEN) pipe_dividend (clk_i, rstn_i, 1'b0, save_inputs, dividend_d, dividend_q);
flopenrc #(XLEN) pipe_divisor  (clk_i, rstn_i, 1'b0, save_inputs, divisor_d, divisor_q);

flopenrc #(XLEN) pipeline_quo  (clk_i, rstn_i, flushM_i, ~stallM_i, quotientE, quotientM);
flopenrc #(XLEN) pipeline_rem  (clk_i, rstn_i, flushM_i, ~stallM_i, remainderE, remainderM);
flopenrc #(2) pipeline_ctrl (clk_i, rstn_i, 1'b0, save_inputs, {diff_signsE, neg_dividendE}, {diff_signsM, neg_dividendM});

// do signed correction in M stage and then output the result for the mdu to pick what is wants
assign busyE_o = (state != DONE) & is_div_i;

// fixed as in sign has been fixed
logic [XLEN-1:0] fixed_quotientM, fixed_remainderM;

assign fixed_quotientM = diff_signsM ? (~quotientM + 1'b1) : quotientM;
assign fixed_remainderM = neg_dividendM ? (~remainderM + 1'b1) : remainderM;

assign quotientM_o = fixed_quotientM;
assign remainderM_o = fixed_remainderM;

endmodule: divider

`default_nettype wire