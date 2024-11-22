`timescale 1ns / 1ps
`include "driver/led_driver.sv"
`include "pattern/pat_gradient.sv"
`default_nettype none

module top_level #(
    parameter int NUM_LEDS = 2,
    parameter int COLOR_WIDTH = 8,
    localparam int CounterWidth = $clog2(NUM_LEDS)
) (
    // SHARED
    input wire clk_100mhz,
    input wire [3:0] btn,  // push buttons
    input wire [15:0] sw,  // switches
    output logic [15:0] led,  // green leds
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1,

    // LED 
    output logic [3:0] strand_out  // strand output wire PMODA

    // CAMERA BUS
    input wire [7:0]    camera_d, // 8 parallel data wires
    output logic        cam_xclk, // XC driving camera
    input wire          cam_hsync, // camera hsync wire
    input wire          cam_vsync, // camera vsync wire
    input wire          cam_pclk, // camera pixel clock
    inout wire          i2c_scl, // i2c inout clock
    inout wire          i2c_sda, // i2c inout data

    //HDMI PORT
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);

    wire rst_in = btn[0];


    logic [COLOR_WIDTH-1:0] next_red, next_green, next_blue;
    logic color_valid;
    logic [CounterWidth-1:0] next_led_request;

    // instantiate pattern modules
    pat_gradient #(
        .NUM_LEDS(NUM_LEDS),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) pat_gradient_inst (
        .rst_in(rst_in),
        .clk_in(clk_100mhz),
        .next_led_request(next_led_request),
        .red_out(next_red),
        .green_out(next_green),
        .blue_out(next_blue),
        .color_valid(color_valid)
    );

    // instantiate led_driver module
    led_driver #(
        .NUM_LEDS(NUM_LEDS),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) led_driver_inst (
        .rst_in(rst_in),
        .clk_in(clk_100mhz),
        .force_reset(btn[1]),
        .green_in(next_green),
        .red_in(next_red),
        .blue_in(next_blue),
        .color_valid(color_valid),
        .strand_out(strand_out[0]),
        .next_led_request(next_led_request)
    );


endmodule
`default_nettype wire
