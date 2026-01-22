module video_core
import video_pkg::*;
(
	input clk_i,
    input rstn_i,

    input pixel_clk_i,
	input pixel_rstn_i,
    input pixel_clk_5x_i,

	wishbone_if.SLAVE config_if,

    wishbone_if.MASTER fetch_if,
    
    // hdmi signal outputs
	output logic [3:0] hdmi_channel_o
);

// the frame starts in the blanking area after reset
localparam [9:0] X_COUNTER_INIT_VALUE = '0;
localparam [9:0] Y_COUNTER_INIT_VALUE = 'd481;

logic vblank;

// module configuration registers
video_config_t video_config;
video_addr_t video_addr;

video_core_ctrl video_core_ctrl_i
(
	.clk_i(clk_i),
	.rstn_i(rstn_i),

	.config_if(config_if),

	.is_vblank_i(vblank),

	.video_config_o(video_config),
	.video_addr_o(video_addr)
);

logic wb_cyc, wb_stb, wb_ack, wb_stall;
logic [31:0] wb_addr_d, wb_addr_q;

assign wb_ack = fetch_if.ack;
assign wb_stall = fetch_if.stall;

localparam ASIZE = 9;
localparam DSIZE = 128;

logic ff_we;
logic [DSIZE-1:0] ff_wdata;
logic ff_full;
logic [ASIZE:0] ff_fill_count;

logic async_ff_re;
logic [DSIZE-1:0] async_ff_rdata;
logic async_ff_empty;

async_fifo #(.DATA_WIDTH(DSIZE), .ADDR_WIDTH(ASIZE)) afifo_i
(
	// write side
	.wclk_i(clk_i),
	.wrstn_i(rstn_i),
	.we_i(ff_we),
	.wdata_i(ff_wdata),
	.full_o(ff_full),
	.wfill_count_o(ff_fill_count),

	// read side
	.rclk_i(pixel_clk_i),
	.rrstn_i(pixel_rstn_i),
	.re_i(async_ff_re),
	.rdata_o(async_ff_rdata),
	.empty_o(async_ff_empty)
);

logic adapter_re;
logic adapter_rsize;
logic [31:0] adapter_rdata;
logic adapter_empty;

// assign adapter_rsize = video_config.is_text_mode ? 1'b0 : 1'b1;

// fifo frontend adapter placed at the read side of the fifo above
// allows use to read in 16 or 32-bit chunks without specializing the fifo
fifo_adapter fifo_adapter_i
(
	.clk_i(pixel_clk_i),
	.rstn_i(pixel_rstn_i),

	// connection to fifo
	.empty_i(async_ff_empty),
	.re_o(async_ff_re),
	.rdata_i(async_ff_rdata),

	// adapter read interface
	.re_i(adapter_re),
	.rsize_i(adapter_rsize),
	.rdata_o(adapter_rdata),
	.empty_o(adapter_empty)
);

assign ff_we = wb_ack;
assign ff_wdata = fetch_if.rdata;

