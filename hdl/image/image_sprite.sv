`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "mem/xilinx_single_port_ram_read_first.v"
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite #(
    parameter WIDTH = 256,
    HEIGHT = 256
) (
    input wire pixel_clk_in,
    input wire rst_in,
    input wire [10:0] x_in,
    hcount_in,
    input wire [9:0] y_in,
    vcount_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out
);

  localparam COLOR_ID_WIDTH = 8;
  localparam COLOR_WIDTH = 24;

  // calculate rom address
  logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
  assign image_addr = (hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);

  logic in_sprite;
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));


  logic [COLOR_ID_WIDTH-1:0] pixel_color_id;

  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(COLOR_ID_WIDTH),
      .RAM_DEPTH(WIDTH * HEIGHT),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
      .INIT_FILE(`FPATH(image.mem))
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
      .INIT_FILE(`FPATH(palette.mem))
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

  assign red_out   = in_sprite ? pixel_color[23:16] : 0;
  assign green_out = in_sprite ? pixel_color[15:8] : 0;
  assign blue_out  = in_sprite ? pixel_color[7:0] : 0;
endmodule

`default_nettype wire
