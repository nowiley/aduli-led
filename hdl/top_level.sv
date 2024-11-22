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

    // VIDEO MUX STUFF
    //channel select module (select which of six color channels to mask):
    logic [2:0] channel_sel;
    logic [7:0] selected_channel; //selected channels
    //selected_channel could contain any of the six color channels depend on selection

    //threshold module (apply masking threshold):
    logic [7:0] lower_threshold;
    logic [7:0] upper_threshold;
    logic mask; //Whether or not thresholded pixel is 1 or 0

    // SKIPPNG COM

    //take lower 8 of full outputs.
    // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
    assign y = y_full[7:0];
    assign cr = {!cr_full[7],cr_full[6:0]};
    assign cb = {!cb_full[7],cb_full[6:0]};
    assign channel_sel = sw[3:1];
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
    localparam PS1_STAGES = 3;
    logic [7:0] ps1_r_in [PS1_STAGES-1:0];
    logic [7:0] ps1_g_in [PS1_STAGES-1:0];
    logic [7:0] ps1_b_in [PS1_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps1_r_in[0] <= fb_red;
        ps1_g_in[0] <= fb_green;
        ps1_b_in[0] <= fb_blue;
        for (int i=1; i<PS1_STAGES; i = i+1)begin
            ps1_r_in[i] <= ps1_r_in[i-1];
            ps1_g_in[i] <= ps1_g_in[i-1];
            ps1_b_in[i] <= ps1_b_in[i-1];
        end
    end
    channel_select mcs(
        .sel_in(channel_sel),
        .r_in(ps1_r_in[PS1_STAGES-1]),    //TODO: needs to use pipelined signal (PS1)
        .g_in(ps1_g_in[PS1_STAGES-1]),  //TODO: needs to use pipelined signal (PS1)
        .b_in(ps1_b_in[PS1_STAGES-1]),   //TODO: needs to use pipelined signal (PS1)
        .y_in(y),
        .cr_in(cr),
        .cb_in(cb),
        .channel_out(selected_channel)
    );

    //threshold values used to determine what value  passes:
    assign lower_threshold = {sw[11:8],4'b0};
    assign upper_threshold = {sw[15:12],4'b0};

    //Thresholder: Takes in the full selected channedl and
    //based on upper and lower bounds provides a binary mask bit
    // * 1 if selected channel is within the bounds (inclusive)
    // * 0 if selected channel is not within the bounds
    threshold mt(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .pixel_in(selected_channel),
        .lower_bound_in(lower_threshold),
        .upper_bound_in(upper_threshold),
        .mask_out(mask) //single bit if pixel within mask.
    );

    // SKIP Seven Segment display

    // SKIP COM

    // SKIP IMAGE SPRITE

    // SKIP Crosshair overlay

    // HDMI
    // HDMI video signal generator
    video_sig_gen vsg(
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
    logic [1:0] display_choice;
    logic [1:0] target_choice;

    assign display_choice = sw[5:4];
    assign target_choice =  sw[7:6];

    localparam PS2_STAGES = 4;
    // PS3 defined abover
    // PS4 not needed
    localparam PS5_STAGES = 1;
    localparam PS6_STAGES = 1;
    // PS7 not needed
    localparam PS8_STAGES = 8;
    localparam PS9_STAGES = 4;

    // PS2
    logic [7:0] ps2_fb_red [PS2_STAGES-1:0];
    logic [7:0] ps2_fb_green [PS2_STAGES-1:0];
    logic [7:0] ps2_fb_blue [PS2_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps2_fb_red[0] <= fb_red;
        ps2_fb_green[0] <= fb_green;
        ps2_fb_blue[0] <= fb_blue;
        for (int i=1; i<PS2_STAGES; i = i+1)begin
            ps2_fb_red[i] <= ps2_fb_red[i-1];
            ps2_fb_green[i] <= ps2_fb_green[i-1];
            ps2_fb_blue[i] <= ps2_fb_blue[i-1];
        end
    end

    // PS6
    logic [9:0] ps6_y [PS6_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps6_y[0] <= y;
        for (int i=1; i<PS6_STAGES; i = i+1)begin
            ps6_y[i] <= ps6_y[i-1];
        end
    end

    //PS5
    logic [7:0] ps5_selected_channel [PS5_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps5_selected_channel[0] <= selected_channel;
        for (int i=1; i<PS5_STAGES; i = i+1)begin
            ps5_selected_channel[i] <= ps5_selected_channel[i-1];
        end
    end

    //PS8 
    logic [7:0] ps8_ch_red [PS8_STAGES-1:0];
    logic [7:0] ps8_ch_green [PS8_STAGES-1:0];
    logic [7:0] ps8_ch_blue [PS8_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps8_ch_red[0] <= ch_red;
        ps8_ch_green[0] <= ch_green;
        ps8_ch_blue[0] <= ch_blue;
        for (int i=1; i<PS8_STAGES; i = i+1)begin
            ps8_ch_red[i] <= ps8_ch_red[i-1];
            ps8_ch_green[i] <= ps8_ch_green[i-1];
            ps8_ch_blue[i] <= ps8_ch_blue[i-1];
        end
    end

    //PS9
    logic [7:0] ps9_img_red [PS9_STAGES-1:0];
    logic [7:0] ps9_img_green [PS9_STAGES-1:0];
    logic [7:0] ps9_img_blue [PS9_STAGES-1:0];
    always_ff @(posedge clk_pixel)begin
        ps9_img_red[0] <= img_red;
        ps9_img_green[0] <= img_green;
        ps9_img_blue[0] <= img_blue;
        for (int i=1; i<PS9_STAGES; i = i+1)begin
            ps9_img_red[i] <= ps9_img_red[i-1];
            ps9_img_green[i] <= ps9_img_green[i-1];
            ps9_img_blue[i] <= ps9_img_blue[i-1];
        end
    end

    video_mux mvm(
        .bg_in(display_choice), //choose background
        .target_in(target_choice), //choose target
        .camera_pixel_in({ps2_fb_red[PS2_STAGES-1], ps2_fb_green[PS2_STAGES-1], ps2_fb_blue[PS2_STAGES-1]}), //TODO: needs (PS2)
        .camera_y_in(ps6_y[PS6_STAGES-1]), //luminance TODO: needs (PS6)
        .channel_in(ps5_selected_channel[PS5_STAGES-1]), //current channel being drawn TODO: needs (PS5)
        .thresholded_pixel_in(mask), //one bit mask signal TODO: needs (PS4)
        .crosshair_in({ps8_ch_red[PS8_STAGES-1], ps8_ch_green[PS8_STAGES-1], ps8_ch_blue[PS8_STAGES-1]}), //TODO: needs (PS8)
        .com_sprite_pixel_in({ps9_img_red[PS9_STAGES-1], ps9_img_green[PS9_STAGES-1], ps9_img_blue[PS9_STAGES-1]}), //TODO: needs (PS9) maybe?
        .pixel_out({red,green,blue}) //output to tmds
    );

    // HDMI Output: just like before!

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic       tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control_in[0] = horizontal sync signal
    //  * control_in[1] = vertical sync signal

    tmds_encoder tmds_red(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(red),
        .control_in(2'b0),
        .ve_in(ps3_ad[PS3_STAGES-1]),
        .tmds_out(tmds_10b[2]));

    tmds_encoder tmds_green(
            .clk_in(clk_pixel),
            .rst_in(sys_rst_pixel),
            .data_in(green),
            .control_in(2'b0),
            .ve_in(ps3_ad[PS3_STAGES-1]),
            .tmds_out(tmds_10b[1]));

    tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(blue),
        .control_in({ps3_vsync[PS3_STAGES-1],ps3_hsync[PS3_STAGES-1]}),
        .ve_in(ps3_ad[PS3_STAGES-1]),
        .tmds_out(tmds_10b[0]));


    //three tmds_serializers (blue, green, red):
    //MISSING: two more serializers for the green and blue tmds signals.
    tmds_serializer red_ser(
            .clk_pixel_in(clk_pixel),
            .clk_5x_in(clk_5x),
            .rst_in(sys_rst_pixel),
            .tmds_in(tmds_10b[2]),
            .tmds_out(tmds_signal[2]));
    tmds_serializer green_ser(
            .clk_pixel_in(clk_pixel),
            .clk_5x_in(clk_5x),
            .rst_in(sys_rst_pixel),
            .tmds_in(tmds_10b[1]),
            .tmds_out(tmds_signal[1]));
    tmds_serializer blue_ser(
            .clk_pixel_in(clk_pixel),
            .clk_5x_in(clk_5x),
            .rst_in(sys_rst_pixel),
            .tmds_in(tmds_10b[0]),
            .tmds_out(tmds_signal[0]));

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));


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

    logic  busy, bus_active;
    logic  cr_init_valid, cr_init_ready;

    logic  recent_reset;
    always_ff @(posedge clk_camera) begin
        if (sys_rst_camera) begin
            recent_reset <= 1'b1;
            cr_init_valid <= 1'b0;
        end
        else if (recent_reset) begin
            cr_init_valid <= 1'b1;
            recent_reset <= 1'b0;
        end else if (cr_init_valid && cr_init_ready) begin
            cr_init_valid <= 1'b0;
        end
    end

    logic [23:0] bram_dout;
    logic [7:0]  bram_addr;

    // ROM holding pre-built camera settings to send
    xilinx_single_port_ram_read_first
        #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("rom.mem")
        ) registers
        (
        .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),     // Clock
        .wea(1'b0),            // Write enable
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
        );

    logic [23:0] registers_dout;
    logic [7:0]  registers_addr;
    assign registers_dout = bram_dout;
    assign bram_addr = registers_addr;

    logic       con_scl_i, con_scl_o, con_scl_t;
    logic       con_sda_i, con_sda_o, con_sda_t;

    // NOTE these also have pullup specified in the xdc file!
    // access our inouts properly as tri-state pins
    IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
    IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

    // provided module to send data BRAM -> I2C
    camera_registers crw
        (.clk_in(clk_camera),
        .rst_in(sys_rst_camera),
        .init_valid(cr_init_valid),
        .init_ready(cr_init_ready),
        .scl_i(con_scl_i),
        .scl_o(con_scl_o),
        .scl_t(con_scl_t),
        .sda_i(con_sda_i),
        .sda_o(con_sda_o),
        .sda_t(con_sda_t),
        .bram_dout(registers_dout),
        .bram_addr(registers_addr));

    // a handful of debug signals for writing to registers
    assign led[0] = crw.bus_active;
    assign led[1] = cr_init_valid;
    assign led[2] = cr_init_ready;
    assign led[15:3] = 0;



////////////////////////////////////////////////////////////////////////////////
// LED STUFF
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
