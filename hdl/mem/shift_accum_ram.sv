`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_1_clock_ram.v"
`include "common/synchronizer.sv"
`default_nettype none

typedef enum logic [1:0] {
    READ = 0,
    WRITE = 1,
    WRITE_OVER = 2,
    DISABLE = 3
} accum_request_t;

module shift_accum_ram #(
    parameter WIDTH,
    parameter DEPTH
) (
    input wire clk_in,
    input wire rst_in,
    input wire [$clog2(DEPTH)-1:0] addr_in,
    input wire summand_in,
    input wire accum_request_t request_type_in,
    input wire request_valid_in,
    output logic [WIDTH-1:0] read_out,
    output logic summand_out,
    output logic [WIDTH-1:0] sum_out,
    output logic [$clog2(DEPTH)-1:0] addr_out,
    output accum_request_t request_type_out,
    output logic result_valid_out
);
    parameter DISABLED_VAL = {WIDTH{1'b1}};

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
        .WIDTH($bits(accum_request_t)),
        .DEPTH(2)
    ) request_type_sync (
        .clk_in  (clk_in),
        .rst_in  (rst_in),
        .data_in (request_type_in),
        .data_out(request_type_out)
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

    always_comb begin
        if (request_type_out == WRITE_OVER) begin
            sum_out = summand_sync.data_out;
        end else if ((request_type_out == DISABLE) || (read_out == DISABLED_VAL)) begin
            sum_out = DISABLED_VAL;  // maintain disable lockout
        end else begin
            sum_out = (read_out << 1) | summand_sync.data_out;
        end
    end

    wire is_write = (request_type_out == WRITE) || (request_type_out == WRITE_OVER) || (request_type_out == DISABLE);

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
        .web(result_valid_out && is_write),  // Port B write enable
        .ena(1'b1),  // Port A RAM Enable
        .enb(1'b1),  // Port B RAM Enable,
        .rsta(rst_in),  // Port A output reset
        .rstb(rst_in),  // Port B output reset
        .regcea(1'b1),  // Port A output register enable
        .regceb(1'b0)  // Port B output register enable
    );

endmodule
`default_nettype wire
