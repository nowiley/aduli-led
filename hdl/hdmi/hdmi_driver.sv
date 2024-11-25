`timescale 1ns / 1ps  // (comment to prevent autoformatting)
`include "hdmi/tmds_encoder.sv"
`include "hdmi/tmds_serializer.sv"

module hdmi_driver (
    input  wire        clk_pixel,
    input  wire        clk_5x,
    input  wire        sys_rst_pixel,
    input  wire  [7:0] red,
    green,
    blue,
    input  wire        vsync_hdmi,
    hsync_hdmi,
    input  wire        active_draw_hdmi,
    output logic [2:0] hdmi_tx_p,         //hdmi output signals (positives) (blue, green, red)
    output logic [2:0] hdmi_tx_n,         //hdmi output signals (negatives) (blue, green, red)
    output logic       hdmi_clk_p,
    hdmi_clk_n
);

    // HDMI Output: just like before!

    logic [9:0] tmds_10b   [0:2];  //output of each TMDS encoder!
    logic       tmds_signal[2:0];  //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control_in[0] = horizontal sync signal
    //  * control_in[1] = vertical sync signal

    tmds_encoder tmds_red (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(red),
        .control_in(2'b0),
        .ve_in(active_draw_hdmi),
        .tmds_out(tmds_10b[2])
    );

    tmds_encoder tmds_green (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(green),
        .control_in(2'b0),
        .ve_in(active_draw_hdmi),
        .tmds_out(tmds_10b[1])
    );

    tmds_encoder tmds_blue (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(blue),
        .control_in({vsync_hdmi, hsync_hdmi}),
        .ve_in(active_draw_hdmi),
        .tmds_out(tmds_10b[0])
    );


    //three tmds_serializers (blue, green, red):
    //MISSING: two more serializers for the green and blue tmds signals.
    tmds_serializer red_ser (
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2])
    );
    tmds_serializer green_ser (
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1])
    );
    tmds_serializer blue_ser (
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0])
    );

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
`ifndef LINTING  // iverilog linting has no idea what these are
    OBUFDS OBUFDS_blue (
        .I (tmds_signal[0]),
        .O (hdmi_tx_p[0]),
        .OB(hdmi_tx_n[0])
    );
    OBUFDS OBUFDS_green (
        .I (tmds_signal[1]),
        .O (hdmi_tx_p[1]),
        .OB(hdmi_tx_n[1])
    );
    OBUFDS OBUFDS_red (
        .I (tmds_signal[2]),
        .O (hdmi_tx_p[2]),
        .OB(hdmi_tx_n[2])
    );
    OBUFDS OBUFDS_clock (
        .I (clk_pixel),
        .O (hdmi_clk_p),
        .OB(hdmi_clk_n)
    );
`endif



endmodule


`default_nettype wire
