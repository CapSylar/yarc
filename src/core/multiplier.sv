
module multiplier
import riscv_pkg::*;
(   
    input wire clk_i,
    input wire rstn_i,

    input wire stallM_i,
    input wire flushM_i,

    input wire [31:0] input_a_i,
    input wire [31:0] input_b_i,

    input wire [2:0] funct3_i,

    output logic [63:0] resultM_o
);

localparam XLEN = 32;

// we only care about these since we need to be careful with signedness
wire is_mulh = (funct3_i == 3'b001);
wire is_mulhsu = (funct3_i == 3'b010);

logic [31:0] Aprime;
logic [31:0] Bprime;

logic pp; // product of the MSBs
logic [XLEN-2:0] pa, pb;

logic [2*XLEN-1:0] pp0E, pp1E, pp2E, pp3E;
logic [2*XLEN-1:0] pp0M, pp1M, pp2M, pp3M;

assign Aprime = {1'b0, input_a_i[XLEN-2:0]};
assign Bprime = {1'b0, input_b_i[XLEN-2:0]};

// product of the MSB of A and the bits of B[XLEN-2:0]
assign pa = {31{input_a_i[31]}} & input_b_i[XLEN-2:0];

// product of the MSB of B and the bits of A[XLEN-2:0]
assign pb = {31{input_b_i[31]}} & input_a_i[XLEN-2:0];

assign pp = input_a_i[31] & input_b_i[31];

// always unsigned since it doesn't include the MSBs which are the sign bits
assign pp0E = Aprime * Bprime;

/*
 * A is signed if mulh or mulhsu
 */
assign pp1E = {2'b00, (is_mulh | is_mulhsu) ? ~pa : pa, 31'b0};

/*
 * B is signed if mulh only
 * It is also signed for mul but in this case we only care about the lower half
 * so this partial product won't matter
 */
assign pp2E = {2'b00, (is_mulh) ? ~pb : pb, 31'b0};

/*
 * case 1: the bit 1 is at position XLEN because it is carried over
 * from the two bits we added at XLEN-1 following the negation
 *  of both pa and pb
 * 
 * case 2: B is unsigned in this case so the bit 1 is at position XLEN-1 (from the negation of pa),
 * the negation of PP should have needed a 1 added at XLEN*2-2, but this is taken into account
 * by adding them manually (try an example out by hand you'll see)
 * 
 * case 3: not added ones since both pa and pb are unsigned
 */
always_comb begin
    if (is_mulh)        pp3E = {1'b1, pp, {(XLEN-3){1'b0}},1'b1 ,32'b0};  // case 1
    else if (is_mulhsu) pp3E = {1'b1, ~pp, {(XLEN-2){1'b0}} ,1'b1, 31'b0}; // case 2
    else                pp3E = {1'b0, pp, {(2*XLEN-2){1'b0}}}; // case 3
end

// pipeline registers
flopenrc #(XLEN*2) pipeline_pp0 (clk_i, rstn_i, flushM_i, ~stallM_i, pp0E, pp0M);
flopenrc #(XLEN*2) pipeline_pp1 (clk_i, rstn_i, flushM_i, ~stallM_i, pp1E, pp1M);
flopenrc #(XLEN*2) pipeline_pp2 (clk_i, rstn_i, flushM_i, ~stallM_i, pp2E, pp2M);
flopenrc #(XLEN*2) pipeline_pp3 (clk_i, rstn_i, flushM_i, ~stallM_i, pp3E, pp3M);

assign resultM_o = pp0M + pp1M + pp2M + pp3M;

// final result by adding the partial products

endmodule: multiplier
