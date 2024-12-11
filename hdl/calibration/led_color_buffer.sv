`timescale 1ns / 1ps
`include "mem/xilinx_true_dual_port_read_first_2_clock_ram.v"
`include "calibration/id_shower.sv"
`include "common/synchronizer.sv"
`default_nettype none

module led_color_buffer
#(
    parameter int NUM_LEDS = 50,
    parameter int LED_ADDRESS_WIDTH = $clog2(NUM_LEDS),
    parameter int FBUF_COLOR_WIDTH = 24
)(  
    input wire rst,
    input wire wipe,
    // For requests from the calibration_fsm_accum_lookup table
    // Clocked off of HDMI pixel clock
        input wire clk_pixel,
        input wire [LED_ADDRESS_WIDTH-1:0] led_lookup_address,
        input wire [FBUF_COLOR_WIDTH-1:0] camera_color,
        input wire led_color_buffer_update_enable,
    
    // For requests from led driver
    // Clocked off of LED driver clock
        input wire clk_led,
        input wire [LED_ADDRESS_WIDTH-1:0] next_led_request_address,
        output logic [7:0] green_out,
        output logic [7:0] red_out,
        output logic [7:0] blue_out,
        output logic [FBUF_COLOR_WIDTH-1:0] data_out,
        output logic color_valid,
        output logic wiping
);

logic [LED_ADDRESS_WIDTH-1:0] address_counter;
logic last_wipe;
always_ff @(posedge clk_pixel) begin
    last_wipe <= wipe;
    if (rst) begin
        address_counter <= 0;
        wiping <= 0;
    end else if (wipe && !last_wipe) begin
        wiping <= 1;
        address_counter <= 0;
    end else if (wiping) begin
        if (address_counter == NUM_LEDS-1) begin
            address_counter <= 0;
            wiping <= 0;
        end else begin
            address_counter <= address_counter + 1;
        end
    end
end


logic write_to_buffer;
assign write_to_buffer = ((led_color_buffer_update_enable) && (led_lookup_address < NUM_LEDS) && !wiping);
wire [23:0] write_value = write_to_buffer ? camera_color : 0;
wire [LED_ADDRESS_WIDTH-1:0] writing_address = wiping ? address_counter : led_lookup_address;

xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(FBUF_COLOR_WIDTH),
    .RAM_DEPTH(NUM_LEDS)
) led_color_ram (
    // INPUT FROM CAMERA
    .clka(clk_pixel),                       // Port A clock
    .addra(writing_address),             // Port A address bus, width determined from RAM_DEPTH
    .dina(write_value),                    // Port A RAM input data
    .wea(1'b1),                  // Port A write enable
    .ena(1'b1),                             // Port A RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),                             // Port A output reset (does not affect memory contents)
    .douta(),                               // Port A RAM output data
    .regcea(1'b1),                          // Port A output register enable
    // OUTPUT TO LED DRIVER
    .clkb(clk_led),                         // Port B clock
    .addrb(next_led_request_address),       // Port B address bus, width determined from RAM_DEPTH
    .web(1'b0),                             // Port B write enable
    .enb(1'b1),                             // Port B RAM Enable, for additional power savings, disable port when not in use
    .rstb(rst),                             // Port B output reset (does not affect memory contents)
    .doutb(data_out),                       // Port B RAM output data
    .regceb(1'b1)                          // Port B output register enable
);


// LED DRIVER LOGIC
assign red_out = {4'b0, data_out[23:20]};
assign green_out = {4'b0, data_out[15:12]};
assign blue_out = {4'b0, data_out[7:4]};

logic [LED_ADDRESS_WIDTH-1:0] last_led_request_address;
logic [LED_ADDRESS_WIDTH-1:0] last_last_led_request_address;

always_ff @(posedge clk_led) begin
    if (rst) begin
        last_led_request_address <= next_led_request_address;
        last_last_led_request_address <= 0;
    end else begin
        last_last_led_request_address <= last_led_request_address;
        last_led_request_address <= next_led_request_address;
        // Color is valid if current request is the same as the request the last 2 cycles
        color_valid <= ((next_led_request_address == last_last_led_request_address) && (last_led_request_address == next_led_request_address));
    end
end

endmodule 


`default_nettype wire