`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`default_nettype none

module led_color_buffer
#(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 10,
    parameter int CAMERA_COLOR_WIDTH = 16
)(
    // For requests from the calibration_fsm_accum_lookup table
    // Clocked off of HDMI pixel clock
        input wire clk_pixel,
        input wire [LED_ADDRESS_WIDTH-1:0] led_lookup_address,
        input wire [CAMERA_COLOR_WIDTH-1:0] camera_color,
        input wire led_color_buffer_enable,
    
    // For requests from led driver
    // Clocked off of LED driver clock
        input wire clk_led,
        input wire [LED_ADDRESS_WIDTH-1:0] led_address,
        output logic [7:0] green_out,
        output logic [7:0] red_out,
        output logic [7:0] blue_out
        output logic color_valid
);



endmodule 


`default_nettype wire