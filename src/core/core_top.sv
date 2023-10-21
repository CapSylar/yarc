/*
    2023 with love
 __     __               _____                 _______          
 \ \   / /              / ____|               |__   __|         
  \ \_/ /_ _ _ __ ___  | |     ___  _ __ ___     | | ___  _ __  
   \   / _` | '__/ __| | |    / _ \| '__/ _ \    | |/ _ \| '_ \ 
    | | (_| | | | (__  | |___| (_) | | |  __/    | | (_) | |_) |
    |_|\__,_|_|  \___|  \_____\___/|_|  \___|    |_|\___/| .__/ 
                                                         | |    
                                                         |_|    
*/

module core_top
import riscv_pkg::*;
(
    input clk_i,
    input rstn_i,

    // Core <-> Imem interface
    output imem_read_o,
    output [31:0] imem_raddr_o,
    input [31:0] imem_rdata_i,

    // Core <-> Dmem interface
    output [31:0] dmem_addr_o,
    // read port
    output dmem_read_o,
    input [31:0] dmem_rdata_i,
    // write port
    output [3:0] dmem_wsel_byte_o,
    output [31:0] dmem_wdata_o
);

// Signal definitions

// Driven by the Fetch stage
logic instr_valid;
logic [31:0] if_id_instr;
logic [31:0] if_id_pc;

// Driven by the Register file
logic [31:0] rs1_data, rs2_data;

// Driven by the CS Register file
logic [31:0] csr_rdata;

// Driven by the Decode stage
logic [4:0] rs1_addr, rs2_addr;
logic csr_re;
logic [11:0] csr_raddr;
logic [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
alu_oper1_src_t id_ex_alu_oper1_src;
alu_oper2_src_t id_ex_alu_oper2_src;
bnj_oper_t id_ex_bnj_oper;
alu_oper_t id_ex_alu_oper;
mem_oper_t id_ex_mem_oper;
logic [11:0] id_ex_csr_waddr;
logic id_ex_csr_we;
logic id_ex_wb_use_mem;
logic id_ex_write_rd;
logic [4:0] id_ex_rd_addr;
logic [4:0] id_ex_rs1_addr;
logic [4:0] id_ex_rs2_addr;
logic id_ex_trap;
logic [31:0] id_ex_csr_rdata;

// Driven by the Ex stage
logic [31:0] ex_mem_alu_result;
logic [31:0] ex_mem_alu_oper2;
mem_oper_t ex_mem_mem_oper;
logic [11:0] ex_mem_csr_waddr;
logic ex_mem_csr_we;
logic ex_mem_wb_use_mem;
logic ex_mem_write_rd;
logic [4:0] ex_mem_rd_addr;
logic [31:0] new_pc;
logic load_pc;
logic ex_mem_trap;

// Driven by the Mem stage
logic mem_wb_use_mem;
logic mem_wb_write_rd;
logic [4:0] mem_wb_rd_addr;
logic [31:0] mem_wb_alu_result;
logic [31:0] mem_wb_dmem_rdata;
logic [31:0] csr_wdata;
logic [11:0] csr_waddr;
logic csr_we;
logic mem_wb_trap;

// Driven by the Wb stage
logic regf_write;
logic [4:0] regf_waddr;
logic [31:0] regf_wdata;

// Driven by the Dependency detection unit
logic forward_ex_mem_rs1;
logic forward_ex_mem_rs2;
logic forward_mem_wb_rs1;
logic forward_mem_wb_rs2;
logic [31:0] forward_ex_mem_data;
logic [31:0] forward_mem_wb_data;
logic if_id_stall;
logic id_ex_flush;
logic id_ex_stall;

// Fetch Stage

simple_fetch simple_fetch_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .valid_o(instr_valid),
    .instr_o(if_id_instr),
    .pc_o(if_id_pc),

    .stall_i(if_id_stall),

    .pc_i(new_pc),
    .new_pc_i(load_pc),

    // Imem interface
    .read_o(imem_read_o),
    .raddr_o(imem_raddr_o),
    .rdata_i(imem_rdata_i)
);

// Register file

reg_file reg_file_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // read port
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),

    .rs1_data_o(rs1_data),
    .rs2_data_o(rs2_data),

    // write port
    .write_i(regf_write),
    .waddr_i(regf_waddr),
    .wdata_i(regf_wdata)
);

