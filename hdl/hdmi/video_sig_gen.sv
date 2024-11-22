module video_sig_gen #(
    parameter ACTIVE_H_PIXELS = 1280,
    parameter H_FRONT_PORCH = 110,
    parameter H_SYNC_WIDTH = 40,
    parameter H_BACK_PORCH = 220,
    parameter ACTIVE_LINES = 720,
    parameter V_FRONT_PORCH = 5,
    parameter V_SYNC_WIDTH = 5,
    parameter V_BACK_PORCH = 20,
    parameter FPS = 60
) (
    input wire pixel_clk_in,
    input wire rst_in,
    output logic [$clog2(TOTAL_WIDTH)-1:0] hcount_out,
    output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
    output logic hs_out,  //horizontal sync out
    output logic vs_out,  //vertical sync out
    output logic ad_out,  //active drawing out
    output logic nf_out,  //single cycle enable signal
    output logic [$clog2(FPS)-1:0] fc_out  // frame counter
);

    localparam TOTAL_WIDTH = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
    localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            hcount_out <= 0;
            vcount_out <= 0;
            fc_out <= 0;
        end else begin
            // Position / frame shifting
            if (hcount_out == TOTAL_WIDTH - 1) begin
                hcount_out <= 0;
                if (vcount_out == TOTAL_LINES - 1) begin
                    vcount_out <= 0;
                end else begin
                    vcount_out <= vcount_out + 1;
                end
            end else begin
                hcount_out <= hcount_out + 1;
            end

            if (hcount_out == ACTIVE_H_PIXELS - 1 && vcount_out == ACTIVE_LINES) begin
                // increment frame counter when reaching (ACTIVE_H_PIXELS, ACTIVE_LINES)
                fc_out <= (fc_out == FPS - 1) ? 0 : fc_out + 1;
            end
        end
    end

    // Status selectors
    /// note that these can be set based on the current state, given it is combinational
    always_comb begin
        hs_out = (hcount_out >= ACTIVE_H_PIXELS + H_FRONT_PORCH ) && (hcount_out < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH);
        vs_out = (vcount_out >= ACTIVE_LINES + V_FRONT_PORCH) && (vcount_out < ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH);
        ad_out = (hcount_out < ACTIVE_H_PIXELS && vcount_out < ACTIVE_LINES) && !rst_in;
        nf_out = (hcount_out == ACTIVE_H_PIXELS && vcount_out == ACTIVE_LINES);
    end

endmodule
