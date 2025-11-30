// execute module

module execute
import riscv_pkg::*;
(
    input clk_i,
    input rstn_i,

    // from ID/EX
    input [31:0] pc_i,
    input [31:0] rs1_data_i,
    input [31:0] rs2_data_i,
    input [31:0] imm_i,
    input alu_oper1_src_t alu_oper1_src_i,
    input alu_oper2_src_t alu_oper2_src_i,
    input alu_oper_t alu_oper_i,
    input bnj_oper_t bnj_oper_i,
    input instr_valid_i,
    input mem_oper_t mem_oper_i,
    // input [11:0] csr_waddr_i,
    input exc_t trap_i,
    
    // forward to the WB stage
    input write_rd_i,
    input [4:0] rd_addr_i,

    // EX/MEM pipeline registers
    output logic [31:0] rs1ValueM_o,

    // feedback into the pipeline registers
    input stall_i,
    input flush_i,

    output logic [31:0] alu_result_o, // always contains a mem address or the rd value
    output logic [31:0] alu_oper2_o,
    output mem_oper_t mem_oper_o,
    // output logic [31:0] csr_wdata_o,
    // output logic [11:0] csr_waddr_o,
    output exc_t trap_o,
    output logic [31:0] pc_o,
    output logic instr_valid_o,

    // for WB stage exclusively
    output logic write_rd_o,
    output logic [4:0] rd_addr_o,

    // branches and jumps
    output logic new_pc_en_o,
    output logic [31:0] branch_target_o,

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

    unique case (alu_oper1_src_i)
        OPER1_RS1:
            operand1 = rs1ValueE;
        OPER1_PC:
            operand1 = pc_i;
        OPER1_ZERO:
            operand1 = '0;
        OPER1_CSR_IMM:
            operand1 = imm_i;
        default:;
    endcase
end

// determine operand2
always_comb
begin
    operand2 = '0;

    unique case (alu_oper2_src_i)
        OPER2_RS2:
            operand2 = rs2ValueE;
        OPER2_IMM:
            operand2 = imm_i;
        OPER2_PC_INC:
            operand2 = 4; // no support for compressed instructions extension, yet
        OPER2_CSR:
            operand2 = '0;
        OPER2_ZERO:
            operand2 = '0;
        default:;
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

logic [31:0] alu_result;
wire [4:0] shift_amount = operand2[4:0];

// alu result mux
always_comb
begin
    alu_result = '0;
    unique case (alu_oper_i)
        ALU_ADD, ALU_SUB: alu_result = adder_result;

        // comparsion operations
        ALU_SEQ, ALU_SNEQ,
        ALU_SLT, ALU_SLTU,
        ALU_SGE, ALU_SGEU: alu_result = {31'd0, cmp_result};

        // bitwise operations
        ALU_XOR: alu_result = operand1 ^ operand2;
        ALU_OR:  alu_result = operand1 | operand2;
        ALU_AND: alu_result = operand1 & operand2;

        // shift operations
        ALU_SLL: alu_result = operand1 << shift_amount;
        ALU_SRL: alu_result = operand1 >> shift_amount;
        ALU_SRA: alu_result = $signed(operand1) >>> shift_amount;

        default:;
    endcase
end

logic new_pc_en;
// handle branches and jumps
always_comb
begin
    new_pc_en = '0;
    branch_target_o = '0;

    unique case (bnj_oper_i)
        BNJ_JAL:
        begin
            new_pc_en = 1'b1;
            branch_target_o = pc_i + imm_i;
        end

        BNJ_JALR:
        begin
            new_pc_en = 1'b1;
            branch_target_o = rs1ValueE + imm_i;
        end

        BNJ_BRANCH:
        begin
            new_pc_en = cmp_result;
            branch_target_o = pc_i + imm_i;
        end
        default:;
    endcase
end

flopenrc #(32) rs1ValueD_pipe (clk_i, rstn_i, flush_i, !stall_i, rs1ValueE, rs1ValueM_o);

// pipeline registers and outputs
always_ff @(posedge clk_i)
begin : ex_mem_pip
    if (!rstn_i || flush_i)
    begin
        mem_oper_o <= MEM_NOP;
        trap_o <= NO_TRAP;
        instr_valid_o <= '0;
        write_rd_o <= 0;
    end
    else if (!stall_i)
    begin
        // TODO: rename alu_result_o
        // since it doesn't really reflect alu_result
        // it is really the value to write to rd if any
        alu_result_o <= alu_result;
        alu_oper2_o <= rs2ValueE;
        mem_oper_o <= mem_oper_i;
        trap_o <= trap_i;
        pc_o <= pc_i;
        instr_valid_o <= instr_valid_i;

        write_rd_o <= write_rd_i;
        rd_addr_o <= rd_addr_i;
    end
end

assign new_pc_en_o = new_pc_en & ~(flush_i | stall_i);

endmodule: execute
