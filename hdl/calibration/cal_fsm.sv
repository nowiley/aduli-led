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
        output logic [LED_ADDRESS_WIDTH:0] cal_table_read_data
    // READ REQUESTS TO FRAME BUFFER
        output logic [CAL_TABLE_COUNTER_WIDTH-1:0] frame_buffer_read_request_address,
        input wire [15:0] frame_buffer_data
);

logic [CAL_TABLE_COUNTER_WIDTH-1:0] internal_read_request_address;
logic [LED_ADDRESS_WIDTH:0]         internal_read_data;
logic [LED_ADDRESS_WIDTH:0]         internal_write_data;
logic                               internal_write_enable;

// Instantiate the calibration table bram
// 2 Port so that we can write internally and allow hdmi to read externally
xilinx_true_dual_port_read_first_2_clock_ram 
#(
   .RAM_WIDTH = LED_ADDRESS_WIDTH + 1,
   .RAM_DEPTH = NUM_FRAME_BUFFER_PIXELS
) cal_table_bram (
    .clka(clk),
    // INTERNAL WRITE/READ to update calibration table
    .addra(internal_read_request_address), // internal read address  
    .douta(internal_read_data), // internal read data
    .wea(internal_write_enable), // internal write enable
    .dina(internal_write_data), // internal write data
    // EXTERNAL READ to read calibration table
    .addrb(cal_table_read_request_address), // external read address
    .doutb(cal_table_read_data) // external read data
    .ena(1'b1), // enable ram A
    .enb(1'b1) // enable ram B
    .rsta(rst), // reset ram A
    .rstb(rst) // reset ram B
    .regcea(1'b1), // register enable A
    .regceb(1'b1) // register enable B
);




endmodule

`default_nettype wire