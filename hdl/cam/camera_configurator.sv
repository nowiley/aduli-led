`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "mem/xilinx_single_port_ram_read_first.v"
`include "cam/camera_registers.sv"
`default_nettype none

module camera_configurator #(
    localparam RAMWidth = 24,
    localparam RAMAddrWidth = 8
) (
    input  wire clk_camera,
    input  wire sys_rst_camera,
    input  wire cr_init_valid,
    output wire cr_init_ready,
    output wire bus_active,
    inout  wire i2c_scl,
    inout  wire i2c_sda
    // ...
);

    logic [23:0] bram_dout;
    logic [ 7:0] bram_addr;

    // ROM holding pre-built camera settings to send
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("../../data/camera_orig_720.mem")
    ) registers (
        .addra(bram_addr),  // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),  // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),  // Clock
        .wea(1'b0),  // Write enable
        .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera),  // Output reset (does not affect memory contents)
        .regcea(1'b1),  // Output register enable
        .douta(bram_dout)  // RAM output data, width determined from RAM_WIDTH
    );

    logic [23:0] registers_dout;
    logic [ 7:0] registers_addr;
    assign registers_dout = bram_dout;
    assign bram_addr = registers_addr;

    logic con_scl_i, con_scl_o, con_scl_t;
    logic con_sda_i, con_sda_o, con_sda_t;

    // NOTE these also have pullup specified in the xdc file!
    // access our inouts properly as tri-state pins
`ifndef LINTING  // iverilog linting has no idea what these are
    IOBUF IOBUF_scl (
        .I (con_scl_o),
        .IO(i2c_scl),
        .O (con_scl_i),
        .T (con_scl_t)
    );
    IOBUF IOBUF_sda (
        .I (con_sda_o),
        .IO(i2c_sda),
        .O (con_sda_i),
        .T (con_sda_t)
    );
`endif

    // provided module to send data BRAM -> I2C
    camera_registers crw (
        .clk_in(clk_camera),
        .rst_in(sys_rst_camera),
        .init_valid(cr_init_valid),
        .init_ready(cr_init_ready),
        .scl_i(con_scl_i),
        .scl_o(con_scl_o),
        .scl_t(con_scl_t),
        .sda_i(con_sda_i),
        .sda_o(con_sda_o),
        .sda_t(con_sda_t),
        .bram_dout(registers_dout),
        .bram_addr(registers_addr)
    );

    assign bus_active = crw.bus_active;

endmodule

`default_nettype wire
