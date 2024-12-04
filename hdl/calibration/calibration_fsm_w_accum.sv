`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`include "mem/shift_accum_ram.sv"
`default_nettype none

module calibration_fsm_w_accum 
#(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 10,
    parameter int NUM_FRAME_BUFFER_PIXELS = 360 * 180,
    parameter int WAIT_CYCLES = 10000000,
    parameter int ACTIVE_H_PIXELS = 320,
    parameter int ACTIVE_LINES = 180,
    localparam int WAIT_COUNTER_WIDTH = $clog2(WAIT_CYCLES)
)(
        input wire clk_pixel,
        input wire rst,
    // User interactions
        input wire increment_id,
        input wire read_request,

    // LED SHOWR INPUT
        input wire displayed_frame_valid,

    // Address, thresh, nframe inputs
        input wire [10:0] hcount_in,
        input wire [9:0] vcount_in,
        input wire new_frame_in,
        input wire detect_0,
        input wire detect_1
);

logic enum {
    IDLE,
    WAIT_FOR_LED_STRAND_VALID,
    WAIT_FOR_CAM,
    WAIT_FOR_NFRAME,
    CAPTURE_FRAME
} state;

logic old_nf;
logic old_displayed_frame_valid;
logic old_increment_id;
logic [WAIT_COUNTER_WIDTH-1:0] wait_counter;
wire active_draw = (hcount_in < ACTIVE_H_PIXELS && vcount_in < ACTIVE_LINES) && !rst;
wire top_left = ((hcount_in[1:0] == 2'b00) && (vcount_in[1:0] == 2'b00));
wire good_addrb = top_left && active_draw;
wire addrb = (319 - (hcount_in >> 2)) + 320 * (vcount_in >> 2);

always_ff @(posedge clk_pixel) begin
    if (rst) begin
        state <= IDLE;
        wait_counter <= 0;
        old_nf <= 0;
        old_displayed_frame_valid <= 0;
        old_increment_id <= 0;
    end else begin
        old_nf <= new_frame_in;
        old_displayed_frame_valid <= displayed_frame_valid;
        old_increment_id <= increment_id;

        case (state)
            IDLE: begin
                if (increment_id && ! old_increment_id) begin
                    state <= WAIT_FOR_LED_STRAND_VALID;
                end
            end
            WAIT_FOR_LED_STRAND_VALID: begin
                if (displayed_frame_valid && !old_displayed_frame_valid) begin
                    state <= WAIT_FOR_CAM;
                    wait_counter <= 0;
                end
            end
            WAIT_FOR_CAM: begin
                wait_counter <= wait_counter + 1;
                if (wait_counter == WAIT_CYCLES-1) begin
                    state <= WAIT_FOR_NFRAME;
                end
            end
            WAIT_FOR_NFRAME: begin
                if (new_frame_in) begin
                    state <= CAPTURE_FRAME;
                end
            end
            CAPTURE_FRAME: begin
                if (new_frame_in) begin
                    state <= IDLE;
                end
            end
        endcase
    end
end


wire summand_in = detect1;
wire accum_request_t request_wire = (state == CAPTURE_FRAME) ? WRITE: READ;

// Instantiat the accum thing
shift_accum_ram #(
    .WIDTH(LED_ADDRESS_WIDTH),
    .DEPTH(ACTIVE_H_PIXELS * ACTIVE_LINES)
) accum_ram (
    .clk_in(clk_pixel),
    .rst_in(rst),
    .addr_in(addrb),
    .summand_in(summand_in),
    .request_type_in(request_wire),
    .request_valid_in(read_request || (good_addrb && active_draw && state == CAPTURE_FRAME)),
    .read_out(),
    .summand_out(),
    .sum_out(),
    .addr_out(),
    .request_type_out(),
    .result_valid_out()
);


endmodule
`default_nettype wire