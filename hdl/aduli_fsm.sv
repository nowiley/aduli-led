`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "calibration/calibration_step_fsm.sv"
`default_nettype none

`ifndef ADULI_FSM_DEFINES
`define ADULI_FSM_DEFINES
typedef enum logic [1:0] {
    DISPLAY = 0,
    SHOW_CALIB_LED = 1,
    RUN_CALIB_STEP = 2
} aduli_state_t;
`endif

module aduli_fsm #(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = $clog2(NUM_LEDS),
    parameter int LED_ADDR_BIT_SEL_WIDTH = $clog2(LED_ADDRESS_WIDTH)
) (
    input wire clk_in,
    input wire rst_in,

    // User interactions
    input wire start_in,

    // Module interfaction
    input wire led_display_valid_in,
    input wire calibration_step_state_t calibration_state_in,
    output logic [LED_ADDR_BIT_SEL_WIDTH-1:0] led_addr_bit_sel_out,
    output logic led_addr_bit_sel_start_out,
    output logic calibration_start_out,
    output logic calibration_first_out,

    output aduli_state_t state
);

    logic calibration_started;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= DISPLAY;
            led_addr_bit_sel_start_out <= 0;
            calibration_started <= 0;
        end else begin
            case (state)
                DISPLAY: begin
                    calibration_start_out <= 0;

                    if (start_in) begin
                        led_addr_bit_sel_out <= 0;
                        led_addr_bit_sel_start_out <= 1;
                        calibration_first_out <= 1;
                        state <= SHOW_CALIB_LED;
                    end else begin
                        led_addr_bit_sel_start_out <= 0;
                        calibration_first_out <= 0;
                    end
                end
                SHOW_CALIB_LED: begin
                    led_addr_bit_sel_start_out <= 0;
                    if (led_display_valid_in) begin
                        calibration_start_out <= 1;
                        state <= RUN_CALIB_STEP;
                    end
                end
                RUN_CALIB_STEP: begin
                    if (calibration_state_in != IDLE) begin
                        calibration_started   <= 1;
                        calibration_start_out <= 0;
                        calibration_first_out <= 0;
                    end

                    if ((calibration_state_in == IDLE) && calibration_started) begin
                        calibration_started <= 0;
                        if (led_addr_bit_sel_out + 1 == LED_ADDRESS_WIDTH) begin
                            state <= DISPLAY;
                        end else begin
                            led_addr_bit_sel_out <= led_addr_bit_sel_out + 1;
                            led_addr_bit_sel_start_out <= 1;
                            state <= SHOW_CALIB_LED;
                        end
                    end
                end
            endcase
        end
    end

endmodule
`default_nettype wire
