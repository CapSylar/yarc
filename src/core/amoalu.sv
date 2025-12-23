// performs the binary operation required by the AMO instructions

module amoalu(
    input wire [31:0] loaded_value_i,
    input wire [31:0] wdata_i,

    input wire [31:0] instrM_i,
    output logic [31:0] result_o
);

wire [4:0] upper_5 = instrM_i[31:27];

wire [31:0] a = loaded_value_i;
wire [31:0] b = wdata_i;
logic [31:0] result;

always_comb begin
    unique case (upper_5)
        5'b00001: result = b;
        5'b00000: result = a + b;
        5'b00100: result = a ^ b;
        5'b01100: result = a & b;
        5'b01000: result = a | b;
        5'b10000: result = ($signed(a) < $signed(b)) ? a : b;
        5'b10100: result = ($signed(a) >= $signed(b)) ? a : b;
        5'b11000: result = ($unsigned(a) < $unsigned(b)) ? a : b;
        5'b11100: result = ($unsigned(a) >= $unsigned(b)) ? a : b;
        default:  result = b;
    endcase
end

assign result_o = result;

endmodule: amoalu
