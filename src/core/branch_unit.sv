// branch unit

module branch_unit
import riscv_pkg::*;
(
    input wire [31:0] rs1ValueE_i,
    input wire [31:0] rs2ValueE_i,
    
    input wire [31:0] pc_i,
    input wire [31:0] imm_i,
    input bnj_oper_t bnj_oper_i,
    input wire [2:0] func3E_i,
    
    output logic [31:0] branch_target_o,
    output logic branch_taken_o
);

logic is_cmp_signed;

// prepare both operands 1 and 2
logic [32:0] adder_in_1, adder_in_2;
logic [32:0] adder_result_ext;
logic [31:0] adder_result;

assign adder_in_1 = {rs1ValueE_i,1'b1};
assign adder_in_2 = ~{rs2ValueE_i,1'b0};

assign adder_result_ext = $unsigned(adder_in_1) + $unsigned(adder_in_2);
assign adder_result = adder_result_ext[32:1];

// produce the comparison values
logic is_equal, is_greater_equal;

assign is_equal = (adder_result == '0);

// calculate greater or equal
always_comb
begin
    // if both operands have the same sign (++ or --), then if a - b is positive then a > b
    if ((rs1ValueE_i[31] ^ rs2ValueE_i[31]) == '0)
        is_greater_equal = (adder_result[31] == '0);

        // the operands' signs are not equal:
        // 1- if the cmp is signed, the one with the + sign is greater
        // 2- if the cmp is not signed, the operand with the MSB is greater
    else
        is_greater_equal = (rs1ValueE_i[31] ^ is_cmp_signed);
end

logic is_cond_branch_taken;

always_comb begin
    is_cmp_signed = 1'b1;
    is_cond_branch_taken = 1'b0;

    unique case (opcode_branch_t'(func3E_i))
        BEQ: is_cond_branch_taken = is_equal;
        BNE: is_cond_branch_taken = ~is_equal;
        BLT: is_cond_branch_taken = ~is_greater_equal;
        BGE: is_cond_branch_taken = is_greater_equal;

        BLTU: begin
            is_cmp_signed = 1'b0;
            is_cond_branch_taken = ~is_greater_equal;
        end 
        
        BGEU: begin
            is_cmp_signed = 1'b0;
            is_cond_branch_taken = is_greater_equal;
        end
        default:;
    endcase
end

wire [31:0] pc_offset = pc_i + imm_i;
wire [31:0] register_offset = rs1ValueE_i + imm_i;

always_comb begin
    unique case (bnj_oper_i) 
        BNJ_JAL, BNJ_JALR: branch_taken_o = 1'b1;
        BNJ_BRANCH:        branch_taken_o = is_cond_branch_taken;
        default:           branch_taken_o = 1'b0;
    endcase
end

always_comb begin
    unique case (bnj_oper_i)
        BNJ_JAL, BNJ_BRANCH: branch_target_o = pc_offset;

        // BNJ_JALR
        default:             branch_target_o = register_offset;
    endcase
end

endmodule: branch_unit
