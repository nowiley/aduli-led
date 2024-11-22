`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));
  
  
  //your code here.
  logic [4:0] tally;
  logic [3:0] num_ones;
  logic [3:0] num_zeros;
  
  // Count the number of ones and zeros in the bottom 8 bits of q_m signal
  always_comb begin
    num_ones = 0;
    num_zeros = 0;
    for (int i = 0; i < 8; i++)begin
        num_ones = num_ones + q_m[i];
        num_zeros = num_zeros + !q_m[i];
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin // RESET
      tally <= 0;
      tmds_out <= 10'b0;

    end else if (!ve_in) begin //VIDEO ENABLE DOWN
      tally <= 0;
      case (control_in)
        (2'b00): tmds_out <= 10'b1101010100;
        (2'b01): tmds_out <= 10'b0010101011;
        (2'b10): tmds_out <= 10'b0101010100;
        (2'b11): tmds_out <= 10'b1010101011;
        default: tmds_out <= 10'b0;
      endcase

    end else begin // STANDARD OPERATION
        // STEP 1
        if ((tally == 0) || num_ones == num_zeros) begin // Right Option
            tmds_out[9] <= !q_m[8];
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= q_m[8]? q_m[7:0] : ~q_m[7:0];
            if (q_m[8] == 0) begin
                tally <= tally + num_zeros - num_ones;
            end else begin
                tally <= tally + num_ones - num_zeros;
            end
        end else if ( (tally[4] == 0 && num_ones > num_zeros) || (tally[4] == 1 && num_zeros > num_ones) ) begin // Left Option
            //bottom right option
            tmds_out[9] <= 1;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= ~q_m[7:0];
            tally <= tally + 2*(q_m[8] && 2'b111) + num_zeros - num_ones; 
        end else begin
            //bottom left option
            tmds_out[9] <= 0;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= q_m[7:0];
            // tally <= tally + 2*(q_m[8] && 2'b111) + num_zeros - num_ones; 
            tally <= tally - 2*(~q_m[8] && 2'b111) + num_ones - num_zeros; 
        end
    end
  end


endmodule //end tmds_encoder
`default_nettype wire
