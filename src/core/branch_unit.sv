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
    
    output logic [31:0] branch_targetE_o,
    output logic branch_takenE_o
);

// produce the comparison values
logic is_equal, is_less_than, is_less_than_unsigned;

assign is_equal = (rs1ValueE_i == rs2ValueE_i);
assign is_less_than = $signed(rs1ValueE_i) < $signed(rs2ValueE_i);
assign is_less_than_unsigned = rs1ValueE_i < rs2ValueE_i;

logic is_cond_branch_taken;

always_comb begin
    is_cond_branch_taken = 1'b0;

    unique case (opcode_branch_t'(func3E_i))
        BEQ: is_cond_branch_taken = is_equal;
        BNE: is_cond_branch_taken = ~is_equal;
        BLT: is_cond_branch_taken = is_less_than;
        BGE: is_cond_branch_taken = ~is_less_than;

        BLTU: begin
            is_cond_branch_taken = is_less_than_unsigned;
        end 
        
        BGEU: begin
            is_cond_branch_taken = ~is_less_than_unsigned;
        end
        default:;
    endcase
end

wire [31:0] pc_offset = pc_i + imm_i;
wire [31:0] register_offset = rs1ValueE_i + imm_i;

always_comb begin
    unique case (bnj_oper_i) 
        BNJ_JAL, BNJ_JALR: branch_takenE_o = 1'b1;
        BNJ_BRANCH:        branch_takenE_o = is_cond_branch_taken;
        default:           branch_takenE_o = 1'b0;
    endcase
end

always_comb begin
    unique case (bnj_oper_i)
        BNJ_JAL, BNJ_BRANCH: branch_targetE_o = pc_offset;

        // BNJ_JALR
        default:             branch_targetE_o = register_offset;
    endcase
end

endmodule: branch_unit
