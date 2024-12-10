`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`default_nettype none

module calibration_manager 
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
    // FRAME BUFFER VALUE and ADDRESS INPUTS
        input wire [CAL_TABLE_COUNTER_WIDTH-1:0] frame_buffer_in_address,
        input wire [15:0] frame_buffer_data,
        input wire use_this_frame_address_and_data,
    // CALIBRATION TABLE I/O
        // FOR READ REQUESTS FROM HDMI
        input wire [CAL_TABLE_COUNTER_WIDTH-1:0] cal_table_read_request_address,
        output logic [LED_ADDRESS_WIDTH:0] cal_table_read_data //DELAYED BY 2 CYCLES
);

// DEFINED LATER
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
    .web(1'b0), // write enable B SHOULD BE 0
    .ena(1'b1), // enable ram A
    .enb(1'b1) // enable ram B
    .rsta(rst), // reset ram A
    .rstb(rst) // reset ram B
    .regcea(1'b1), // register enable A
    .regceb(1'b1) // register enable B
);


// Instantiate the ID Shower module
id_shower #(
    .NUM_LEDS(NUM_LEDS),
    .LED_ADDRESS_WIDTH(LED_ADDRESS_WIDTH)
) id_shower_inst (
    .clk(clk),
    .rst(rst),
    .increment_bit(increment_id),
    .next_led_request(next_led_request),
    .green_out(green_out),
    .red_out(red_out),
    .blue_out(blue_out),
    .color_valid(color_valid),
    .displayed_frame_valid(displayed_frame_valid)
);

// FSM

// LOGIC TO PROCESS FRAME BUFFER DATA INTO CALIBRATION TABLE
// 1. Put address from frame buffer directly into calibration table lookup
assign internal_read_request_address = frame_buffer_in_address;
// 2. DELAY FRAME BUFFER DATA, ADDRESS, AND use_this_frame_address_and_data by 2 cycles
synchronizer #(
    .DEPTH(2),
    .WIDTH(16)
) sync_fb_data_ps1 (
    .clk_in  (clk),
    .rst_in  (rst),
    .data_in (frame_buffer_data),
    .data_out()
);

synchronizer #(
    .DEPTH(2),
    .WIDTH(CAL_TABLE_COUNTER_WIDTH)
) sync_fb_addr_ps1 (
    .clk_in  (clk),
    .rst_in  (rst),
    .data_in (frame_buffer_in_address),
    .data_out()
);

synchronizer #(
    .DEPTH(2),
    .WIDTH(1)
) sync_use_this_frame_address_and_data_ps1 (
    .clk_in  (clk),
    .rst_in  (rst),
    .data_in (use_this_frame_address_and_data),
    .data_out()
);

// 3. Threshold synchronized frame_buffer data, 
// then append to shifted data from bram,
// then store this back into the bram, 
// only do when calibration mode is on and sync_use_this_frame_address_and_data_ps1 is high
logic sync_fb_data_ps1_above_threshold;
assign sync_fb_data_ps1_above_threshold = sync_fb_data_ps1.data_out > 16'bFFF0; // TODO: modify this definition

assign internal_write_data = ((internal_read_data << 1) || (sync_fb_data_ps1_above_threshold));
assign internal_write_enable = calibration_on && sync_use_this_frame_address_and_data_ps1.data_out;


endmodule

`default_nettype wire