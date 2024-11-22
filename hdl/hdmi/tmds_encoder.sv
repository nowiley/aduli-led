`timescale 1ns / 1ps
`include "hdmi/tm_choice.sv"
`default_nettype none  // prevents system from inferring an undeclared logic (good practice)

module tmds_encoder (
    input wire clk_in,
    input wire rst_in,
    input wire [DATA_WIDTH-1:0] data_in,  // video data (red, green or blue)
    input wire [1:0] control_in,  //for blue set to {vs,hs}, else will be 0
    input wire ve_in,  // video data enable, to choose between control or video signal
    output logic [9:0] tmds_out
);
  localparam DATA_WIDTH = 8;

  logic [DATA_WIDTH:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm (
      .data_in(data_in),
      .qm_out (q_m)
  );

  logic [$clog2(DATA_WIDTH+1)-1:0] one_count;
  always_comb begin
    one_count = 0;
    for (int i = 0; i < DATA_WIDTH; i++) begin
      one_count += q_m[i];
    end
  end
  logic [$clog2(DATA_WIDTH+1)-1:0] zro_count;
  assign zro_count = DATA_WIDTH - one_count;

  logic [4:0] cnt;

  always @(posedge clk_in) begin
    if (rst_in) begin
      cnt <= 0;
      tmds_out <= 10'b0;
    end else if (ve_in == 0) begin
      cnt <= 0;
      case (control_in)
        2'b00: tmds_out <= 10'b1101010100;
        2'b01: tmds_out <= 10'b0010101011;
        2'b10: tmds_out <= 10'b0101010100;
        2'b11: tmds_out <= 10'b1010101011;
      endcase
    end else begin
      if (cnt == 0 || (one_count == zro_count)) begin
        tmds_out[9] <= ~q_m[8];
        tmds_out[8] <= q_m[8];
        for (int i = 0; i < 8; i++) begin
          tmds_out[i] <= q_m[8] ? q_m[i] : ~q_m[i];
        end

        if (q_m[8] == 0) cnt <= cnt + zro_count - one_count;
        else cnt <= cnt + one_count - zro_count;
      end else begin
        if ((!cnt[4] && (one_count > zro_count)) || (cnt[4] && (zro_count > one_count))) begin
          tmds_out[9] <= 1;
          tmds_out[8] <= q_m[8];
          for (int i = 0; i < 8; i++) begin
            tmds_out[i] <= ~q_m[i];
          end

          cnt <= cnt + (q_m[8] << 1) + zro_count - one_count;
        end else begin
          tmds_out[9] <= 0;
          tmds_out[8] <= q_m[8];
          for (int i = 0; i < 8; i++) begin
            tmds_out[i] <= q_m[i];
          end

          cnt <= cnt - ((!q_m[8]) << 1) + one_count - zro_count;
        end
      end
    end
  end

endmodule  //end tmds_encoder
`default_nettype wire
