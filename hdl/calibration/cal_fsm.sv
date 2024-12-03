`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`default_nettype none

module cal_fsm 
#(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 6,
    parameter int NUM_FRAME_BUFFER_PIXELS = 360 * 180,
    localparam int CAL_TABLE_COUNTER_WIDTH = $clog2(NUM_FRAME_BUFFER_PIXELS)
)(
        input wire clk, 
    // USER INTERACTIONS
        input wire rst,
        input wire increment_id,
        input wire capture_shown_frame,
        input wire calibration_on,
    // LED Driver I/O
        input wire [LED_ADDRESS_WIDTH:0] next_led_request,
        // LED STRAND DRIVING OUTPUTS
        output logic [7:0] green_out,
        output logic [7:0] red_out,
        output logic [7:0] blue_out,
        output logic color_valid,
        // FRAME DISPLAYED FLAG
        output logic displayed_frame_valid
    // CALIBRATION TABLE I/O
        // FOR READ REQUESTS FROM HDMI
        input wire [CAL_TABLE_COUNTER_WIDTH-1:0] cal_table_read_request_address,
        output logic [LED_ADDRESS_WIDTH:0] cal_table_read_data,

);


endmodule

`default_nettype wire