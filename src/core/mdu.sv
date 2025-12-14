
module mdu
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    input wire flushE_i,

    input wire stallM_i,
    input wire flushM_i,

    output logic mdu_busyE_o,

    input wire [31:0] rs1_forwarded_value_i,
    input wire [31:0] rs2_forwarded_value_i,
    input wire is_muldivE_i,

    input wire [31:0] instrE_i,
    input wire [31:0] instrM_i,

    output logic [31:0] resultW_o
);

wire [2:0] funct3E = instrE_i[14:12];
wire [2:0] funct3M = instrM_i[14:12];

logic [31:0] resultM;
logic [63:0] mul_resultM;

logic [31:0] quotientM, remainderM;

wire is_mul = is_muldivE_i & ~funct3E[2];
wire is_div = is_muldivE_i & funct3E[2];
wire is_div_signed = ~funct3E[0];

multiplier multiplier_i 
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .stallM_i(stallM_i),
    .flushM_i(flushM_i),

    .input_a_i({32{is_mul}} & rs1_forwarded_value_i),
    .input_b_i({32{is_mul}} & rs2_forwarded_value_i),

    .funct3_i(funct3E),

    .resultM_o(mul_resultM)
);

divider divider_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .flushE_i(flushE_i),

    .stallM_i(stallM_i),
    .flushM_i(flushM_i),

    .is_div_i(is_div),
    .is_signed_i(is_div_signed),

    .input_a_i(rs1_forwarded_value_i),
    .input_b_i(rs2_forwarded_value_i),

    .quotientM_o(quotientM),
    .remainderM_o(remainderM),

    .busyE_o(mdu_busyE_o)
);

always_comb begin
    resultM = '0;

    unique case (funct3M)
        3'b000: begin // MUL
            resultM = mul_resultM[31:0];
        end
        3'b001, // MULH
        3'b010, // MULHSU
        3'b011: // MULHU
        begin
            resultM = mul_resultM[63:32];
        end

        3'b100, // DIV
        3'b101: // DIVU
        begin
            resultM = quotientM;
        end

        3'b110, // REM
        3'b111: // REMU
        begin
            resultM = remainderM;
        end
        default: begin end
    endcase
end

flopenrc #(32) resultW_pipe (clk_i, rstn_i, flushM_i, ~stallM_i, resultM, resultW_o); 

endmodule: mdu
