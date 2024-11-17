`timescale 1ns / 1ps
`default_nettype none
`include "led_driver.sv"

module top_level (
    input wire clk_100mhz,
    output logic [15:0] led, // green leds
    input wire [3:0] btn,  // push buttons
    input wire [15:0] sw,  // switches
    output logic [3:0] strand_out // strand output wire PMODA
);

assign strand_out[1] = clk_100mhz; // FOR DEBUGGING

// instantiate led_driver module
led_driver #(.NUM_LEDS(10)) 
    led_driver_inst (    
    .rst_in(btn[0]),
    .clk_in(clk_100mhz),
    .force_reset(btn[1]),
    .red_in({sw[15:11], 3'b000}),
    .green_in({sw[10:5], 2'b000}),
    .blue_in({sw[4:0], 3'b000}),
    .color_valid(1'b1),
    .strand_out(strand_out[0]),
    .next_led_request(),
    .request_valid()
);


endmodule
`default_nettype wire
