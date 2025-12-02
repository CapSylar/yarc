// stage_mem1 module

`default_nettype none

module stage_mem1
import riscv_pkg::*;
(
    input wire clk_i,
    input wire rstn_i,

    // <-> CS Register File
    // write port
    // output logic [31:0] csr_wdata_o,
    // output logic [11:0] csr_waddr_o,
    // output logic csr_we_o,

    // Load Store Unit
    output logic lsu_req_o,
    // read port
    output logic [31:0] lsu_addr_o,
    output logic lsu_we_o,
    // write port
    output logic [3:0] lsu_wsel_byte_o,
    output logic [31:0] lsu_wdata_o,
    input wire lsu_req_stall_i,

    input wire [31:0] lsu_rdata_i,
    input wire lsu_req_done_i,

    // from EX/MEM1
    input wire [31:0] alu_result_i,
    input wire [31:0] alu_oper2_i,
    input wire mem_oper_t mem_oper_i,
    input wire [31:0] csr_wdata_i,
    input wire [11:0] csr_waddr_i,
    input wire instr_valid_i,
    // input wire is_csr_i,
    input wire csr_we_i,
    input wire trapM_i,

    // for WB stage exclusively
    input wire write_rd_i,
    input wire [4:0] rd_addr_i,

    // MEM1/MEM2 pipeline registers
    output logic instr_valid_o,
    // output logic is_csr_o,
    output logic write_rd_o,
    output logic [4:0] rd_addr_o,
    output logic [31:0] alu_result_o,
    output logic [31:0] lsu_rdata_o,
    output mem_oper_t mem_oper_o,

    output logic lsu_stall_m_o,
    output logic load_misaligned_trapM_o,
    output logic store_misaligned_trapM_o,
    
    input wire stall_i,
    input wire flush_i
);

// TODO: handle unaligned loads and stores, signal an error in this case
wire [31:0] addr = lsu_addr_o;
wire [31:0] to_write = alu_oper2_i;
logic [3:0] wsel_byte;
logic [31:0] wdata;
logic is_write;

// detected unaligned addresses
wire is_half_unaligned = (mem_oper_i[1:0] == 2'b01) & (addr[0] == 1'b1);
wire is_word_unaligned = (mem_oper_i[1:0] == 2'b10) & (|addr[1:0]);

wire misaligned_trap = is_half_unaligned | is_word_unaligned;
assign load_misaligned_trapM_o = misaligned_trap & ~mem_oper_i[3];
assign store_misaligned_trapM_o = misaligned_trap & mem_oper_i[3];

// format the write data
always_comb
begin
    wsel_byte = '0;
    wdata = '0;
    is_write = '0;

    case(mem_oper_i)
        MEM_SB:
        begin
            is_write = 1'b1;
            wsel_byte = 4'b0001 << addr[1:0];
            wdata = to_write << (addr[1:0] * 8);
        end

        MEM_SH:
        begin
            is_write = 1'b1;
            wsel_byte = 4'b0011 << (addr[1] * 2);
            wdata = to_write << (addr[1] * 16);
        end

        MEM_SW:
        begin
            is_write = 1'b1;
            wsel_byte = 4'b1111;
            wdata = to_write;
        end

        default:
        begin end
    endcase
end

logic [31:0] rdata;
// format the read data correctly
always_comb
begin : format_rdata
    rdata = '0;

    case(mem_oper_i)
        MEM_LB:
        begin
            case (alu_result_i[1:0])
                2'b00: rdata = 32'(signed'(lsu_rdata_i[(8*1)-1 -:8]));
                2'b01: rdata = 32'(signed'(lsu_rdata_i[(8*2)-1 -:8]));
                2'b10: rdata = 32'(signed'(lsu_rdata_i[(8*3)-1 -:8]));
                2'b11: rdata = 32'(signed'(lsu_rdata_i[(8*4)-1 -:8]));
            endcase
        end
        MEM_LBU:
        begin
            case (alu_result_i[1:0])
                2'b00: rdata = 32'(lsu_rdata_i[(8*1)-1 -:8]);
                2'b01: rdata = 32'(lsu_rdata_i[(8*2)-1 -:8]);
                2'b10: rdata = 32'(lsu_rdata_i[(8*3)-1 -:8]);
                2'b11: rdata = 32'(lsu_rdata_i[(8*4)-1 -:8]);
            endcase 
        end
        MEM_LH:
        begin
            case (alu_result_i[1])
                1'b0: rdata = 32'(signed'(lsu_rdata_i[(16*1)-1 -:16]));
                1'b1: rdata = 32'(signed'(lsu_rdata_i[(16*2)-1 -:16]));
            endcase
        end

        MEM_LHU:
        begin
            case (alu_result_i[1])
                1'b0: rdata = 32'(lsu_rdata_i[(16*1)-1 -:16]);
                1'b1: rdata = 32'(lsu_rdata_i[(16*2)-1 -:16]);
            endcase
        end
        MEM_LW:
        begin
            rdata = lsu_rdata_i;
        end
        default:;
    endcase
end

// memory request to be issued in the current must be known 1 cycle in advance
// so we must determine if a memory instruction currently in EX will be in MEM in the next cycle

// when not to start a memory request
wire cannot_issue_req = trapM_i | flush_i ; // | stall_i;

typedef enum {IDLE, WAITING_FOR_DONE} state_t;
state_t state, next;

flopr_type #(state_t, IDLE) state_flop (clk_i, rstn_i, next, state);

always_comb
begin
    next = state;
    lsu_req_o = 1'b0;

    unique case (state)
        IDLE: begin
            if (mem_oper_i != MEM_NOP & !cannot_issue_req) begin
                lsu_req_o = 1'b1;
                next = WAITING_FOR_DONE;
            end
        end

        WAITING_FOR_DONE: begin
            if (lsu_req_done_i) begin
                next = IDLE;
            end
        end
    endcase
end

/*
 * Here I am using the fact that for now lsu req never responds in the same cycle
 */
assign lsu_stall_m_o = lsu_req_o | (state != IDLE) & ~lsu_req_done_i;

// lsu outputs
assign lsu_addr_o = alu_result_i;
assign lsu_wdata_o = wdata;
assign lsu_wsel_byte_o = wsel_byte;
assign lsu_we_o = is_write;

wire no_csr_commit = stall_i | trapM_i != NO_SYS;

// csrs
// assign csr_we_o = csr_we_i & ~no_csr_commit;
// assign csr_wdata_o = csr_wdata_i;
// assign csr_waddr_o = csr_waddr_i;

// pipeline registers
flopenrc #(1) write_rd_reg      (clk_i, rstn_i, flush_i, !stall_i, write_rd_i, write_rd_o);
// flopenrc #(1) is_csr_reg        (clk_i, rstn_i, flush_i, !stall_i, is_csr_i, is_csr_o);
flopenrc #(32) alu_result_reg   (clk_i, rstn_i, flush_i, !stall_i, alu_result_i, alu_result_o);
flopenrc #(32) lsu_rdata_reg    (clk_i, rstn_i, flush_i, !stall_i, rdata, lsu_rdata_o);
flopenrc_type #(mem_oper_t, MEM_NOP) mem_oper_reg     (clk_i, rstn_i, flush_i, !stall_i, mem_oper_i, mem_oper_o);

flopenrc #(5) rd_addr_reg       (clk_i, rstn_i, flush_i, !stall_i, rd_addr_i, rd_addr_o);
flopenrc #(1) instr_valid_reg   (clk_i, rstn_i, flush_i, !stall_i, instr_valid_i, instr_valid_o);

// flopenrc #(1) csr_we_reg        (clk_i, rstn_i, flush_i, !stall_i, csr_we_i, csr_we_o);
// flopenrc #(12) csr_waddr_reg    (clk_i, rstn_i, flush_i, !stall_i, csr_waddr_i, csr_waddr_o);
// flopenrc #(32) csr_wdata_reg    (clk_i, rstn_i, flush_i, !stall_i, csr_wdata_i, csr_wdata_o);

// flopenrc_type #(exc_t, NO_SYS) trap_reg             (clk_i, rstn_i, flush_i, !stall_i, trapM_i, trap_o);

endmodule: stage_mem1

`default_nettype wire
