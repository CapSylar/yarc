
package riscv_pkg;

typedef enum logic [6:0]
{
    LUI =       7'b0110111,
    AUIPC =     7'b0010111,
    JAL =       7'b1101111,
    JALR =      7'b1100111,
    BRANCH =    7'b1100011,

    LOAD =      7'b0000011,
    STORE =     7'b0100011,

    ARITH_IMM = 7'b0010011,
    ARITH =     7'b0110011,

    FENCE =     7'b0001111,

    SYSTEM =    7'b1110011 // ecall, ebreak and Zicsr instructions
} opcode_t;

typedef enum logic [2:0]
{
    ADD =   3'b000,
    SLT =   3'b010,
    SLTU =  3'b011,
    XOR =   3'b100,
    OR =    3'b110,
    AND =   3'b111,
    SLL =   3'b001,
    SRA_L = 3'b101
} opcode_alu_t;

typedef enum logic [3:0]
{
    // the 3 LSBs are made to correspond with the func3 field of the opcode for arithmetic instructions
    // the MSB indicates the variations when func3 is the same for different operations
    ALU_ADD =   4'b0000,
    ALU_SUB =   4'b1000,

    ALU_SEQ =   4'b1100,
    ALU_SNEQ =  4'b1110,

    ALU_SLT =   4'b0010,
    ALU_SGE =   4'b1010,

    ALU_SLTU =  4'b0011,
    ALU_SGEU =  4'b1011,

    ALU_XOR =   4'b0100,
    ALU_OR =    4'b0110,
    ALU_AND =   4'b0111,
    
    ALU_SLL =   4'b0001,

    ALU_SRL =   4'b0101,
    ALU_SRA =   4'b1101
} alu_oper_t;

typedef enum
{
    OPER1_RS1,
    OPER1_ZERO,
    OPER1_PC,
    OPER1_CSR_IMM
} alu_oper1_src_t;

typedef enum
{
    OPER2_RS2,
    OPER2_IMM,
    OPER2_PC_INC,
    OPER2_CSR,
    OPER2_ZERO
} alu_oper2_src_t;

typedef enum logic [2:0]
{
    BEQ =   3'b000,
    BNE =   3'b001,
    BLT =   3'b100,
    BGE =   3'b101,
    BLTU =  3'b110,
    BGEU =  3'b111
} opcode_branch_t;

typedef enum logic [2:0]
{
    CSRRW = 3'b001,
    CSRRS = 3'b010,
    CSRRC = 3'b011,
    CSRRWI= 3'b101,
    CSRRSI= 3'b110,
    CSRRCI= 3'b111
} system_opc_t;

typedef enum logic [1:0]
{
    BNJ_NO,
    BNJ_JAL,
    BNJ_JALR,
    BNJ_BRANCH
} bnj_oper_t; // branch n jump operation

typedef enum logic [3:0]
{
    // MSB = 0 => load || MSB = 1 => store
    // the 3 LSBs have the same encoding as the func3 field in the opcode

    MEM_LB = 4'b0000,
    MEM_LH = 4'b0001,
    MEM_LW = 4'b0010,
    MEM_LBU = 4'b0100,
    MEM_LHU = 4'b0101,

    MEM_SB = 4'b1000,
    MEM_SH = 4'b1001,
    MEM_SW = 4'b1010,

    MEM_NOP = 4'b1111 // no operation
} mem_oper_t;

function logic is_mem_oper_load(mem_oper_t mem_oper);
    return !mem_oper[3];
endfunction: is_mem_oper_load

typedef enum logic [4:0]
{
    NO_SYS = 5'b1_0000,
    MRET = 5'b1_0001, // TODO: not an exception, find a better place maybe ?
    
    // INST_ADDR_MISALIGN = 5'd0,
    // INST_ACC_FAULT = 5'd1,

    // ILL_INSTR = 5'd2,
    BRK_POINT = 5'd3,

    // LOAD_ADDR_MISALIGNED = 5'd4,
    // LOAD_ACC_FAULT = 5'd5,

    // STORE_AMO_ADDR_MISALIGNED = 5'd6,
    // STORE_AMO_ACC_FAULT = 5'd7,

    ECALL_UMODE = 5'd8,
    ECALL_MMODE = 5'd11

    // INSTR_PAGE_FAULT = 5'd12,
    // LOAD_PAGE_FAULT = 5'd13,

    // STORE_AMO_PAGE_FAULT = 5'd15
} exc_t;

typedef enum logic [1:0]
{
    PC_JUMP,
    PC_MEPC,
    PC_TRAP,
    PC_CSRW
} pc_sel_t;

typedef enum logic [1:0]
{
    RESULT_ALU,
    RESULT_MEM,
    RESULT_CSR
} result_src_e;

endpackage: riscv_pkg