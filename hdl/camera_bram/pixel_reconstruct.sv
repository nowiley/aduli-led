`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct
	#(
	parameter HCOUNT_WIDTH = 11,
	parameter VCOUNT_WIDTH = 10
	)
	(
	input wire 										 clk_in,
	input wire 										 rst_in,
	input wire 										 camera_pclk_in,
	input wire 										 camera_hs_in,
	input wire 										 camera_vs_in,
	input wire [7:0] 							     camera_data_in,
	
	output logic 									 pixel_valid_out,
	output logic [HCOUNT_WIDTH-1:0]                  pixel_hcount_out,
	output logic [VCOUNT_WIDTH-1:0] 				 pixel_vcount_out,
	output logic [15:0] 						 	 pixel_data_out
	);

	// your code here! and here's a handful of logics that you may find helpful to utilize.

	// previous value of PCLK
	logic 													 pclk_prev;

	// can be assigned combinationally:
	//  true when pclk transitions from 0 to 1
	logic 													 camera_sample_valid;
	assign camera_sample_valid = !pclk_prev && camera_pclk_in; // TODO: fix this assign

	// previous value of camera data, from last valid sample!
	// should NOT update on every cycle of clk_in, only
	// when samples are valid.
	logic 													 last_sampled_hs;
	logic 													 last_sampled_vs;
	logic [7:0] 										   last_sampled_data;

	// flag indicating whether the last byte has been transmitted or not.
	logic 													 half_pixel_ready;
	logic [HCOUNT_WIDTH-1:0] next_hcount;
	logic [VCOUNT_WIDTH-1:0] next_vcount;
	
	always_ff@(posedge clk_in) begin
		if (rst_in) begin
			// reset all states
			pclk_prev <= camera_pclk_in;
			pixel_valid_out <= 0;
			pixel_hcount_out <= 0;
			pixel_vcount_out <= 0;
			pixel_data_out <= 0;
			last_sampled_hs <= 0;
			last_sampled_vs <= 0;
			last_sampled_data <= 0;
			half_pixel_ready <= 0;
			next_hcount <= 0;
			next_vcount <= 0;
		end else 
			// Update the previouse values
			pclk_prev <= camera_pclk_in;
			pixel_valid_out <= 0;
			pixel_vcount_out <= next_vcount;
			pixel_hcount_out <= next_hcount;
			if (camera_sample_valid) begin // rising edge of camera_pclk_in
				// update the last sampled values
				last_sampled_hs <= camera_hs_in;
				last_sampled_vs <= camera_vs_in;
				last_sampled_data <= camera_data_in;
				// vsync falls
				if (!camera_vs_in) begin
					next_hcount <= 0;
					next_vcount <= 0;
					half_pixel_ready <= 0;
				// hsync falls
				end else if (!camera_hs_in) begin
					next_hcount <= 0;
					half_pixel_ready <= 0;
					if (last_sampled_hs) begin
						next_vcount <= pixel_vcount_out + 1;
					end
				// data operation
				end else if (half_pixel_ready) begin
					pixel_data_out <= {last_sampled_data, camera_data_in};
					next_hcount <= pixel_hcount_out + 1;
					half_pixel_ready <= 0;
					pixel_valid_out <= 1;
				end else begin
					half_pixel_ready <= 1;
				end
			end
		
	end

endmodule

`default_nettype wire
