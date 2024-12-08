`timescale 1ns / 1ps `default_nettype none

module clock_cross #(
    parameter WIDTH = 1,
    parameter DEPTH_DST = 3
) (
    input wire rst_in,
    input wire clk_src_in,
    input wire clk_dst_in,
    input wire [WIDTH-1:0] data_src_in,
    output logic [WIDTH-1:0] data_dst_out
);

    logic [WIDTH-1:0] data_dst_stages[DEPTH_DST-1:0];

    always_ff @(posedge clk_dst_in) begin
        if (rst_in) begin
            for (int i = 0; i < DEPTH_DST; i++) begin
                data_dst_stages[i] <= '0;
            end
        end else begin
            data_dst_stages[0] <= data_src_in;
            for (int i = 1; i < DEPTH_DST; i++) begin
                data_dst_stages[i] <= data_dst_stages[i-1];
            end
        end
    end

    assign data_dst_out = data_dst_stages[DEPTH_DST-1];

endmodule

`default_nettype wire
