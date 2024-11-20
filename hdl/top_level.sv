`timescale 1ns / 1ps
`include "driver/led_driver.sv"
`default_nettype none

module top_level (
    input wire clk_100mhz,
    output logic [15:0] led,  // green leds
    input wire [3:0] btn,  // push buttons
    input wire [15:0] sw,  // switches
    output logic [3:0] strand_out  // strand output wire PMODA
);

    // instantiate led_driver module
    led_driver #(
        .NUM_LEDS(2)
    ) led_driver_inst (
        .rst_in(btn[0]),
        .clk_in(clk_100mhz),
        .force_reset(btn[1]),
        .green_in({2'b0, sw[15:10]}),
        .red_in({3'b0, sw[9:5]}),
        .blue_in({3'b0, sw[4:0]}),
        .color_valid(1'b1),
        .strand_out(strand_out[0]),
        .next_led_request(),
        .request_valid()
    );


endmodule
`default_nettype wire
