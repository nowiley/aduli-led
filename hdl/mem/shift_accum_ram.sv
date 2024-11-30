`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_1_clock_ram.v"
`include "common/synchronizer.sv"
`default_nettype none
module shift_accum_ram #(
    parameter WIDTH,
    parameter DEPTH
) (
    input wire clk_in,
    input wire rst_in,
    input wire [$clog2(DEPTH)-1:0] addr_in,
    input wire summand_in,
    input wire request_valid_in,
    output logic [WIDTH-1:0] read_out,
    output logic summand_out,
    output logic [WIDTH-1:0] sum_out,
    output logic [$clog2(DEPTH)-1:0] addr_out,
    output logic result_valid_out
);

    synchronizer #(
        .WIDTH($clog2(DEPTH)),
        .DEPTH(2)
    ) addr_sync (
        .clk_in  (clk_in),
        .rst_in  (rst_in),
        .data_in (addr_in),
        .data_out(addr_out)
    );
    synchronizer #(
        .WIDTH(1),
        .DEPTH(2)
    ) summand_sync (
        .clk_in  (clk_in),
        .rst_in  (rst_in),
        .data_in (summand_in),
        .data_out(summand_out)
    );
    synchronizer #(
        .WIDTH(1),
        .DEPTH(2)
    ) request_valid_sync (
        .clk_in  (clk_in),
        .rst_in  (rst_in),
        .data_in (request_valid_in),
        .data_out(result_valid_out)
    );

    assign sum_out = (read_out << 1) | summand_sync.data_out;

    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(WIDTH),
        .RAM_DEPTH(DEPTH),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE")  // 2 cycle reading
    ) mem (
        .clka(clk_in),  // Clock
        //reading port:
        .addra(addr_in),  // Port A address bus,
        .douta(read_out),  // Port A RAM output data, width determined from RAM_WIDTH
        // .dina(pixel_data_in),  // Port A RAM input data
        .wea(1'b0),  // Port A write enable
        //writing port:
        .addrb(addr_sync.data_out),  // Port B address bus,
        // .doutb(),  // Port B RAM output data,
        .dinb(sum_out),  // Port B RAM input data, width determined from RAM_WIDTH
        .web(result_valid_out),  // Port B write enable
        .ena(1'b1),  // Port A RAM Enable
        .enb(1'b1),  // Port B RAM Enable,
        .rsta(rst_in),  // Port A output reset
        .rstb(rst_in),  // Port B output reset
        .regcea(1'b1),  // Port A output register enable
        .regceb(1'b0)  // Port B output register enable
    );

endmodule
`default_nettype wire