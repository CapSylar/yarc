module top
(
    input clk_i
);

logic rstn, rstn_t;
logic imem_read;
logic [31:0] imem_raddr;
logic [31:0] imem_rdata;
wire imem_ena = !imem_raddr[30];

// Instruction Memory
sp_mem #(.MEMFILE(`IMEMFILE)) imem
(
    .clk_i(clk_i),
    .ena_i(imem_ena),

    .read_i(imem_read),
    .addr_i(imem_raddr[31:2]), // 4-byte addressable
    .rdata_o(imem_rdata),

    .wsel_byte_i(0),
    .wdata_i(0)
);

logic [31:0] dmem_addr;
logic dmem_read;
logic [31:0] dmem_rdata;
logic [3:0] dmem_wsel_byte;
logic [31:0] dmem_wdata;
wire dmem_ena = dmem_addr[30];

// Data Memory
sp_mem #(.MEMFILE(`DMEMFILE)) dmem
(
    .clk_i(clk_i),
    .ena_i(dmem_ena),

    .read_i(dmem_read),
    .addr_i(dmem_addr[31:2]), // 4-byte addressable
    .rdata_o(dmem_rdata),

    .wsel_byte_i(dmem_wsel_byte),
    .wdata_i(dmem_wdata)
);

// Core Top
core_top yarc_top
(
    .clk_i(clk_i),
    .rstn_i(rstn),

    // Core <-> Imem interface
    .imem_read_o(imem_read),
    .imem_raddr_o(imem_raddr),
    .imem_rdata_i(imem_rdata),

    // Core <-> Dmem interface
    .dmem_addr_o(dmem_addr),
    // read port
    .dmem_read_o(dmem_read),
    .dmem_rdata_i(dmem_rdata),
    // write port
    .dmem_wsel_byte_o(dmem_wsel_byte),
    .dmem_wdata_o(dmem_wdata)
);

always_ff @(posedge clk_i)
begin
    rstn <= rstn_t;
end

initial
begin
    rstn_t = 1;
    repeat(2) @(posedge clk_i);

    rstn_t = 0;
    repeat(2) @(posedge clk_i);

    rstn_t = 1;
end

endmodule
