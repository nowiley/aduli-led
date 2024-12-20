`timescale 1ns / 1ps
`include "common/evt_counter.sv"
`default_nettype none  // prevents system from inferring an undeclared logic (good practice)


module moving_pix #(
    parameter int CLOCK_SPEED = 100_000_000,  // 100MHz
    parameter int NUM_LEDS = 20, // !!! ASSUMES STRAND DRIVER HAS MORE LEDS (next_led_request >= NUM_LEDS)
    parameter int FRAMES_PER_LED = 100,
    parameter int COLOR_WIDTH = 8,
    parameter int GREEN_VAL = 8'hFF,
    parameter int RED_VAL = 8'hFF,
    parameter int BLUE_VAL = 8'hFF,
    localparam int LED_COUNTER_WIDTH = $clog2(NUM_LEDS),
    localparam int FRAME_COUNTER_WIDTH = $clog2(FRAMES_PER_LED)
    )
    (
    input wire rst_in,  // active high
    input wire clk_in,  // 100MHz
    input wire [LED_COUNTER_WIDTH-1:0] next_led_request,
    input wire request_valid,
    output logic [COLOR_WIDTH-1:0] green_out,
    output logic [COLOR_WIDTH-1:0] red_out,
    output logic [COLOR_WIDTH-1:0] blue_out,
    output logic color_ready
    );  

    logic [LED_COUNTER_WIDTH-1:0] current_pixel_idx;
    logic [LED_COUNTER_WIDTH-1:0] last_pixel_request;
    logic [FRAME_COUNTER_WIDTH-1:0] num_strand_frames;
    logic cur_pix_displayed;
    assign cur_pix_displayed = ((last_pixel_request != next_led_request) && (last_pixel_request == current_pixel_idx));
    logic displayed_prev_led;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // Reset all states
            current_pixel_idx <= 0;
            last_pixel_request <= next_led_request;
            num_strand_frames <= 0;
            green_out <= 8'h00;
            red_out <= 8'h00;
            blue_out <= 8'h00;
            color_ready <= 0;
            displayed_prev_led <= 0;
        end else begin
            // Update num_strand_frames too keep track of how many frames we display current_pixel_idx
            last_pixel_request <= next_led_request;
            if (cur_pix_displayed) begin
                if (num_strand_frames == FRAMES_PER_LED - 1) begin
                    // Increment current pixel index to display
                    current_pixel_idx <= (current_pixel_idx == NUM_LEDS - 1) ? 0 : current_pixel_idx + 1;
                    displayed_prev_led <= 1;
                end else begin
                    displayed_prev_led <= 0;
                end
                // handle looping and skipping next led on last frame of current led
                num_strand_frames <= (displayed_prev_led) ? 0 :  (num_strand_frames == FRAMES_PER_LED - 1) ? 0 : num_strand_frames + 1;
            end

            // Respond to requests
            if (next_led_request == current_pixel_idx && !displayed_prev_led) begin
                green_out <= GREEN_VAL;
                red_out <= RED_VAL;
                blue_out <= BLUE_VAL;
                color_ready <= 1;
            end else begin
                green_out <= 8'h00;
                red_out <= 8'h00;
                blue_out <= 8'h00;
                color_ready <= 1;
            end
        end
    end

endmodule
`default_nettype wire