logic [ASIZE:0] req_pending_d, req_pending_q;
wire [ASIZE:0] max_ff_count = {1'b1, {(ASIZE){1'b0}}};
wire ff_one_till_full = (req_pending_q + ff_fill_count) >= (max_ff_count-1'b1);

// ==================================== fetching part ====================================
// read data from the framebuffer into the line fifos

// *fetch_start* pulses when the fetching logic should start fetching data from the framebuffer
// and store it in the fifo
logic fetch_start_synced;
logic [16:0] reqs_left_d, reqs_left_q; // contains the number left for this frame

// for text mode: 80 * 30 * 2 bytes for an entire frame, we fetch 16b bytes per req thus = 300
// for raw mode : 640 * 480 * 4 bytes for an entire frame, thus = 76800 fetches
wire [16:0] initial_reqs_left = video_config.is_text_mode ? 'd300 : 'd76800;

assign wb_req_ok = wb_cyc & wb_stb & ~wb_stall;

enum {IDLE, FETCHING, FIFO_FULL, WAIT_OUTSTANDING} state, next;
always_ff @(posedge clk_i)
	if (!rstn_i) state <= IDLE;
	else	     state <= next;

always_comb begin
	next = state;

	wb_cyc = '0;
	wb_stb = '0;

	wb_addr_d = wb_addr_q;
	reqs_left_d = reqs_left_q;

	case (state)
		IDLE: begin
			// fetching starts if the module is enabled and the update period is over
			if (video_config.is_enabled && fetch_start_synced) begin

				wb_addr_d = video_addr.fb_address;
				reqs_left_d = initial_reqs_left;
				next = FETCHING;
			end
		end

		FETCHING: begin
			wb_cyc = 1'b1;
			wb_stb = 1'b1;

			if (wb_req_ok) begin
				wb_addr_d += 'd1;
				reqs_left_d -= 1'd1;
			end

			if (reqs_left_d == '0) begin
				next = WAIT_OUTSTANDING; // if no requests are left to send
			end else if (wb_req_ok && ff_one_till_full) begin
				// we can't issue more requests currently since there is no way to store them
				// back off and wait for some fifo space to become available
				next = FIFO_FULL;
			end
		end

		FIFO_FULL: begin
			wb_cyc = 1'b1;

			if (!ff_one_till_full)
				next = FETCHING;
		end

		WAIT_OUTSTANDING: begin // stay here till all acks have been received
			wb_cyc = 1'b1;

			if (req_pending_q == '0)
				next = IDLE;
		end
	endcase
end

// bookkeeping logic
always_comb begin: count_pending_reqs

	req_pending_d = req_pending_q;

	if (fetch_if.ack) begin
		req_pending_d = req_pending_d - 1;
	end

	if (wb_req_ok) begin
		req_pending_d = req_pending_d + 1;
	end
end

always_ff @(posedge clk_i) begin
	if (!rstn_i) begin
		req_pending_q <= '0;
		wb_addr_q <= '0;
		reqs_left_q <= '0;
	end else begin
		req_pending_q <= req_pending_d;
		wb_addr_q <= wb_addr_d;
		reqs_left_q <= reqs_left_d;
	end
end

logic [9:0] x_counter;
logic [9:0] y_counter;
logic hsync, vsync;
logic draw_area;
logic [23:0] rgb; // final rgb value presented to the video phy

// text mode
logic text_mode_adapter_re;
logic text_mode_adapter_rsize;
logic [23:0] text_mode_rgb;

logic is_active_frame_d, is_active_frame_q;
logic fetch_start;

video_text_mode #(.X_COUNTER_INIT_VALUE(X_COUNTER_INIT_VALUE),
				  .Y_COUNTER_INIT_VALUE(Y_COUNTER_INIT_VALUE))
video_text_mode_i
(
	.sys_clk_i(clk_i),
	.sys_rstn_i(rstn_i),
	
	.enable_i(is_active_frame_q),
	.frame_pulse_i(fetch_start),

	.pixel_clk_i(pixel_clk_i),
	.pixel_rstn_i(pixel_rstn_i),

	.adapter_empty_i(adapter_empty),
	.adapter_rdata_i(adapter_rdata),
	.adapter_re_o(text_mode_adapter_re),
	.adapter_rsize_o(text_mode_adapter_rsize),

	.rgb_o(text_mode_rgb)
);

logic [23:0] raw_mode_rgb;
logic raw_mode_adapter_re;
logic raw_mode_adapter_rsize;

// in raw framebuffer mode, we can read just in time
assign raw_mode_adapter_re = draw_area & ~adapter_empty;
assign raw_mode_adapter_rsize = 1'b1;
assign raw_mode_rgb = adapter_rdata[23:0];

// Mux control signals between text mode and raw mode
assign adapter_re = video_config.is_text_mode ? text_mode_adapter_re : raw_mode_adapter_re;

// 16-bit reads for text-mode
// 32-bit reads for raw framebuffer mode
assign adapter_rsize = video_config.is_text_mode ? text_mode_adapter_rsize : raw_mode_adapter_rsize;
assign rgb = video_config.is_text_mode ? text_mode_rgb : raw_mode_rgb;

// ===================================== drawing part ==============================================

// testing a simple hdmi(really dvi) driver
// create a 640x480 image
// we really have a 800 x 525 pixel area

// cross fetch start to the other domain
logic [1:0] sys_clk_sync;
logic [1:0] pixel_clk_sync;

logic fetch_start_ack;
logic fetch_start_d, fetch_start_q;

always_ff @(posedge clk_i) begin
	{sys_clk_sync} <= {sys_clk_sync[0], fetch_start_q};
end

always_ff @(posedge pixel_clk_i) begin
	{pixel_clk_sync} <= {pixel_clk_sync[0], fetch_start_synced};
end

assign fetch_start_synced = sys_clk_sync[1];
assign fetch_start_ack = pixel_clk_sync[1];

always_comb begin
	fetch_start_d = fetch_start_q;

	if (fetch_start) begin
		fetch_start_d = 1'b1;
	end

	if (fetch_start_ack) begin
		fetch_start_d = '0;
	end
end

always_ff @(posedge clk_i) begin
	if (!pixel_rstn_i) begin
		fetch_start_q <= '0;
	end else begin
		fetch_start_q <= fetch_start_d;
	end
end

assign fetch_start = (x_counter == '0 && y_counter == 'd500);

assign is_active_frame_d = fetch_start ? video_config.is_enabled : is_active_frame_q;

always_ff @(posedge pixel_clk_i, negedge pixel_rstn_i) begin
	if (!pixel_rstn_i) is_active_frame_q <= '0;
	else is_active_frame_q <= is_active_frame_d;
end

always_ff @(posedge pixel_clk_i or negedge pixel_rstn_i)
begin
	if (!pixel_rstn_i)
	begin
		x_counter <= X_COUNTER_INIT_VALUE;
		y_counter <= Y_COUNTER_INIT_VALUE;
	end
	else
	begin
		x_counter <= (x_counter == 'd799) ? '0 : x_counter + 1'b1;

		if (x_counter == 'd799)
			y_counter <= (y_counter == 'd524) ? '0 : y_counter + 1'b1;
	end
end


// create the hsync and vsync signals
assign hsync = (x_counter >= 'd656) & (x_counter < 'd757);
assign vsync = (y_counter >= 'd490) & (y_counter < 'd492);
assign draw_area = (x_counter < 'd640) & (y_counter < 'd480);
assign vblank = (y_counter > 'd480);

// hdmi phy
hdmi_phy hdmi_phy_i
(
	.pixel_clk_i(pixel_clk_i),
	.pixel_clk_5x_i(pixel_clk_5x_i),
	.rstn_i(pixel_rstn_i),

	.rgb_i(rgb),

	.hsync(hsync),
	.vsync(vsync),

	.draw_area_i(draw_area),

	// output hdmi channels
	.hdmi_channel_o(hdmi_channel_o)
);

// assign wishbone signals
assign fetch_if.cyc = wb_cyc;
assign fetch_if.stb = wb_stb;
assign fetch_if.we = '0;
assign fetch_if.addr = wb_addr_q;
assign fetch_if.sel = '1;
assign fetch_if.wdata = '0;

endmodule: video_core
