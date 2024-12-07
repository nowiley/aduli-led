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
    input wire rst,
    // For requests from the calibration_fsm_accum_lookup table
    // Clocked off of HDMI pixel clock
        input wire clk_pixel,
        input wire [LED_ADDRESS_WIDTH-1:0] led_lookup_address,
        input wire [CAMERA_COLOR_WIDTH-1:0] camera_color,
        input wire led_color_buffer_enable,
    
    // For requests from led driver
    // Clocked off of LED driver clock
        input wire clk_led,
        input wire [LED_ADDRESS_WIDTH-1:0] next_led_request_address,
        output logic [7:0] green_out,
        output logic [7:0] red_out,
        output logic [7:0] blue_out
        output logic color_valid
);
logic write_to_buffer;
assign write_to_buffer = ((led_color_buffer_enable) && (led_lookup_address <= NUM_LEDS));
logic data_out;
// Instantiate 2-port ram 2 clocks
xilinx_true_dual_port_read_first_2_clock_ram #(
    .DATA_WIDTH(CAMERA_COLOR_WIDTH),
    .RAM_DEPTH(NUM_LEDS)
) led_color_ram (
    // INPUT FROM CAMERA
    .clka(clk_pixel),                           // Port A clock
    .addra(led_lookup_address),  // Port A address bus, width determined from RAM_DEPTH
    .dina(camera_color),           // Port A RAM input data
    .wea(write_to_buffer),                            // Port A write enable
    .ena(1'b1),                            // Port A RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),                           // Port A output reset (does not affect memory contents)
    .douta(),         // Port A RAM output data
    // OUTPUT TO LED DRIVER
    .clkb(clk_led),                           // Port B clock
    .addrb(next_led_request_address),  // Port B address bus, width determined from RAM_DEPTH
    .web(1'b0),                            // Port B write enable
    .enb(1'b1),                            // Port B RAM Enable, for additional power savings, disable port when not in use
    .rstb(rst),                           // Port B output reset (does not affect memory contents)
    .doutb(data_out),          // Port B RAM output data
    .regcea(1'b1),                         // Port A output register enable
    .regceb(1'b1),                         // Port B output register enable
);





endmodule 


`default_nettype wire