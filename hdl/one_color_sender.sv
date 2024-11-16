`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module one_color_sender (
    input wire rst,  // active high
    input wire clk_100mhz,
    input wire next_led_request[10:0],
    output logic [7:0] green_out,
    output logic [7:0] red_out,
    output logic [7:0] blue_out,
    output logic color_valid
);


endmodule

`default_nettype wire