// CS Register file
cs_registers cs_registers_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // read port
    .csr_re_i(csr_re),
    .csr_raddr_i(csr_raddr),
    .csr_rdata_o(csr_rdata),

    // write port
    .csr_we_i(csr_we),
    .csr_waddr_i(csr_waddr),
    .csr_wdata_i(csr_wdata)
);

// Decode Stage

decode decode_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // register file <-> decode module
    // read port
    .regf_rs1_addr_o(rs1_addr),
    .regf_rs2_addr_o(rs2_addr),
    .rs1_data_i(rs1_data),
    .rs2_data_i(rs2_data),

    // csr unit <-> decode module
    // read port
    .csr_re_o(csr_re),
    .csr_raddr_o(csr_raddr),
    .csr_rdata_i(csr_rdata),

    // from IF stage
    .instr_i(if_id_instr), // instruction
    .pc_i(if_id_pc), // pc of the instruction

    // ID/EX pipeline registers ************************************************

    // feedback into the pipeline register
    .stall_i(id_ex_stall), // keep the same content in the registers
    .flush_i(id_ex_flush), // zero the register contents

    // for direct use by the EX stage
    .pc_o(id_ex_pc), // forwarded from IF/ID
    .rs1_data_o(id_ex_rs1_data),
    .rs2_data_o(id_ex_rs2_data),
    .imm_o(id_ex_imm),
    .csr_rdata_o(id_ex_csr_rdata),
    .alu_oper1_src_o(id_ex_alu_oper1_src),
    .alu_oper2_src_o(id_ex_alu_oper2_src),
    .bnj_oper_o(id_ex_bnj_oper),
    .alu_oper_o(id_ex_alu_oper),

    // for the MEM stage
    .mem_oper_o(id_ex_mem_oper),
    .csr_waddr_o(id_ex_csr_waddr),
    .csr_we_o(id_ex_csr_we),

    // for the WB stage
    .wb_use_mem_o(id_ex_wb_use_mem),
    .write_rd_o(id_ex_write_rd),
    .rd_addr_o(id_ex_rd_addr),

    // used by the hazard/forwarding logic
    .rs1_addr_o(id_ex_rs1_addr),
    .rs2_addr_o(id_ex_rs2_addr),

    .trap_o(id_ex_trap)
);

// Execute Stage

execute execute_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from ID/EX
    .pc_i(id_ex_pc),
    .rs1_data_i(id_ex_rs1_data),
    .rs2_data_i(id_ex_rs2_data),
    .imm_i(id_ex_imm),
    .csr_rdata_i(id_ex_csr_rdata),
    .alu_oper1_src_i(id_ex_alu_oper1_src),
    .alu_oper2_src_i(id_ex_alu_oper2_src),
    .alu_oper_i(id_ex_alu_oper),
    .bnj_oper_i(id_ex_bnj_oper),

    // forward to MEM stage
    .mem_oper_i(id_ex_mem_oper),
    .csr_waddr_i(id_ex_csr_waddr),
    .csr_we_i(id_ex_csr_we),
    .trap_i(id_ex_trap),

    // forward to the WB stage
    .wb_use_mem_i(id_ex_wb_use_mem),
    .write_rd_i(id_ex_write_rd),
    .rd_addr_i(id_ex_rd_addr),

    // EX/MEM pipeline registers
    
    // feedback into the pipeline register
    .stall_i(1'b0), // keep the same content in the registers
    .flush_i(1'b0), // zero the register contents

    .alu_result_o(ex_mem_alu_result),
    .alu_oper2_o(ex_mem_alu_oper2),
    .mem_oper_o(ex_mem_mem_oper),
    .csr_waddr_o(ex_mem_csr_waddr),
    .csr_we_o(ex_mem_csr_we),
    .trap_o(ex_mem_trap),
    // for WB stage exclusively
    .wb_use_mem_o(ex_mem_wb_use_mem),
    .write_rd_o(ex_mem_write_rd),
    .rd_addr_o(ex_mem_rd_addr),

    // branches and jumps
    .load_pc_o(load_pc),
    .new_pc_o(new_pc),

    // from forwarding logic
    .forward_ex_mem_rs1_i(forward_ex_mem_rs1),
    .forward_ex_mem_rs2_i(forward_ex_mem_rs2),
    .forward_ex_mem_data_i(forward_ex_mem_data),

    .forward_mem_wb_rs1_i(forward_mem_wb_rs1),
    .forward_mem_wb_rs2_i(forward_mem_wb_rs2),
    .forward_mem_wb_data_i(forward_mem_wb_data)
);

// Memory Stage

mem_rw mem_rw_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // Mem-rw <-> Data Memory
    // read port
    .rw_addr_o(dmem_addr_o),
    .read_o(dmem_read_o),
    .rdata_i(dmem_rdata_i),
    // write port
    .wsel_byte_o(dmem_wsel_byte_o),
    .wdata_o(dmem_wdata_o),

    // Mem-rw <-> CS Register File
    // write port
    .csr_wdata_o(csr_wdata),
    .csr_waddr_o(csr_waddr),
    .csr_we_o(csr_we),

    // from EX/MEM
    .alu_result_i(ex_mem_alu_result),
    .alu_oper2_i(ex_mem_alu_oper2),
    .mem_oper_i(ex_mem_mem_oper),
    .csr_waddr_i(ex_mem_csr_waddr),
    .csr_we_i(ex_mem_csr_we),
    .trap_i(ex_mem_trap),
    // for WB stage exclusively
    .wb_use_mem_i(ex_mem_wb_use_mem),
    .write_rd_i(ex_mem_write_rd),
    .rd_addr_i(ex_mem_rd_addr),

    // MEM/WB pipeline registers
    .wb_use_mem_o(mem_wb_use_mem),
    .write_rd_o(mem_wb_write_rd),
    .rd_addr_o(mem_wb_rd_addr),
    .alu_result_o(mem_wb_alu_result),
    .dmem_rdata_o(mem_wb_dmem_rdata),
    .trap_o(mem_wb_trap)
);

