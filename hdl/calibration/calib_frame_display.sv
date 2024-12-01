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
module calib_frame_display
# (
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 6
)(
    input wire clk,
    input wire rst,
    input wire [3:0] btn,
    input wire [15:0] sw,
    input [LED_ADDRESS_WIDTH:0] next_led_request,
    output [7:0] green_out,
    output [7:0] red_out,
    output [7:0] blue_out
);


endmodule


`default_nettype wire