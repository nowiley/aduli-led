`timescale 1ns / 1ps
`include "common/evt_counter.sv"
`define max2(v1, v2) ((v1) > (v2) ? (v1) : (v2))
`default_nettype none  // prevents system from inferring an undeclared logic (good practice)
// Adheres to: https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf
// 800kbps 1250ns period per bit
// Assuming 100MHz clock, 10ns period ->
// 0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
// 1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
// reset = 50us low
module led_driver #(
    parameter int CLOCK_SPEED = 100_000_000,  // 100MHz
    parameter int NUM_LEDS = 20,
    parameter int COLOR_WIDTH = 8,
    localparam int CounterWidth = $clog2(NUM_LEDS)
) (
    input wire rst_in,  // active high
    input wire clk_in,  // 100MHz
    input wire force_reset,  // active high
    input wire [COLOR_WIDTH-1:0] green_in,
    input wire [COLOR_WIDTH-1:0] red_in,
    input wire [COLOR_WIDTH-1:0] blue_in,
    input wire color_valid,  //single cycle pulse
    output logic strand_out,
    output logic [CounterWidth-1:0] next_led_request,
    output logic request_valid  // FIXME: unused
);
    logic [COLOR_WIDTH-1:0] next_red, next_green, next_blue;
    logic next_valid;

    logic [COLOR_WIDTH*3 - 1:0] bit_buffer;
    wire current_bit = bit_buffer[COLOR_WIDTH*3-1];

    // State machine
    enum logic [1:0] {
        IDLE,
        SEND,
        RESET
    } state;

    enum logic {
        HIGH,
        LOW
    } bit_state;

    // Derivative signals
    wire incr_led_counter = (
        (state == IDLE && (color_valid || next_valid))
        || (state == SEND && bit_end && last_bit && next_valid && !last_led)
    //  || (state == RESET && reset_end)  // this gets handled when leaving IDLE state
    );

    // LED counter
    wire reset_led_counter = force_reset;
    evt_counter #(
        .MAX_COUNT(NUM_LEDS)
    ) led_counter_module (
        .clk_in(clk_in),
        .rst_in(rst_in || reset_led_counter),
        .evt_in(incr_led_counter),
        .count_out(next_led_request)
    );
    wire last_led = next_led_request == 0;

    // Bit counter
    logic [$clog2(COLOR_WIDTH*3) - 1:0] bit_counter;
    evt_counter #(
        .MAX_COUNT(COLOR_WIDTH * 3)
    ) bit_counter_module (
        .clk_in(clk_in),
        .rst_in(rst_in || reset_led_counter),
        .evt_in(state == SEND && bit_end),
        .count_out(bit_counter)
    );
    wire last_bit = bit_counter == COLOR_WIDTH * 3 - 1;

    localparam int  // Signal timing per WS2812B datasheet (in ns units
    T0H = 400,  // 0.4us high
    T1H = 800,  // 0.8us high
    T0L = 850,  // 0.85us low
    T1L = 450,  // 0.45us low
    RES = 55000;  // >50us reset

    // Cycles for bit timing
    localparam int  //
    T0HCyc = T0H / 1e9 * CLOCK_SPEED,
    T1HCyc = T1H / 1e9 * CLOCK_SPEED,
    T0LCyc = T0L / 1e9 * CLOCK_SPEED,
    T1LCyc = T1L / 1e9 * CLOCK_SPEED,
    RESCyc = RES / 1e9 * CLOCK_SPEED;

    localparam int CycBitMax = `max2(T0HCyc + T0LCyc, T1HCyc + T1LCyc);
    localparam int CycMax = `max2(CycBitMax, RESCyc);
    logic [$clog2(CycMax) - 1:0] cyc_counter;

    // Bit counter
    wire counter_reset = (state == SEND && bit_end) || (state == RESET && reset_end) || reset_led_counter;  // FIXME: improve this
    evt_counter #(
        .MAX_COUNT(CycMax)
    ) cyc_counter_module (
        .clk_in(clk_in),
        .rst_in(rst_in || counter_reset),
        .evt_in(state == SEND || state == RESET),
        .count_out(cyc_counter)
    );

    // Derivative signals
    localparam int HighCycMax = `max2(T0HCyc, T1HCyc);
    wire [$clog2(HighCycMax)-1:0] bit_change_cyc = current_bit ? T1HCyc : T0HCyc;
    wire [$clog2(CycMax)-1:0] bit_end_cyc = current_bit ? T1HCyc + T1LCyc : T0HCyc + T0LCyc;

    wire bit_change = cyc_counter == bit_change_cyc - 1;
    wire bit_end = cyc_counter == bit_end_cyc - 1;
    wire reset_end = cyc_counter == RESCyc - 1;


    function static logic start_bit;
        return 1'b1;
    endfunction
    function static logic [COLOR_WIDTH*3-1:0] shift_buffer;
        return {bit_buffer[COLOR_WIDTH*3-2:0], 1'b0};
    endfunction
    function static logic [COLOR_WIDTH*3-1:0] build_buffer;
        return {next_green, next_red, next_blue};
    endfunction
    function static logic [COLOR_WIDTH*3-1:0] build_buffer_direct;
        return {green_in, red_in, blue_in};
    endfunction

    // Signal driving
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            next_valid <= 0;
            state <= IDLE;
            strand_out <= 1'b0;
        end else if (force_reset) begin
            state <= RESET;
        end else begin
            case (state)
                IDLE: begin
                    // Hang out
                    if (color_valid) begin
                        bit_buffer <= build_buffer_direct();
                        strand_out <= start_bit();
                        next_valid <= 0;
                        state <= SEND;
                    end else if (next_valid) begin
                        bit_buffer <= build_buffer();
                        strand_out <= start_bit();
                        next_valid <= 0;
                        state <= SEND;
                    end
                end
                SEND: begin
                    if (bit_end) begin
                        if (last_bit) begin
                            if (next_valid && !last_led) begin
                                bit_buffer <= build_buffer();
                                strand_out <= start_bit();
                                next_valid <= 0;
                            end else begin
                                strand_out <= 1'b0;  // should already be low but just in case
                                state <= RESET;
                            end
                        end else begin
                            bit_buffer <= shift_buffer();
                            strand_out <= start_bit();
                        end
                    end else if (color_valid) begin
                        next_red   <= red_in;
                        next_green <= green_in;
                        next_blue  <= blue_in;
                        next_valid <= 1;
                    end
                    if (bit_change) begin
                        strand_out <= 1'b0;
                    end
                end
                RESET: begin  // 50us reset
                    if (reset_end) begin
                        state <= IDLE;
                    end
                end
                default: begin
                end
            endcase
        end
    end
endmodule

`default_nettype wire
