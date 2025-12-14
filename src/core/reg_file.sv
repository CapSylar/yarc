// register file
// reads are asynchronous since they will pipelined anyway

// handle the internal forwarding from the WB stage to the ID stage
// forwarding will happen in the case where an instruction in the
// WB stage will write to a register that is being read by the ID stage, in this case ID will read a stale value
// It can't be forwarded like from the EX/MEM or MEM/WB stage because on the next cycle,
// the instruction is not in the pipeline anymore

module reg_file
#(parameter ADDR_WIDTH = 5, parameter REG_SIZE = 32)
( 
    input clk_i,
    input rstn_i,

    // read port
    input [ADDR_WIDTH-1:0] rs1_addr_i,
    input [ADDR_WIDTH-1:0] rs2_addr_i,

    output [REG_SIZE-1:0] rs1_data_o,
    output [REG_SIZE-1:0] rs2_data_o,

    // write port
    input write_i,
    input [ADDR_WIDTH-1:0] waddr_i,
    input [REG_SIZE-1:0] wdata_i
);

// register file
logic [REG_SIZE-1:0] regf [2**ADDR_WIDTH];

logic [REG_SIZE-1:0] rs1_data;
logic [REG_SIZE-1:0] rs2_data;

wire write = write_i && (waddr_i != 0);

// asynchronous read
// TODO: check impact on timing
always_comb
begin
    rs1_data = 0;
    rs2_data = 0;

    if (write && (rs1_addr_i == waddr_i)) // internal forwarding
    begin
        rs1_data = wdata_i;
    end
    else
        rs1_data = regf[rs1_addr_i];

    if(write && (rs2_addr_i == waddr_i)) // internal forwarding
    begin
        rs2_data = wdata_i;
    end
    else
        rs2_data = regf[rs2_addr_i];
end

// reset and write
always_ff@(posedge clk_i, negedge rstn_i)
begin
    if (!rstn_i)
    begin
        for (int i = 0; i < 2**ADDR_WIDTH; ++i)
            regf[i] <= 0;
    end
    else if (write && waddr_i != 0)
        regf[waddr_i] <= wdata_i;
end

// outputs
assign rs1_data_o = rs1_data;
assign rs2_data_o = rs2_data;

endmodule : reg_file