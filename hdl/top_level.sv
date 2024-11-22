`timescale 1ns / 1ps
`include "driver/led_driver.sv"
`include "pattern/pat_gradient.sv"
`default_nettype none

module top_level #(
    parameter int NUM_LEDS = 2,
    parameter int COLOR_WIDTH = 8,
    localparam int CounterWidth = $clog2(NUM_LEDS)
) (
    // SHARED
    input wire clk_100mhz,
    input wire [3:0] btn,  // push buttons
    input wire [15:0] sw,  // switches
    output logic [15:0] led,  // green leds
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1,

    // LED 
    output logic [3:0] strand_out  // strand output wire PMODA

    // CAMERA BUS
    input wire [7:0]    camera_d, // 8 parallel data wires
    output logic        cam_xclk, // XC driving camera
    input wire          cam_hsync, // camera hsync wire
    input wire          cam_vsync, // camera vsync wire
    input wire          cam_pclk, // camera pixel clock
    inout wire          i2c_scl, // i2c inout clock
    inout wire          i2c_sda, // i2c inout data

    //HDMI PORT
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);

    // SHUT THEM RGB BOARD LEDS UP
    assign rgb0 = 3'b000;
    assign rgb1 = 3'b000;

    // CAMERA 
    //assign clock and reset signals
    logic sys_rst_camera;
    logic sys_rst_pixel;
    logic clk_camera;
    logic clk_pixel;
    logic clk_xc;
    logic clk_5x;
    logic clk_100_passthrough;

    // clock wizards to generate the clock speeds neede for different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the camera's PCLK 50MHz
    cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .clk_tmds(clk_5x),
     .reset(0));

    cw_fast_clk_wiz wizard_migcam
    (.clk_in1(clk_100mhz),
     .clk_camera(clk_camera),
     .clk_xc(clk_xc),
     .clk_100(clk_100_passthrough),
     .reset(0));

     // assign camera's xclk to mod port: drive the operating clock of the camera
     // this port also is specfically set to high drive by the XDC file
    assign cam_xclk = clk_xc;
    assign sys_rst_camera = btn[0];
    assign sys_rst_pixel = btn[0];


    //HDMI
    //video signal generator signals
    logic          hsync_hdmi;
    logic          vsync_hdmi;
    logic [10:0]   hcount_hdmi;
    logic [9:0]    vcount_hdmi;
    logic          active_draw_hdmi;
    logic          new_frame_hdmi;
    logic [5:0]    frame_count_hdmi;
    logic          nf_hdmi;
    logic [7:0]    red, green, blue; // rgb output values

    //HANDLE INPUT FROM CAMERA
    //synchronizers to prevent metastability
    logic [7:0]    camera_d_buf [1:0];
    logic          cam_hsync_buf [1:0];
    logic          cam_vsync_buf [1:0];
    logic          cam_pclk_buf [1:0];

    always_ff @(posedge clk_camera) begin
        camera_d_buf <= {camera_d, camera_d_buf[1]};
        cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
        cam_hsync_buf <= {cam_hsync, cam_hsync_buf[1]};
        cam_vsync_buf <= {cam_vsync, cam_vsync_buf[1]};
    end

    // hooking up pixel_reconstruct module
    logic [10:0] camera_hcount;
    logic [9:0]  camera_vcount;
    logic [15:0] camera_pixel;
    logic        camera_valid;

  // your pixel_reconstruct module, from the exercise!
  // hook it up to buffered inputs.
    pixel_reconstruct #(
        .HCOUNT_WIDTH(1280),
        .VCOUNT_WIDTH(720)
    ) pixel_reconstruct1
    (.clk_in(clk_camera),
        .rst_in(sys_rst_camera),
        .camera_pclk_in(cam_pclk_buf[0]),
        .camera_hs_in(cam_hsync_buf[0]),
        .camera_vs_in(cam_vsync_buf[0]),
        .camera_data_in(camera_d_buf[0]),
        .pixel_valid_out(camera_valid),
        .pixel_hcount_out(camera_hcount),
        .pixel_vcount_out(camera_vcount),
        .pixel_data_out(camera_pixel)
    );

    // BRAM for Camera
    /* //two-port BRAM used to hold image from camera.
    //The camera is producing video at 720p and 30fps, but we can't store all of that
    //we're going to down-sample by a factor of 4 in both dimensions
    //so we have 320 by 180.  this is kinda a bummer, but we'll fix it
    //in future weeks by using off-chip DRAM.
    //even with the down-sample, because our camera is producing data at 30fps
    //and  our display is running at 720p at 60 fps, there's no hope to have the
    //production and consumption of information be synchronized in this system.
    //even if we could line it up once, the clocks of both systems will drift over time
    //so to avoid this sync issue, we use a conflict-resolution device...the frame buffer
    //instead we use a frame buffer as a go-between. The camera sends pixels in at
    //its own rate, and we pull them out for display at the 720p rate/requirement
    //this avoids the whole sync issue. It will however result in artifacts when you
    //introduce fast motion in front of the camera. These lines/tears in the image
    //are the result of unsynced frame-rewriting happening while displaying. It won't
    //matter for slow movement
    */
    localparam FB_DEPTH = 320*180;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer

    logic valid_camera_mem; //used to enable writing pixel data to frame buffer
    logic [15:0] camera_mem; //used to pass pixel data into frame buffer
    
    // Downsampling camera data and updating fb address
    always_ff @(posedge clk_camera)begin
        //create logic to handle wriiting of camera.
        //we want to down sample the data from the camera by a factor of four in both
        //the x and y dimensions! TO DO
        if (camera_valid && (camera_hcount[1:0] == 2'b00) && (camera_vcount[1:0] == 2'b00))begin
            if (camera_hcount == 0 && camera_vcount == 0)begin
            addra <= 0;
            end else begin
            addra <= addra + 1;
            end
            valid_camera_mem <= 1'b1; 
            camera_mem <= camera_pixel;
        end else begin
            valid_camera_mem <= 1'b0;
        end
    end

    //frame buffer from IP
    blk_mem_gen_0 frame_buffer (
        .addra(addra), //pixels are stored using this math
        .clka(clk_camera),
        .wea(valid_camera_mem),
        .dina(camera_mem),
        .ena(1'b1),
        .douta(0), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .doutb(frame_buff_raw)
    );
    logic [15:0] frame_buff_raw; //data out of frame buffer (565)
    logic [FB_SIZE-1:0] addrb; //used to lookup address in memory for reading from buffer
    logic good_addrb; //used to indicate within valid frame for scaling

    // Scale from frame buffer default 4x
    always_ff @(posedge clk_pixel)begin
        //use structure below to do scaling
        // if (btn[1])begin //1X scaling from frame buffer
        //     addrb <= (319-hcount_hdmi) + 320*vcount_hdmi;
        //     good_addrb <= (hcount_hdmi<320)&&(vcount_hdmi<180);
        // end else if (!sw[0])begin //2X scaling from frame buffer
        //     addrb <= (319-(hcount_hdmi>>1)) + 320*(vcount_hdmi>>1);
        //     good_addrb <= (hcount_hdmi<640)&&(vcount_hdmi<360); 
        // end else begin //4X scaling from frame buffer
            addrb <= (319-(hcount_hdmi>>2)) + 320*(vcount_hdmi>>2);
            good_addrb <= (hcount_hdmi<1280)&&(vcount_hdmi<720);
        // end
    end

    // Split frame buffer into 3 8 bit color channels
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel)begin
        fb_red <= good_addrb?{frame_buff_raw[15:11],3'b0}:8'b0;
        fb_green <= good_addrb?{frame_buff_raw[10:5], 2'b0}:8'b0;
        fb_blue <= good_addrb?{frame_buff_raw[4:0],3'b0}:8'b0;
    end

    // Pixel Processing pre-HDMI output -> RGB to YCrCb
    //output of rgb to ycrcb conversion (10 bits due to module):
    logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
    //bottom 8 of y, cr, cb conversions:
    logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
    
    //Convert RGB of full pixel to YCrCb
    //See lecture 07 for YCrCb discussion.
    //Module has a 3 cycle latency
    rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_pixel),
    .r_in(fb_red),
    .g_in(fb_green),
    .b_in(fb_blue),
    .y_out(y_full),
    .cr_out(cr_full),
    .cb_out(cb_full)
    );








    wire rst_in = btn[0];

    logic [COLOR_WIDTH-1:0] next_red, next_green, next_blue;
    logic color_valid;
    logic [CounterWidth-1:0] next_led_request;

    // instantiate pattern modules
    pat_gradient #(
        .NUM_LEDS(NUM_LEDS),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) pat_gradient_inst (
        .rst_in(rst_in),
        .clk_in(clk_100mhz),
        .next_led_request(next_led_request),
        .red_out(next_red),
        .green_out(next_green),
        .blue_out(next_blue),
        .color_valid(color_valid)
    );

    // instantiate led_driver module
    led_driver #(
        .NUM_LEDS(NUM_LEDS),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) led_driver_inst (
        .rst_in(rst_in),
        .clk_in(clk_100mhz),
        .force_reset(btn[1]),
        .green_in(next_green),
        .red_in(next_red),
        .blue_in(next_blue),
        .color_valid(color_valid),
        .strand_out(strand_out[0]),
        .next_led_request(next_led_request)
    );


endmodule
`default_nettype wire
