`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`include "common/synchronizer.sv"
`default_nettype none

typedef enum logic {
    ID_SHOWER_OUT = 0,
    CAMERA_COLOR_OUT = 1
} led_out_mux_t;

module led_out_mux #(
    parameter int COLOR_WIDTH = 8 
)(
    input wire led_out_mux_t        led_out_mux_mode,
    input wire                      moving_override,
    // LED SHOWER INPUTS
    input wire [COLOR_WIDTH-1:0]    id_shower_green_out,
    input wire [COLOR_WIDTH-1:0]    id_shower_red_out,
    input wire [COLOR_WIDTH-1:0]    id_shower_blue_out,
    input wire                      id_shower_color_valid,
    // LED_COLOR_BUFFER INPUTS
    input wire [COLOR_WIDTH-1:0]    led_color_buffer_green_out,
    input wire [COLOR_WIDTH-1:0]    led_color_buffer_red_out,
    input wire [COLOR_WIDTH-1:0]    led_color_buffer_blue_out,
    input wire                      led_color_buffer_color_valid,
    // Moving Pixel Inputs
    input wire [COLOR_WIDTH-1:0]    moving_pixel_green_out,
    input wire [COLOR_WIDTH-1:0]    moving_pixel_red_out,
    input wire [COLOR_WIDTH-1:0]    moving_pixel_blue_out,
    input wire                      moving_pixel_color_valid,
    // OUTPUTS
    output logic [COLOR_WIDTH-1:0]  green_out,
    output logic [COLOR_WIDTH-1:0]  red_out,
    output logic [COLOR_WIDTH-1:0]  blue_out,
    output logic                    color_valid
);

always_comb begin
    if (moving_override) begin
        green_out = moving_pixel_green_out;
        red_out = moving_pixel_red_out;
        blue_out = moving_pixel_blue_out;
        color_valid = moving_pixel_color_valid;
    end else if (led_out_mux_mode == ID_SHOWER_OUT) begin
        green_out = id_shower_green_out;
        red_out = id_shower_red_out;
        blue_out = id_shower_blue_out;
        color_valid = id_shower_color_valid;
    end else begin
        green_out = led_color_buffer_green_out;
        red_out = led_color_buffer_red_out;
        blue_out = led_color_buffer_blue_out;
        color_valid = led_color_buffer_color_valid;
    end
end


endmodule

`default_nettype none