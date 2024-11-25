`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "pixel/pixel_reconstruct.sv"
`include "pixel/rgb_to_ycrcb.sv"
`include "common/synchronizer.sv"
`default_nettype none

module camera_reader #(
    localparam FB_DEPTH = 320 * 180,
    localparam FB_SIZE  = $clog2(FB_DEPTH)
) (
    input wire clk_camera,
    input wire clk_pixel,
    input wire sys_rst_camera,
    input wire sys_rst_pixel,
    input wire [7:0] camera_d,
    input wire cam_pclk,
    input wire cam_hsync,
    input wire cam_vsync,
    input wire [FB_SIZE-1:0] addrb,
    input wire good_addrb,
    output logic [7:0] red,
    green,
    blue,
    output logic [7:0] y,
    cr,
    cb
);


    // synchronizers to prevent metastability
    logic [7:0] camera_d_buf [1:0];
    logic       cam_hsync_buf[1:0];
    logic       cam_vsync_buf[1:0];
    logic       cam_pclk_buf [1:0];

    always_ff @(posedge clk_camera) begin
        camera_d_buf[0]  <= camera_d_buf[1];
        camera_d_buf[1]  <= camera_d;
        cam_pclk_buf[0]  <= cam_pclk_buf[1];
        cam_pclk_buf[1]  <= cam_pclk;
        cam_hsync_buf[0] <= cam_hsync_buf[1];
        cam_hsync_buf[1] <= cam_hsync;
        cam_vsync_buf[0] <= cam_vsync_buf[1];
        cam_vsync_buf[1] <= cam_vsync;
    end

    logic [10:0] camera_hcount;
    logic [ 9:0] camera_vcount;
    logic [15:0] camera_pixel;
    logic        camera_valid;

    // your pixel_reconstruct module, from the exercise!
    // hook it up to buffered inputs.
    pixel_reconstruct pixel_reconstruct_m (
        .clk_in(clk_camera),
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

    //two-port BRAM used to hold image from camera.
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
    logic [FB_SIZE-1:0] addra;  //used to specify address to write to in frame buffer

    logic valid_camera_mem;  //used to enable writing pixel data to frame buffer
    logic [15:0] camera_mem;  //used to pass pixel data into frame buffer


    //TO DO in camera part 1:
    always_ff @(posedge clk_camera) begin
        //create logic to handle wriiting of camera.
        //we want to down sample the data from the camera by a factor of four in both
        //the x and y dimensions! TO DO

        //downsample by 4 in x and y
        if (camera_hcount % 4 == 0 && camera_vcount % 4 == 0) begin
            addra <= (camera_hcount >> 2) + 320 * (camera_vcount >> 2);
            valid_camera_mem <= 1;
            camera_mem <= camera_pixel;
        end else begin
            valid_camera_mem <= 0;
        end
    end

    //frame buffer from IP
`ifndef LINTING
    blk_mem_gen_0 frame_buffer (
        .addra(addra),  //pixels are stored using this math
        .clka(clk_camera),
        .wea(valid_camera_mem),
        .dina(camera_mem),
        .ena(1'b1),
        .douta(),  //never read from this side
        .addrb(addrb),  //transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .doutb(frame_buff_raw)
    );
`endif
    logic [15:0] frame_buff_raw;  //data out of frame buffer (565)

    //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel) begin
        fb_red   <= good_addrb ? {frame_buff_raw[15:11], 3'b0} : 8'b0;
        fb_green <= good_addrb ? {frame_buff_raw[10:5], 2'b0} : 8'b0;
        fb_blue  <= good_addrb ? {frame_buff_raw[4:0], 3'b0} : 8'b0;
    end
    // Pixel Processing pre-HDMI output

    // RGB to YCrCb

    //output of rgb to ycrcb conversion (10 bits due to module):
    logic [9:0] y_full, cr_full, cb_full;  //ycrcb conversion of full pixel
    //Convert RGB of full pixel to YCrCb
    //See lecture 07 for YCrCb discussion.
    //Module has a 3 cycle latency
    rgb_to_ycrcb rgbtoycrcb_m (
        .clk_in(clk_pixel),
        .r_in  (fb_red),
        .g_in  (fb_green),
        .b_in  (fb_blue),
        .y_out (y_full),
        .cr_out(cr_full),
        .cb_out(cb_full)
    );

    //take lower 8 of full outputs.
    // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
    assign y  = y_full[7:0];
    assign cr = {!cr_full[7], cr_full[6:0]};
    assign cb = {!cb_full[7], cb_full[6:0]};

    synchronizer #(
        .DEPTH(3),
        .WIDTH(3 * 8)
    ) sync_fb_ps1 (
        .clk_in  (clk_pixel),
        .rst_in  (sys_rst_pixel),
        .data_in ({fb_red, fb_green, fb_blue}),
        .data_out({red, green, blue})
    );

endmodule

`default_nettype wire
