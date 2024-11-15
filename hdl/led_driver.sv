`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
// Adheres to: https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf
// 800kbps 1250ns period per bit
// Assuming 100MHz clock, 10ns period ->
// 0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
// 1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
// reset = 50us low
module led_driver #(
    parameter int NUM_LEDS = 20
) (
    input wire rst,  // active high
    input clk_in,  // 100MHz
    input force_reset,  // active high
    input wire [7:0] green_in,
    input wire [7:0] red_in,
    input wire [7:0] blue_in,
    input wire color_valid,  //single cycle pulse
    output logic strand_out,
    output logic [COUNTER_WIDTH:0] next_led_request,  // TODO: Convert to parametric
    output logic request_valid
);
    localparam int CounterWidth = $clog2(NUM_LEDS);





endmodule

`default_nettype wire
