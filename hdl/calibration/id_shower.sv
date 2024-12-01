`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "mem/xilinx_single_port_ram_read_first.v"
`include "cam/camera_registers.sv"
`default_nettype none

// Module to debug calibration, four user interactions
// Four user interactions:
// 1. User presses button 0 to reset
// 2. User presses button 1 to display next calibration frame on leds
// 3. User presses button 2 to capture current calibration frame stores in bram 
// (shows threshholded pixels on hdmi)
// 4. Updates the camera settings (exposure) and resets calibration frames
// 4. Displays ID of current calibration frame buffer on leds id[10:0] -> g [10:7] r [6:3] b [2:0]
// ADDRESS WITDH MUST BE LESS THAN # CYCLES FOR LED
// 3 CYCLE DELAY FROM WHEN NEXT LED_REQUEST IS MADE
module id_shower
# (
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 6
)(
    input wire clk,
    input wire rst,
    input wire [3:0] btn,
    input wire [15:0] sw,
    input [LED_ADDRESS_WIDTH:0] next_led_request,
    output logic [7:0] green_out,
    output logic [7:0] red_out,
    output logic [7:0] blue_out,
    output logic color_valid,
    output logic displayed_frame_valid
);
    localparam ADDRESS_BIT_COUNTER_WIDTH = $clog2($clog2(NUM_LEDS));
    logic [ADDRESS_BIT_COUNTER_WIDTH-1:0] address_bit_counter; // hold what bit lsb part of ids are showing
    logic [LED_ADDRESS_WIDTH-1:0] current_shift_amount;

    logic processing_request;
    logic can_display_pixel;
    logic [LED_ADDRESS_WIDTH-1:0] prev_request;
    logic [LED_ADDRESS_WIDTH-1:0] temp_request_to_process;

    enum logic [1:0] {
        SEEN_ZERO_ZERO_REQUESTS,
        SEEN_ONE_ZERO_REQUESTS,
        VALID_DISPLAY  
    } display_state;

    assign can_display_pixel = (address_bit_counter == current_shift_amount) && (btn == 1);
    assign displayed_frame_valid = (display_state == VALID_DISPLAY);

    always_ff @(posedge clk) begin
        if (rst) begin // assuming rst is tied to button 0
            address_bit_counter <= 0;
            green_out <= 0;
            red_out <= 0;
            blue_out <= 0;
            processing_request <= 0;
            color_valid <= 0;
        end else begin
            // General behavior taking in request, processing, and outputting
            if (processing_request) begin
                if (can_display_pixel) begin
                    // HANDLE COLOR OUTPUT
                    case (temp_request_to_process[0])
                        0: begin
                            green_out <= 0;
                            red_out <= 8'hFF;
                            blue_out <= 0;
                        end
                        1: begin
                            green_out <= 0;
                            red_out <= 0;
                            blue_out <= 8'hFF;
                        end
                        default: begin // SHOULD NEVER GO HERE
                            green_out <= 8'hFF;
                            red_out <= 0;
                            blue_out <= 0;
                        end
                    endcase
                    // HANDLE DISPLAY STATE
                    case (display_state && prev_request == 0)
                        SEEN_ZERO_ZERO_REQUESTS: display_state <= SEEN_ONE_ZERO_REQUESTS;
                        SEEN_ONE_ZERO_REQUESTS: display_state <= VALID_DISPLAY;
                        default: display_state <= SEEN_ZERO_ZERO_REQUESTS;
                    endcase
                    color_valid <= 1;
                    processing_request <= 0;
                end else begin
                    color_valid <= 0;
                    processing_request <= 1;
                    temp_request_to_process <= temp_request_to_process >> 1;
                    current_shift_amount <= current_shift_amount + 1;
                end
            end else if (next_led_request != prev_request) begin
                // accept new request
                temp_request_to_process <= next_led_request;
                prev_request <= next_led_request;
                processing_request <= 1;
                current_shift_amount <= 0;
                color_valid <= 0;
            end

            // Handle Button Pushes
            if (btn[1]) begin
                address_bit_counter <= address_bit_counter + 1;
                display_state <= SEEN_ONE_ZERO_REQUESTS;
            end else if (btn[2]) begin
                address_bit_counter <= address_bit_counter - 1;
                display_state <= SEEN_ZERO_ZERO_REQUESTS;
            end 
        end
    end


endmodule


`default_nettype wire