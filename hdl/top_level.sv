`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "driver/led_driver.sv"
`include "pattern/pat_gradient.sv"
`include "calibration/id_shower.sv"
`include "clk/cw_hdmi_clk_wiz.v"
`include "clk/cw_fast_clk_wiz.v"
`include "cam/camera_reader.sv"
`include "pixel/channel_select.sv"
`include "pixel/threshold.sv"
`include "driver/lab05_ssc.sv"
`include "pixel/center_of_mass.sv"
`include "hdmi/video_sig_gen.sv"
`include "pixel/video_mux.sv"
`include "image/image_sprite_pop_cat.sv"
`include "common/synchronizer.sv"
`include "common/clock_cross.sv"
`include "hdmi/hdmi_driver.sv"
`include "cam/camera_configurator.sv"
`include "calibration/calibration_fsm_w_accum.sv"
`default_nettype none

module top_level #(
    parameter int NUM_LEDS = 30,
    parameter int COLOR_WIDTH = 8,
    localparam int CounterWidth = $clog2(NUM_LEDS)
) (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus
    input  wire  [ 7:0] camera_d,    // 8 parallel data wires
    output logic        cam_xclk,    // XC driving camera
    input  wire         cam_hsync,   // camera hsync wire
    input  wire         cam_vsync,   // camera vsync wire
    input  wire         cam_pclk,    // camera pixel clock
    inout  wire         i2c_scl,     // i2c inout clock
    inout  wire         i2c_sda,     // i2c inout data
    input  wire  [15:0] sw,
    input  wire  [ 3:0] btn,
    output logic [ 2:0] rgb0,
    output logic [ 2:0] rgb1,
    // seven segment
    output logic [ 3:0] ss0_an,      //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,      //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,       //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c,       //cathod controls for the segments of lower four digits
    // hdmi port
    output logic [ 2:0] hdmi_tx_p,   //hdmi output signals (positives) (blue, green, red)
    output logic [ 2:0] hdmi_tx_n,   //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p,
    hdmi_clk_n,  //differential hdmi clock
    output logic [ 3:0] strand_out   // strand output wire PMODA
);

    logic [COLOR_WIDTH-1:0] next_red, next_green, next_blue;
    logic color_valid;
    logic [CounterWidth-1:0] next_led_request;
    logic clean_btn1;
    logic clean_btn2;

    // debouncer for button 1
    debouncer #(
        .CLK_PERIOD_NS(10),
        .DEBOUNCE_TIME_MS(5)
    ) debouncer_btn1 (
        .clk_in(clk_100_passthrough),
        .rst_in(btn[0]),
        .dirty_in(btn[1]),
        .clean_out(clean_btn1)
    );
    debouncer #(
        .CLK_PERIOD_NS(10),
        .DEBOUNCE_TIME_MS(5)
    ) debouncer_btn2 (
        .clk_in(clk_100_passthrough),
        .rst_in(btn[0]),
        .dirty_in(btn[2]),
        .clean_out(clean_btn2)
    );

    logic [$clog2($clog2(NUM_LEDS))-1:0] address_bit_num;
    //instantiate id shower module
    id_shower #(
        .NUM_LEDS(NUM_LEDS),
        .LED_ADDRESS_WIDTH(CounterWidth)
    ) id_shower_inst (
        .clk(clk_100_passthrough),
        .rst(btn[0]),
        .increment_bit(clean_btn1),
        .decrement_bit(clean_btn2),
        .next_led_request(next_led_request),
        .green_out(next_green),
        .red_out(next_red),
        .blue_out(next_blue),
        .color_valid(color_valid),
        // .displayed_frame_valid(),
        .address_bit_num(address_bit_num)
    );

    clock_cross led_frame_valid_cc (
        .rst_in(sys_rst_pixel),
        .clk_src_in(clk_100_passthrough),
        .clk_dst_in(clk_pixel),
        .data_src_in(id_shower_inst.displayed_frame_valid)
        // .data_dst_out()
    );
    clock_cross increment_id (
        .rst_in(sys_rst_pixel),
        .clk_src_in(clk_100_passthrough),
        .clk_dst_in(clk_pixel),
        .data_src_in(clean_btn1)
    );

    logic [CounterWidth-1:0] pixel_led_id;
    calibration_fsm_w_accum #(
        .NUM_LEDS(NUM_LEDS),
        .LED_ADDRESS_WIDTH(CounterWidth),
        .WAIT_CYCLES(10000000),
        .ACTIVE_H_PIXELS(1280),
        .ACTIVE_LINES(720)
    ) fsm (
        .clk_pixel(clk_pixel),
        .rst(sys_rst_pixel),
        .increment_id(increment_id.data_dst_out),
        .read_request(active_draw_hdmi_ps3),
        .displayed_frame_valid(led_frame_valid_cc.data_dst_out),
        .hcount_in(hcount_hdmi_ps3),  // synchronized to detect / threshold outputs
        .vcount_in(vcount_hdmi_ps3),  // synchronized to detect / threshold outputs
        .new_frame_in(nf_hdmi_ps3),
        .detect_0(detect0),
        .detect_1(detect1),
        // .state(),
        .read_out(pixel_led_id)
    );

    // instantiate pattern modules
    // pat_gradient #(
    //     .NUM_LEDS(NUM_LEDS),
    //     .COLOR_WIDTH(COLOR_WIDTH)
    // ) pat_gradient_inst (
    //     .rst_in(sys_rst_led),
    //     .clk_in(clk_100_passthrough),
    //     .next_led_request(next_led_request),
    //     .red_out(next_red),
    //     .green_out(next_green),
    //     .blue_out(next_blue),
    //     .color_valid(color_valid)
    // );


    // instantiate led_driver module
    led_driver #(
        .NUM_LEDS(NUM_LEDS),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) led_driver_inst (
        .rst_in(sys_rst_led),
        .clk_in(clk_100_passthrough),
        .force_reset(btn[0]),
        .green_in(next_green),
        .red_in(next_red),
        .blue_in(next_blue),
        .color_valid(color_valid),
        .strand_out(strand_out[0]),
        .next_led_request(next_led_request)
    );


    // shut up those RGBs
    assign rgb0 = 0;
    assign rgb1 = 0;

    // Clock and Reset Signals
    logic sys_rst_camera;
    logic sys_rst_pixel;
    logic sys_rst_led;

    logic clk_camera;
    logic clk_pixel;
    logic clk_5x;
    logic clk_xc;

    logic clk_100_passthrough;

    // clocking wizards to generate the clock speeds we need for our different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
    cw_hdmi_clk_wiz wizard_hdmi (
        .sysclk(clk_100_passthrough),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0)
    );

    cw_fast_clk_wiz wizard_migcam (
        .clk_in1(clk_100mhz),
        .clk_camera(clk_camera),
        .clk_xc(clk_xc),
        .clk_100(clk_100_passthrough),
        .reset(0)
    );

    // assign camera's xclk to pmod port: drive the operating clock of the camera!
    // this port also is specifically set to high drive by the XDC file.
    assign cam_xclk = clk_xc;

    assign sys_rst_camera = btn[0];  //use for resetting camera side of logic
    assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
    assign sys_rst_led = btn[0];  //use for resetting led side of logic


    // video signal generator signals
    logic        hsync_hdmi;
    logic        vsync_hdmi;
    logic [10:0] hcount_hdmi;
    logic [ 9:0] vcount_hdmi;
    logic        active_draw_hdmi;
    logic        new_frame_hdmi;
    logic [ 5:0] frame_count_hdmi;
    logic        nf_hdmi;

    // rgb output values
    logic [7:0] red, green, blue;

    // ** Handling input from the camera **

    localparam FB_DEPTH = 320 * 180;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addrb;  //used to lookup address in memory for reading from buffer
    logic good_addrb;  //used to indicate within valid frame for scaling

    //TO DO in camera part 1:
    // Scale pixel coordinates from HDMI to the frame buffer to grab the right pixel
    //scaling logic!!! You need to complete!!! We want 1X, 2X, and 4X!
    always_ff @(posedge clk_pixel) begin
        int out_shift;
        //use structure below to do scaling
        if (1'b0) begin  //1X scaling from frame buffer
            out_shift = 0;
        end else begin  //4X scaling from frame buffer
            out_shift = 2;
        end

        addrb <= (319 - (hcount_hdmi >> out_shift)) + 320 * (vcount_hdmi >> out_shift);
        good_addrb <= (hcount_hdmi < (320 << out_shift)) && (vcount_hdmi < (180 << out_shift));
    end


    //channel select module (select which of six color channels to mask):
    logic [2:0] channel_sel;
    logic [7:0] selected_channel;  //FIXME: unused - selected channels
    //selected_channel could contain any of the six color channels depend on selection

    //threshold module (apply masking threshold):
    logic [7:0] lower_threshold;
    logic [7:0] upper_threshold;
    logic detect0;  //Whether or not thresholded pixel is detected as bit 0
    logic detect1;  //Whether or not thresholded pixel is detected as bit 1

    //Center of Mass variables (tally all mask=1 pixels for a frame and calculate their center of mass)
    logic [10:0] x_com, x_com_calc;  //long term x_com and output from module, resp
    logic [9:0] y_com, y_com_calc;  //long term y_com and output from module, resp
    logic new_com;  //used to know when to update x_com and y_com ...

    logic [7:0] fb_red, fb_green, fb_blue;
    logic [7:0] y, cr, cb;  //ycrcb conversion of full pixel
    camera_reader cam_m (
        .clk_camera(clk_camera),
        .clk_pixel(clk_pixel),
        .sys_rst_camera(sys_rst_camera),
        .sys_rst_pixel(sys_rst_pixel),
        .camera_d(camera_d),
        .cam_pclk(cam_pclk),
        .cam_hsync(cam_hsync),
        .cam_vsync(cam_vsync),
        .addrb(addrb),
        .good_addrb(good_addrb),
        .red(fb_red),
        .green(fb_green),
        .blue(fb_blue),
        .y(y),
        .cr(cr),
        .cb(cb)
    );

    // * 3'b000: green
    // * 3'b001: red
    // * 3'b010: blue
    // * 3'b011: not valid
    // * 3'b100: y (luminance)
    // * 3'b101: Cr (Chroma Red)
    // * 3'b110: Cb (Chroma Blue)
    // * 3'b111: not valid
    //Channel Select: Takes in the full RGB and YCrCb information and
    // chooses one of them to output as an 8 bit value
    // channel_select mcs (
    //     .sel_in(3'b001),
    //     .r_in(fb_red),
    //     .g_in(fb_green),
    //     .b_in(fb_blue),
    //     .y_in(y),
    //     .cr_in(cr),
    //     .cb_in(cb),
    //     .channel_out(selected_channel)
    // );

    //threshold values used to determine what value  passes:
    assign lower_threshold = {sw[15:12], 4'b0};
    assign upper_threshold = 8'hFF;
    wire [7:0] exposure = {sw[7], sw[7], sw[6:2], 1'b0};
    wire [3:0] sel_led = sw[11:8];

    //Thresholder: Takes in the full selected channedl and
    //based on upper and lower bounds provides a binary mask bit
    // * 1 if selected channel is within the bounds (inclusive)
    // * 0 if selected channel is not within the bounds
    threshold mt_blue (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .pixel_in(fb_blue),
        .lower_bound_in(lower_threshold),
        .upper_bound_in(upper_threshold),
        .mask_out(detect1)  //single bit if pixel within mask.
    );
    threshold mt_red (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .pixel_in(fb_red),
        .lower_bound_in(lower_threshold),
        .upper_bound_in(upper_threshold),
        .mask_out(detect0)  //single bit if pixel within mask.
    );


    logic [6:0] ss_c;
    //modified version of seven segment display for showing
    // thresholds and selected channel
    // special customized version
    lab05_ssc mssc (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .lt_in(lower_threshold),
        .ut_in(upper_threshold),
        .val3_in(exposure),
        .step_in(address_bit_num),
        .sel_led_in(sel_led),
        .cat_out(ss_c),
        .an_out({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c;  //control upper four digit's cathodes!
    assign ss1_c = ss_c;  //same as above but for lower four digits!

    logic [10:0] hcount_hdmi_ps3;
    logic [ 9:0] vcount_hdmi_ps3;
    logic        hsync_hdmi_ps3;
    logic        vsync_hdmi_ps3;
    logic        active_draw_hdmi_ps3;
    logic        nf_hdmi_ps3;

    logic [10:0] hcount_hdmi_ps7;
    logic [ 9:0] vcount_hdmi_ps7;
    logic        hsync_hdmi_ps7;
    logic        vsync_hdmi_ps7;
    logic        active_draw_hdmi_ps7;
    logic        nf_hdmi_ps7;

    localparam SigGenPackedWidth = 11 + 10 + 1 + 1 + 1 + 1;
    synchronizer #(
        .DEPTH(8),
        .WIDTH(SigGenPackedWidth)
    ) sync_hdmi_ps3 (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in({hcount_hdmi, vcount_hdmi, hsync_hdmi, vsync_hdmi, active_draw_hdmi, nf_hdmi}),
        .data_out({
            hcount_hdmi_ps3,
            vcount_hdmi_ps3,
            hsync_hdmi_ps3,
            vsync_hdmi_ps3,
            active_draw_hdmi_ps3,
            nf_hdmi_ps3
        })
    );
    synchronizer #(
        .DEPTH(2),
        .WIDTH(SigGenPackedWidth)
    ) sync_hdmi_ps7 (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in({
            hcount_hdmi_ps3,
            vcount_hdmi_ps3,
            hsync_hdmi_ps3,
            vsync_hdmi_ps3,
            active_draw_hdmi_ps3,
            nf_hdmi_ps3
        }),
        .data_out({
            hcount_hdmi_ps7,
            vcount_hdmi_ps7,
            hsync_hdmi_ps7,
            vsync_hdmi_ps7,
            active_draw_hdmi_ps7,
            nf_hdmi_ps7
        })
    );


    //Center of Mass Calculation: (you need to do)
    //using x_com_calc and y_com_calc values
    //Center of Mass:
    center_of_mass com_m (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .x_in(hcount_hdmi_ps3),  //DONE: needs to use pipelined signal! (PS3)
        .y_in(vcount_hdmi_ps3),  //DONE: needs to use pipelined signal! (PS3)
        .valid_in(detect1),  //aka threshold
        .tabulate_in((nf_hdmi_ps3)),
        .x_out(x_com_calc),
        .y_out(y_com_calc),
        .valid_out(new_com)
    );
    //grab logic for above
    //update center of mass x_com, y_com based on new_com signal
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            x_com <= 0;
            y_com <= 0;
        end
        if (new_com) begin
            x_com <= x_com_calc;
            y_com <= y_com_calc;
        end
    end

    //image_sprite output:
    logic [7:0] img_red, img_green, img_blue;

    // TODO: image sprite using hdmi hcount/vcount, x_com y_com to draw image or nothing
    //bring in an instance of your popcat image sprite! remember the correct mem files too!
    wire [10:0] x_sprite = x_com >= 128 ? (x_com - 128) : 0;
    wire [ 9:0] y_sprite = y_com >= 128 ? (y_com - 128) : 0;

    image_sprite_pop_cat pop_cat_m (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .x_in((x_sprite + 256) < 1280 - 1 ? x_sprite : 1280 - 256 - 1),
        .hcount_in(hcount_hdmi),
        .y_in((y_sprite + 256) < 720 - 1 ? y_sprite : 720 - 256 - 1),
        .vcount_in(vcount_hdmi),
        .pop_in(1'b0),  // standard pop cat
        .red_out(img_red),
        .green_out(img_green),
        .blue_out(img_blue)
    );


    //crosshair output:
    logic [7:0] ch_red, ch_green, ch_blue;

    //Create Crosshair patter on center of mass:
    //0 cycle latency
    //DONE: Should be using output of (PS3) - no, not in the reduced one
    always_comb begin
        ch_red   = ((vcount_hdmi == y_com) || (hcount_hdmi == x_com)) ? 8'hFF : 8'h00;
        ch_green = ((vcount_hdmi == y_com) || (hcount_hdmi == x_com)) ? 8'hFF : 8'h00;
        ch_blue  = ((vcount_hdmi == y_com) || (hcount_hdmi == x_com)) ? 8'hFF : 8'h00;
    end


    // HDMI video signal generator
    video_sig_gen vsg (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .hcount_out(hcount_hdmi),
        .vcount_out(vcount_hdmi),
        .vs_out(vsync_hdmi),
        .hs_out(hsync_hdmi),
        .nf_out(nf_hdmi),
        .ad_out(active_draw_hdmi),
        .fc_out(frame_count_hdmi)
    );


    // Video Mux: select from the different display modes based on switch values
    //used with switches for display selections
    wire [1:0] display_choice = {sw[0], 1'b0};
    wire [1:0] target_choice = sw[1] ? 2'b11 : 2'b00;

    //choose what to display from the camera:
    // * 'b00:  normal camera out
    // * 'b01:  selected channel image in grayscale
    // * 'b10:  masked pixel (all on if 1, all off if 0)
    // * 'b11:  chroma channel with mask overtop as magenta
    //
    //then choose what to use with center of mass:
    // * 'b00: nothing
    // * 'b01: crosshair
    // * 'b10: sprite on top
    // * 'b11: nothing

    logic [7:0] fb_red_ps2, fb_green_ps2, fb_blue_ps2;
    synchronizer #(
        .DEPTH(3),
        .WIDTH(3 * 8)
    ) sync_fb_ps2 (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in ({fb_red, fb_green, fb_blue}),
        .data_out({fb_red_ps2, fb_green_ps2, fb_blue_ps2})
    );

    logic detect0_ps4, detect1_ps4;
    synchronizer #(
        .DEPTH(2),
        .WIDTH(2)
    ) sync_detect_ps4 (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in ({detect0, detect1}),
        .data_out({detect0_ps4, detect1_ps4})
    );


    logic [7:0] selected_channel_ps5;
    synchronizer #(
        .DEPTH(3),
        .WIDTH(8)
    ) sync_selected_channel (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in (selected_channel),
        .data_out(selected_channel_ps5)
    );

    logic [7:0] y_ps6;
    synchronizer #(
        .DEPTH(3),
        .WIDTH(8)
    ) sync_y (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in (y),
        .data_out(y_ps6)
    );

    logic [7:0] ch_red_ps8, ch_green_ps8, ch_blue_ps8;
    synchronizer #(
        .DEPTH(10),
        .WIDTH(3 * 8)
    ) sync_ch (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in ({ch_red, ch_green, ch_blue}),
        .data_out({ch_red_ps8, ch_green_ps8, ch_blue_ps8})
    );

    logic [7:0] img_red_ps9, img_green_ps9, img_blue_ps9;
    synchronizer #(
        .DEPTH(6),
        .WIDTH(3 * 8)
    ) sync_img (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in ({img_red, img_green, img_blue}),
        .data_out({img_red_ps9, img_green_ps9, img_blue_ps9})
    );

    wire should_mark_pixel = (pixel_led_id[0] == 1'b1);

    video_mux mvm (
        .bg_in(display_choice),  //choose background
        .target_in(target_choice),  //choose target
        .camera_pixel_in({fb_red_ps2, fb_green_ps2, fb_blue_ps2}),  //DONE: needs (PS2)
        .camera_y_in(y_ps6),  //luminance DONE: needs (PS6)
        .channel_in(selected_channel_ps5),  //current channel being drawn DONE: needs (PS5)
        .thresholded_pixel_in({
            detect1_ps4, detect0_ps4
        }),  //one bit mask signal DONE: needs (PS4) - NOT USED
        .should_mark_pixel_in(should_mark_pixel),
        .crosshair_in({ch_red_ps8, ch_green_ps8, ch_blue_ps8}),  //DONE: needs (PS8)
        .com_sprite_pixel_in({
            img_red_ps9, img_green_ps9, img_blue_ps9
        }),  //DONE: needs (PS9) maybe?
        .pixel_out({red, green, blue})  //output to tmds
    );

    hdmi_driver hdmi_out (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .sys_rst_pixel(sys_rst_pixel),
        .red(red),
        .green(green),
        .blue(blue),
        .vsync_hdmi(vsync_hdmi_ps7),
        .hsync_hdmi(hsync_hdmi_ps7),
        .active_draw_hdmi(active_draw_hdmi_ps7),
        .hdmi_tx_p(hdmi_tx_p),
        .hdmi_tx_n(hdmi_tx_n),
        .hdmi_clk_p(hdmi_clk_p),
        .hdmi_clk_n(hdmi_clk_n)
    );

    // Nothing To Touch Down Here:
    // register writes to the camera

    // The OV5640 has an I2C bus connected to the board, which is used
    // for setting all the hardware settings (gain, white balance,
    // compression, image quality, etc) needed to start the camera up.
    // We've taken care of setting these all these values for you:
    // "rom.mem" holds a sequence of bytes to be sent over I2C to get
    // the camera up and running, and we've written a design that sends
    // them just after a reset completes.

    // If the camera is not giving data, press your reset button.

    logic busy, bus_active;
    logic cr_init_valid, cr_init_ready;

    logic recent_reset;
    always_ff @(posedge clk_camera) begin
        if (sys_rst_camera) begin
            recent_reset  <= 1'b1;
            cr_init_valid <= 1'b0;
        end else if (recent_reset) begin
            cr_init_valid <= 1'b1;
            recent_reset  <= 1'b0;
        end else if (cr_init_valid && cr_init_ready) begin
            cr_init_valid <= 1'b0;
        end
    end

    camera_configurator cam_conf (
        .clk_camera(clk_camera),
        .sys_rst_camera(sys_rst_camera),
        .cr_init_valid(cr_init_valid),
        .cr_init_ready(cr_init_ready),
        .bus_active(bus_active),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
        .exposure(exposure),
        .ready_update_in(btn[3])
    );

    // a handful of debug signals for writing to registers
    assign led[0] = bus_active;
    assign led[1] = cr_init_valid;
    assign led[2] = cr_init_ready;
    assign led[15:3] = 0;

endmodule  // top_level


`default_nettype wire

