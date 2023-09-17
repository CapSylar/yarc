// dependancy and hazard detection unit
// TODO: document functionality

module dep_hzrd_detection
(
    input clk_i,
    input rstn_i,

    // ID stage
    input [4:0] id_rs1_addr_i,
    input [4:0] id_rs2_addr_i,

    // ID/EX pipeline
    input [4:0] id_ex_rs1_addr_i,
    input [4:0] id_ex_rs2_addr_i,
    input [4:0] id_ex_rd_addr_i,
    input id_ex_write_rd_i,
    input id_ex_wb_use_mem_i,

    // from EX/MEM
    input [4:0] ex_mem_rd_addr_i,
    input ex_mem_write_rd_i,
    input ex_mem_wb_use_mem_i,
    input [31:0] ex_mem_alu_result_i,

    // from MEM/WB
    input [4:0] mem_wb_rd_addr_i,
    input mem_wb_write_rd_i,
    input mem_wb_use_mem_i,
    input [31:0] mem_wb_alu_result_i,
    input [31:0] mem_wb_dmem_rdata_i,

    // forward from EX/MEM stage to EX stage
    output forward_ex_mem_rs1_o,
    output forward_ex_mem_rs2_o,
    output [31:0] forward_ex_mem_data_o,
    // forward from MEM/WB stage to EX stage
    output forward_mem_wb_rs1_o,
    output forward_mem_wb_rs2_o,
    output [31:0] forward_mem_wb_data_o,

    input instr_valid_i,
    input load_pc_i,

    // hazard lines to ID/EX
    output id_ex_flush_o,
    output id_ex_stall_o,

    // hazard lines to IF/EX
    output if_id_stall_o
);

// forwarding to the EX stage happens when we are writing to a register that is sourced
// by the instruction currently decoded, it will read a stale value in the decode stage

// we can't foward from the EX stage if the instruction will load from memory
// since the alu result is not the written value but the address to memory
wire ex_mem_forward_possible = (ex_mem_rd_addr_i != 0) && ex_mem_write_rd_i && !ex_mem_wb_use_mem_i;
wire mem_wb_forward_possible = (mem_wb_rd_addr_i != 0) && mem_wb_write_rd_i;

logic forward_ex_mem_rs1;
logic forward_ex_mem_rs2;
logic forward_mem_wb_rs1;
logic forward_mem_wb_rs2;

always_comb begin : forwarding
    forward_ex_mem_rs1 = 0;
    forward_ex_mem_rs2 = 0;
    forward_mem_wb_rs1 = 0;
    forward_mem_wb_rs2 = 0;

    // Note: forwarding from the most recent stage takes priority

    // consider this example where we could forward from EX/MEM and from MEM/WB
    // add x3,x3,x4
    // add x3,x3,x5
    // add x3,x3,x4
    // in this case all Rd is the same for the 3 instructions
    // we must forward from the most recent stage which is EX/MEM since it contains the most up-to-date version of Rd

    // forward rs1
    if (ex_mem_forward_possible && (ex_mem_rd_addr_i == id_ex_rs1_addr_i))
        forward_ex_mem_rs1 = 1;
    else if (mem_wb_forward_possible && (mem_wb_rd_addr_i == id_ex_rs1_addr_i))
        forward_mem_wb_rs1 = 1;

    // forward rs2
    if (ex_mem_forward_possible && (ex_mem_rd_addr_i == id_ex_rs2_addr_i))
        forward_ex_mem_rs2 = 1;
    else if (mem_wb_forward_possible && (mem_wb_rd_addr_i == id_ex_rs2_addr_i))
        forward_mem_wb_rs2 = 1;
end

// outputs
assign forward_ex_mem_rs1_o = forward_ex_mem_rs1;
assign forward_ex_mem_rs2_o = forward_ex_mem_rs2;
assign forward_mem_wb_rs1_o = forward_mem_wb_rs1;
assign forward_mem_wb_rs2_o = forward_mem_wb_rs2;

// data to be forwarded
assign forward_ex_mem_data_o = ex_mem_alu_result_i; // through here just for cleanliness

// 1- if the MEM stage loaded a value, we need this value to be forwarded not the alu result
// the alu result has been used as the address to load from in this case
// 2- if the MEM stage hasn't loaded, forward the alu result
assign forward_mem_wb_data_o = mem_wb_use_mem_i ? mem_wb_dmem_rdata_i : mem_wb_alu_result_i;

// Hazard Section

// handle use after load hazard
// In this case we will stall the instruction needing the loaded value for 1 cycle
// after that, forwarding from the MEM/WB will let it proceed

// A load instruction is currently in the ex_mem stage
wire id_ex_load = id_ex_write_rd_i && id_ex_wb_use_mem_i;
wire load_use_hzrd = id_ex_load && ((id_ex_rd_addr_i == id_rs1_addr_i) ||
    (id_ex_rd_addr_i == id_rs2_addr_i));

// For now, the cpu always predicts that the branch is not taken and continues
// On a mispredict, flush the 2 instruction after the branch and continue from the new PC
assign id_ex_flush_o = load_pc_i || !instr_valid_i || load_use_hzrd;
assign id_ex_stall_o = 0;
assign if_id_stall_o = load_use_hzrd;

endmodule: dep_hzrd_detection