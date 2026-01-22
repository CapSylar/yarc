// contains the settings registers for the video core

module video_core_ctrl
import video_pkg::*;
(
    input clk_i,
    input rstn_i,

    wishbone_if.SLAVE config_if,

    // status lines
    input wire is_vblank_i,

    // outputs config registers
    output video_config_t video_config_o,
    output video_addr_t video_addr_o
);

wire is_addressed  = config_if.cyc & config_if.stb;
wire [2:0] addr = config_if.addr[2:0];

logic [31:0] wb_data_d, wb_data_q;
logic ack_d, ack_q;

video_config_t video_config_q;
video_addr_t video_addr_q;
video_status_t video_status;

logic video_config_we, video_addr_we;

always_comb begin :wb_read
    wb_data_d = '0;

    case (addr)
        VIDEO_CONFIG: wb_data_d = 32'(video_config_q);
        VIDEO_ADDR: wb_data_d = 32'(video_addr_q);
        VIDEO_STATUS: wb_data_d = 32'(video_status);
    endcase
end

always_comb begin: wb_write
    video_config_we = '0;
    video_addr_we = '0;

    if (is_addressed && config_if.we) begin
        case (addr)
            VIDEO_CONFIG: video_config_we = 1'b1;
            VIDEO_ADDR: video_addr_we = 1'b1;
            default:;
        endcase
    end
end

assign ack_d = is_addressed;

always_ff @(posedge clk_i) begin
    if (!rstn_i) begin
        wb_data_q <= '0;
        ack_q <= '0;
    end else begin
        wb_data_q <= wb_data_d;
        ack_q <= ack_d;
    end
end

// config registers
localparam VIDEO_CFG_SZ = $bits(video_config_t);
reg_bw #(.WIDTH(VIDEO_CFG_SZ), .RESET_VALUE('0)) video_config_reg
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .rdata_o(video_config_q),
    .we_i(video_config_we),
    .wsel_i(config_if.sel[$bits(video_config_reg.wsel_i)-1:0]),
    .wdata_i(config_if.wdata[VIDEO_CFG_SZ-1:0])
);

localparam VIDEO_ADDR_SZ = $bits(video_addr_t);
reg_bw #(.WIDTH(VIDEO_ADDR_SZ) , .RESET_VALUE('0)) video_addr_reg
(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .rdata_o(video_addr_q),
    .we_i(video_addr_we),
    .wsel_i(config_if.sel[$bits(video_addr_reg.wsel_i)-1:0]),
    .wdata_i(config_if.wdata[VIDEO_ADDR_SZ-1:0])
);

assign video_status = '{is_vblank: is_vblank_i};

// assign wishbone signals
assign config_if.rdata = wb_data_q;
assign config_if.ack = ack_q;
assign config_if.stall = '0;
assign config_if.err = '0;
assign config_if.rty = '0;

// assign outputs
assign video_config_o = video_config_t'(video_config_q);
assign video_addr_o = video_addr_t'(video_addr_q);

endmodule: video_core_ctrl
