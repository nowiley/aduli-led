`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "mem/xilinx_single_port_ram_read_first.v"
`include "common/synchronizer.sv"
`default_nettype none

`define FPATH(X) `"../../data/X`"

module image_sprite_pop_cat #(
    parameter WIDTH = 256,
    HEIGHT = 256,
    SHEET_COUNT = 2
) (
    input wire pixel_clk_in,
    input wire rst_in,
    input wire [10:0] x_in,
    hcount_in,
    input wire [9:0] y_in,
    vcount_in,
    input wire pop_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out
);

    localparam COLOR_ID_WIDTH = 8;
    localparam COLOR_WIDTH = 24;

    // calculate rom address
    logic [$clog2(SHEET_COUNT*WIDTH*HEIGHT)-1:0] image_addr;
    assign image_addr = (hcount_in - x_in) + ((vcount_in - y_in) * WIDTH) + (pop_in ? WIDTH*HEIGHT : 0);

    logic in_sprite;
    assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));

    logic in_sprite_ps10;
    synchronizer #(
        .DEPTH(4),
        .WIDTH(1)
    ) in_sprite_sync (
        .clk_in  (pixel_clk_in),
        .rst_in  (rst_in),
        .data_in (in_sprite),
        .data_out(in_sprite_ps10)
    );


    logic [COLOR_ID_WIDTH-1:0] pixel_color_id;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(COLOR_ID_WIDTH),
        .RAM_DEPTH(SHEET_COUNT * WIDTH * HEIGHT),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(image2.mem))
    ) image_bram (
        .addra(image_addr),  // Address bus, width determined from RAM_DEPTH
        .dina(8'b0),  // RAM input data, width determined from RAM_WIDTH
        .clka(pixel_clk_in),  // Clock
        .wea(1'b0),  // Write enable
        .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),  // Output reset (does not affect memory contents)
        .regcea(1'b1),  // Output register enable
        .douta(pixel_color_id)  // RAM output data, width determined from RAM_WIDTH
    );

    logic [COLOR_WIDTH-1:0] pixel_color;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(COLOR_WIDTH),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(palette2.mem))
    ) palette_bram (
        .addra(pixel_color_id),  // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),  // RAM input data, width determined from RAM_WIDTH
        .clka(pixel_clk_in),  // Clock
        .wea(1'b0),  // Write enable
        .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),  // Output reset (does not affect memory contents)
        .regcea(1'b1),  // Output register enable
        .douta(pixel_color)  // RAM output data, width determined from RAM_WIDTH
    );

    assign red_out   = in_sprite_ps10 ? pixel_color[23:16] : 0;
    assign green_out = in_sprite_ps10 ? pixel_color[15:8] : 0;
    assign blue_out  = in_sprite_ps10 ? pixel_color[7:0] : 0;
endmodule

`default_nettype wire
