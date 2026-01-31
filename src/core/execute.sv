// execute module

module execute
import core_pkg::*;
(
    input clk_i,
    input rstn_i,

    input stallM_i,
    input flushM_i,

    // from ID/EX
    input [31:0] pc_i,
    input [31:0] rs1_data_i,
    input [31:0] rs2_data_i,
    input [31:0] imm_i,
    input alu_oper1_src_t alu_oper1_src_i,
    input alu_oper2_src_t alu_oper2_src_i,
    input alu_oper_t alu_oper_i,
    input bnj_oper_t bnj_oper_i,
    input wire [31:0] instrE_i,

    output logic [31:0] rs1_forwarded_value_o,
    output logic [31:0] rs2_forwarded_value_o,
    
    // EX/MEM pipeline registers
    output logic [31:0] rs1ValueM_o,

    // feedback into the pipeline registers
    output logic [31:0] alu_resultM_o, // always contains a mem address or the rd value
    output logic [31:0] alu_oper2M_o,

    // branches and jumps
    output logic branch_takenE_o,
    output logic [31:0] branch_targetE_o,

    // from forwarding logic
    input [1:0] forward_rs1_i,
    input [1:0] forward_rs2_i,
    input [31:0] forward_ex_mem_data_i,
    input [31:0] forward_mem_wb_data_i
);

logic [31:0] rs1ValueE, rs2ValueE; // contain the most up to date values of the registers needed

mux3 #(32) mux_rs1_data_i (rs1_data_i, forward_mem_wb_data_i, forward_ex_mem_data_i, forward_rs1_i, rs1ValueE);
mux3 #(32) mux_rs2_data_i (rs2_data_i, forward_mem_wb_data_i, forward_ex_mem_data_i, forward_rs2_i, rs2ValueE);

logic [31:0] operand1, operand2; // arithmetic operations are done on these

// determine operand1
always_comb
begin
    operand1 = '0;

    case (alu_oper1_src_i)
        OPER1_RS1:
            operand1 = rs1ValueE;
        OPER1_PC:
            operand1 = pc_i;
        // OPER1_ZERO:
    endcase
end

// determine operand2
always_comb
begin
    operand2 = '0;

    case (alu_oper2_src_i)
        OPER2_RS2:
            operand2 = rs2ValueE;
        OPER2_IMM:
            operand2 = imm_i;
        OPER2_PC_INC:
            operand2 = 4; // no support for compressed instructions extension, yet
        // OPER2_ZERO:
    endcase
end

logic is_op2_neg;
always_comb
begin
    is_op2_neg = '0;
    unique case (alu_oper_i)
        ALU_SUB,
        ALU_SEQ, ALU_SNEQ,
        ALU_SGE, ALU_SGEU,
        ALU_SLT, ALU_SLTU: is_op2_neg = 1'b1;
        default:;
    endcase
end

// prepare both operands 1 and 2
logic [32:0] adder_in_1, adder_in_2;
logic [32:0] adder_result_ext;
logic [31:0] adder_result;

assign adder_in_1 = {operand1,1'b1};
assign adder_in_2 = is_op2_neg ? ~{operand2,1'b0} : {operand2,1'b0};

assign adder_result_ext = $unsigned(adder_in_1) + $unsigned(adder_in_2);
assign adder_result = adder_result_ext[32:1];

// produce the comparison values
logic is_equal, is_greater_equal;

assign is_equal = (adder_result == '0);

logic cmp_signed;
always_comb
begin: determine_if_signed
    cmp_signed = '0;
    unique case (alu_oper_i)
        ALU_SGE,
        ALU_SLT: cmp_signed = 1'b1;
        default:;
    endcase
end

// calculate greater or equal
always_comb
begin
    // if both operands have the same sign (++ or --), then if a - b is positive then a > b
    if ((operand1[31] ^ operand2[31]) == '0)
        is_greater_equal = (adder_result[31] == '0);

        // the operands' signs are not equal:
        // 1- if the cmp is signed, the one with the + sign is greater
        // 2- if the cmp is not signed, the operand with the MSB is greater
    else
        is_greater_equal = (operand1[31] ^ cmp_signed);
end

logic cmp_result;
// generate the comparison result
always_comb
begin
    cmp_result = '0;
    unique case (alu_oper_i)
        ALU_SEQ:            cmp_result = is_equal;
        ALU_SNEQ:           cmp_result = ~is_equal;
        ALU_SGE, ALU_SGEU:  cmp_result = is_greater_equal;
        ALU_SLT, ALU_SLTU:  cmp_result = ~is_greater_equal;
        default:;
    endcase
end

logic [31:0] alu_resultE;
wire [4:0] shift_amount = operand2[4:0];

// alu result mux
always_comb
begin
    alu_resultE = '0;
    unique case (alu_oper_i)
        ALU_ADD, ALU_SUB: alu_resultE = adder_result;

        // comparsion operations
        ALU_SEQ, ALU_SNEQ,
        ALU_SLT, ALU_SLTU,
        ALU_SGE, ALU_SGEU: alu_resultE = {31'd0, cmp_result};

        // bitwise operations
        ALU_XOR: alu_resultE = operand1 ^ operand2;
        ALU_OR:  alu_resultE = operand1 | operand2;
        ALU_AND: alu_resultE = operand1 & operand2;

        // shift operations
        ALU_SLL: alu_resultE = operand1 << shift_amount;
        ALU_SRL: alu_resultE = operand1 >> shift_amount;
        ALU_SRA: alu_resultE = $signed(operand1) >>> shift_amount;

        default:;
    endcase
end

logic branch_takenE;

branch_unit branch_unit_i (
    .rs1ValueE_i(rs1ValueE),
    .rs2ValueE_i(rs2ValueE),

    .pc_i(pc_i),
    .imm_i(imm_i),

    .bnj_oper_i(bnj_oper_i),
    .func3E_i(instrE_i[14:12]), // FIXME: not like this

    .branch_takenE_o(branch_takenE),
    .branch_targetE_o(branch_targetE_o)
);

flopenrc #(32) rs1ValueD_pipe (clk_i, rstn_i, flushM_i, !stallM_i, rs1ValueE, rs1ValueM_o);
flopenrc #(32) alu_result_pipe (clk_i, rstn_i, flushM_i, !stallM_i, alu_resultE, alu_resultM_o);
flopenrc #(32) alu_oper2_pipe (clk_i, rstn_i, flushM_i, !stallM_i, rs2ValueE, alu_oper2M_o);

/*
 * we used stallM instead of stallE because otherwise a logic loop would be created
 * this works because the only thing that can really stall a branch is stallM 
 */
assign branch_takenE_o = branch_takenE & ~stallM_i;

assign rs1_forwarded_value_o = rs1ValueE;
assign rs2_forwarded_value_o = rs2ValueE;

endmodule: execute
