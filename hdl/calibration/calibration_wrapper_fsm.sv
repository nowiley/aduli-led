`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`default_nettype none

module calibration_wrapper_fsm 
#(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = $clog2(NUM_LEDS),
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
        output logic displayed_frame_valid,
    // FAST FRAME BUFFER INPUTS FROM FRAME BUFFER AND HDMI_SIG_GEN
        input wire [CAL_TABLE_COUNTER_WIDTH-1:0] fast_frame_buffer_in_address,
        input wire [15:0] fast_frame_buffer_data,
    // CALIBRATION TABLE I/O
        // FOR READ REQUESTS FROM HDMI
        input wire [CAL_TABLE_COUNTER_WIDTH-1:0] cal_table_read_request_address,
        output logic [LED_ADDRESS_WIDTH:0] cal_table_read_data //DELAYED BY 2 CYCLES
);

logic [CAL_TABLE_COUNTER_WIDTH-1:0] frame_buffer_in_address;
logic [15:0] frame_buffer_data;


// INSTANTIATE THE CALIBRATION MANAGER
calibration_manager #(
    .NUM_LEDS = NUM_LEDS,
    .LED_ADDRESS_WIDTH = LED_ADDRESS_WIDTH,
    .NUM_FRAME_BUFFER_PIXELS = NUM_FRAME_BUFFER_PIXELS,
    .CAL_TABLE_COUNTER_WIDTH = CAL_TABLE_COUNTER_WIDTH
) calibration_manager_inst (
    .clk(clk),
    .rst(rst),
    .increment_id(increment_id),
    .capture_shown_frame(capture_shown_frame),
    .calibration_on(calibration_on),
    .next_led_request(next_led_request),
    .green_out(green_out),
    .red_out(red_out),
    .blue_out(blue_out),
    .color_valid(color_valid),
    .displayed_frame_valid(displayed_frame_valid),
    .frame_buffer_in_address(frame_buffer_in_address),
    .frame_buffer_data(frame_buffer_data),
    .cal_table_read_request_address(cal_table_read_request_address),
    .cal_table_read_data(cal_table_read_data)
);

endmodule

`default_nettype wire