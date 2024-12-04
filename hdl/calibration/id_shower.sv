`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "mem/xilinx_single_port_ram_read_first.v"
`include "common/debouncer.sv"
`default_nettype none

// Module to debug calibration, four user interactions
// Three interactions
// Reset: reset
// Increment: displays next bit of led address
// Decrement: displays previous bit of led address
module id_shower
# (
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 6
)(
    input wire clk,
    input wire rst,
    input wire increment_bit,
    input wire decrement_bit,
    input wire [LED_ADDRESS_WIDTH:0] next_led_request,
    output logic [7:0] green_out,
    output logic [7:0] red_out,
    output logic [7:0] blue_out,
    output logic color_valid,
    output logic displayed_frame_valid,
    output logic [ADDRESS_BIT_NUMER_WIDTH-1:0] address_bit_num; // hold what bit lsb part of ids are showing
);
    localparam ADDRESS_BIT_NUMER_WIDTH = $clog2($clog2(NUM_LEDS));

    logic [LED_ADDRESS_WIDTH-1:0] prev_request;
    logic prev_increment_bit;
    logic prev_decrement_bit;

    enum logic [1:0] {
        SEEN_ZERO_ZERO_REQUESTS,
        SEEN_ONE_ZERO_REQUESTS,
        VALID_DISPLAY  
    } display_state;

    assign displayed_frame_valid = (display_state == VALID_DISPLAY);
    logic flag;

    always_ff @(posedge clk) begin
        if (rst) begin // assuming rst is tied to button 0
            green_out <= 0;
            red_out <= 0;
            blue_out <= 0;
            color_valid <= 0;
            address_bit_num <= 0;
            prev_request <= 0;
            prev_increment_bit <= increment_bit;
            prev_decrement_bit <= decrement_bit;
            display_state <= SEEN_ZERO_ZERO_REQUESTS;
        // HANDLE INCREMENT AND DECREMENT
        end else if ((increment_bit && !prev_increment_bit) || (decrement_bit && ! prev_decrement_bit)) begin
            prev_increment_bit <= increment_bit;
            prev_decrement_bit <= decrement_bit;
            flag <= 1;
            if (increment_bit && !prev_increment_bit) begin
                address_bit_num <= address_bit_num + 1;
                display_state <= SEEN_ZERO_ZERO_REQUESTS;
            end else if (decrement_bit && ! prev_decrement_bit) begin
                address_bit_num <= address_bit_num - 1;
                display_state <= SEEN_ZERO_ZERO_REQUESTS;
            end
        // HANDLE GENERAL CASE
        end else begin
            // DISPLAY CURRENT BIT OF REQUEST ADDRESS
            case (next_led_request[address_bit_num])
            0: begin
                green_out <= 0;
            red_out <= 8'hFF;
                blue_out <= 0;
                color_valid <= 1;
            end
            1: begin
                green_out <= 0;
                red_out <= 0;
                blue_out <= 8'hFF;
                color_valid <= 1;
            end
            default: begin // SHOULD NEVER GO HERE
                green_out <= 8'hFF;
                red_out <= 0;
                blue_out <= 0;
                color_valid <= 1;
            end
            endcase

            prev_request <= next_led_request;
            prev_increment_bit <= increment_bit;
            prev_decrement_bit <= decrement_bit;
            // accept new requests
            if (next_led_request != prev_request) begin
                if (prev_request == 0) begin
                case (display_state)
                    SEEN_ZERO_ZERO_REQUESTS: display_state <= SEEN_ONE_ZERO_REQUESTS;
                    SEEN_ONE_ZERO_REQUESTS: display_state <= VALID_DISPLAY;
                    VALID_DISPLAY: display_state <= VALID_DISPLAY;
                    default: display_state <= SEEN_ZERO_ZERO_REQUESTS;
                endcase
                end
            end
        end
    end


endmodule


`default_nettype wire