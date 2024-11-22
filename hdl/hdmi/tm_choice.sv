
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  //your code here, friend
  logic [3:0] ones;
  integer i;
  always_comb begin
    ones = 0;
    for (i = 0; i < 8; i++)begin
      ones = ones + data_in[i];
    end

  if ((ones > 4) || (ones == 4 && data_in[0] == 0)) begin //option 2
    qm_out[0] = data_in[0];
    for (i = 1; i < 8; i++)begin
      qm_out[i] = ~(data_in[i] ^ qm_out[i-1]);
    end
    qm_out[8] = 0;
  end else begin //option 1
    qm_out[0] = data_in[0];
    for (i = 1; i < 8; i++)begin
      qm_out[i] = data_in[i] ^ qm_out[i-1];
    end
    qm_out[8] = 1;
    end 
  end


endmodule //end tm_choice
