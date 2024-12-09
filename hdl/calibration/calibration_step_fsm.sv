`timescale 1ns / 1ps
`include "mem/shift_accum_ram.sv"
`default_nettype none

typedef enum logic [2:0] {
    IDLE = 0,
    WAIT_FOR_LED_STRAND_VALID = 1,
    WAIT_FOR_CAM = 2,
    WAIT_FOR_NFRAME = 3,
    CAPTURE_FRAME = 4
} calibration_step_state_t;

module calibration_step_fsm #(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = 10,
    parameter int WAIT_CYCLES = 10000000,
    parameter int ACTIVE_H_PIXELS = 1280,
    parameter int ACTIVE_LINES = 720,
    localparam int downsample_shift = 2,
    localparam int NUM_FRAME_BUFFER_PIXELS = (ACTIVE_H_PIXELS>>downsample_shift) * (ACTIVE_LINES>>downsample_shift),
    localparam int WAIT_COUNTER_WIDTH = $clog2(WAIT_CYCLES),
    localparam int ADDRB_DEPTH_WIDTH = $clog2(NUM_FRAME_BUFFER_PIXELS)
) (
    input wire clk_pixel,
    input wire rst,
    // User interactions
    input wire increment_id,
    input wire read_request,
    input wire should_overwrite,

    // LED SHOWR INPUT
    input wire displayed_frame_valid,

    // Address, thresh, nframe inputs
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    input wire new_frame_in,
    input wire detect_0,
    input wire detect_1,
    output calibration_step_state_t state,
    output logic [LED_ADDRESS_WIDTH-1:0] read_out

);


    logic old_nf;
    logic old_increment_id;
    logic [WAIT_COUNTER_WIDTH-1:0] wait_counter;
    wire active_draw = ((hcount_in < ACTIVE_H_PIXELS) && (vcount_in < ACTIVE_LINES)) && !rst;
    wire top_left = ((hcount_in[1:0] == 2'b00) && (vcount_in[1:0] == 2'b00));
    wire good_addrb = top_left && active_draw;
    wire [ADDRB_DEPTH_WIDTH-1:0] addrb = (hcount_in >> downsample_shift) + (ACTIVE_H_PIXELS>>downsample_shift) * (vcount_in >> 2);

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            state <= IDLE;
            wait_counter <= 0;
            old_nf <= 0;
            old_increment_id <= 0;
        end else begin
            old_nf <= new_frame_in;
            old_increment_id <= increment_id;

            case (state)
                IDLE: begin
                    if (increment_id && !old_increment_id) begin
                        state <= WAIT_FOR_LED_STRAND_VALID;
                    end
                end
                WAIT_FOR_LED_STRAND_VALID: begin
                    if (displayed_frame_valid) begin
                        state <= WAIT_FOR_CAM;
                        wait_counter <= 0;
                    end
                end
                WAIT_FOR_CAM: begin
                    wait_counter <= wait_counter + 1;
                    if (wait_counter == WAIT_CYCLES - 1) begin
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


    wire summand_in = detect_1;
    accum_request_t request_wire;
    wire request_valid_in = read_request || (good_addrb && active_draw && (state == CAPTURE_FRAME));
    wire [ADDRB_DEPTH_WIDTH-1:0] addr_out_wire;

    always_comb begin  // https://github.com/steveicarus/iverilog/issues/1015
        if ((state == CAPTURE_FRAME) && good_addrb) begin
            if (!(detect_0 ^ detect_1)) begin  // conflict
                request_wire = DISABLE;
            end else if (should_overwrite) begin
                request_wire = WRITE_OVER;
            end else begin
                request_wire = WRITE;
            end
        end else begin
            request_wire = READ;
        end
    end

    // Instantiat the accum thing
    shift_accum_ram #(
        .WIDTH(LED_ADDRESS_WIDTH),
        .DEPTH(NUM_FRAME_BUFFER_PIXELS)
    ) accum_ram (
        .clk_in(clk_pixel),
        .rst_in(rst),
        .addr_in(addrb),
        .summand_in(summand_in),
        .request_type_in(request_wire),
        .request_valid_in(request_valid_in),
        .read_out(read_out),
        .summand_out(),
        .sum_out(),
        .addr_out(addr_out_wire),
        .request_type_out(),
        .result_valid_out()
    );


endmodule
`default_nettype wire
