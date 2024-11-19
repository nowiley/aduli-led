`timescale 1ns / 1ps
`default_nettype none  // prevents system from inferring an undeclared logic (good practice)
module pat_gradient #(
    parameter int NUM_LEDS = 20,
    parameter int COLOR_WIDTH = 8,
    localparam int CounterWidth = $clog2(NUM_LEDS)
) (
    input wire rst_in,
    input wire clk_in,
    input wire [CounterWidth-1:0] next_led_request,
    output logic [COLOR_WIDTH-1:0] red_out,
    output logic [COLOR_WIDTH-1:0] green_out,
    output logic [COLOR_WIDTH-1:0] blue_out,
    output logic color_valid
);

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            red_out <= 0;
            green_out <= 0;
            blue_out <= 0;
            color_valid <= 0;
        end else begin
            red_out <= (next_led_request << 2);
            green_out <= 0;
            blue_out <= (1 << COLOR_WIDTH) - 1 - (next_led_request << 2);
            color_valid <= 1;
        end
    end

endmodule
`default_nettype wire