// Write-back Stage

write_back write_back_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // from MEM/WB
    .use_mem_i(mem_wb_use_mem),
    .write_rd_i(mem_wb_write_rd),
    .rd_addr_i(mem_wb_rd_addr),
    .alu_result_i(mem_wb_alu_result),
    .dmem_rdata_i(mem_wb_dmem_rdata),

    // WB -> Register file
    .regf_write_o(regf_write),
    .regf_waddr_o(regf_waddr),
    .regf_wdata_o(regf_wdata)
);

// Dependency detection unit

dep_hzrd_detection dep_detection_i
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // ID stage
    .id_rs1_addr_i(rs1_addr),
    .id_rs2_addr_i(rs2_addr),

    // ID/EX pipeline
    .id_ex_rs1_addr_i(id_ex_rs1_addr),
    .id_ex_rs2_addr_i(id_ex_rs2_addr),
    .id_ex_rd_addr_i(id_ex_rd_addr),
    .id_ex_write_rd_i(id_ex_write_rd),
    .id_ex_wb_use_mem_i(id_ex_wb_use_mem),

    // from EX/MEM
    .ex_mem_rd_addr_i(ex_mem_rd_addr),
    .ex_mem_write_rd_i(ex_mem_write_rd),
    .ex_mem_wb_use_mem_i(ex_mem_wb_use_mem),
    .ex_mem_alu_result_i(ex_mem_alu_result),

    // from MEM/WB
    .mem_wb_rd_addr_i(mem_wb_rd_addr),
    .mem_wb_write_rd_i(mem_wb_write_rd),
    .mem_wb_use_mem_i(mem_wb_use_mem),
    .mem_wb_alu_result_i(mem_wb_alu_result),
    .mem_wb_dmem_rdata_i(mem_wb_dmem_rdata),

    // forward from EX/MEM stage
    .forward_ex_mem_rs1_o(forward_ex_mem_rs1),
    .forward_ex_mem_rs2_o(forward_ex_mem_rs2),
    .forward_ex_mem_data_o(forward_ex_mem_data),
    // forward from MEM/WB stage
    .forward_mem_wb_rs1_o(forward_mem_wb_rs1),
    .forward_mem_wb_rs2_o(forward_mem_wb_rs2),
    .forward_mem_wb_data_o(forward_mem_wb_data),

    .instr_valid_i(instr_valid),
    .load_pc_i(load_pc),

    // hazard lines to ID/EX
    .id_ex_flush_o(id_ex_flush),
    .id_ex_stall_o(id_ex_stall),

    // hazard lines to IF/EX
    .if_id_stall_o(if_id_stall)
);

endmodule : core_top