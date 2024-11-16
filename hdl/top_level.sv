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

// instantiate led_driver module
led_driver led_driver_inst (
    .NUM_LEDS(2),
    .rst(btn[0]),
    .clk_in(clk_100mhz),
    .force_reset(btn[1]),
    .green_in(sw[23:16]),
    .red_in(sw[15:8]),
    .blue_in(sw[7:0]),
    .color_valid(1'b1),
    .strand_out(strand_out[0]),
    .next_led_request(),
    .request_valid()
);


endmodule
`default_nettype wire
