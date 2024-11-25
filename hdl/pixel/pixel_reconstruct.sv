`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`default_nettype none

module pixel_reconstruct #(
    parameter HCOUNT_WIDTH = 11,
    parameter VCOUNT_WIDTH = 10
) (
    input  wire                     clk_in,
    input  wire                     rst_in,
    input  wire                     camera_pclk_in,
    input  wire                     camera_hs_in,
    input  wire                     camera_vs_in,
    input  wire  [             7:0] camera_data_in,
    output logic                    pixel_valid_out,
    output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
    output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
    output logic [            15:0] pixel_data_out
);

    // your code here! and here's a handful of logics that you may find helpful to utilize.

    // previous value of PCLK
    logic       pclk_prev;

    // can be assigned combinationally:
    //  true when pclk transitions from 0 to 1
    wire        camera_sample_valid = ~pclk_prev & camera_pclk_in;
    wire        data_in_valid = camera_hs_in & camera_vs_in;

    // previous value of camera data, from last valid sample!
    // should NOT update on every cycle of clk_in, only
    // when samples are valid.
    logic       last_sampled_hs;
    logic [7:0] last_sampled_data;

    // flag indicating whether the last byte has been transmitted or not.
    logic       half_pixel_ready;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            pixel_valid_out <= 0;
            pixel_hcount_out <= 0;
            pixel_vcount_out <= -1;
            pixel_data_out <= 0;
            half_pixel_ready <= 0;
            last_sampled_hs <= 0;
            last_sampled_data <= 0;
            pclk_prev <= 0;
        end else begin
            if (camera_sample_valid) begin
                if (data_in_valid) begin
                    if (half_pixel_ready) begin
                        pixel_data_out   <= {last_sampled_data, camera_data_in};
                        half_pixel_ready <= 0;
                        pixel_valid_out  <= 1;
                    end else begin
                        last_sampled_data <= camera_data_in;
                        half_pixel_ready  <= 1;
                        pixel_valid_out   <= 0;

                        if (!last_sampled_hs) begin  // started new line
                            pixel_hcount_out <= 0;
                            pixel_vcount_out <= pixel_vcount_out + 1;
                        end else pixel_hcount_out <= pixel_hcount_out + 1;
                    end
                end else begin
                    pixel_valid_out  <= 0;
                    half_pixel_ready <= 0;
                    if (!camera_vs_in) begin
                        pixel_vcount_out <= -1;  // will be reset to 0 on next cycle
                        pixel_hcount_out <= 0;
                    end
                end

                last_sampled_hs <= camera_hs_in && camera_vs_in;
            end else pixel_valid_out <= 0;
        end

        pclk_prev <= camera_pclk_in;
    end

endmodule

`default_nettype wire
