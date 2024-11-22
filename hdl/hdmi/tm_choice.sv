module tm_choice (
    input wire [DATA_WIDTH-1:0] data_in,
    output logic [8:0] qm_out
);
  localparam DATA_WIDTH = 8;

  always_comb begin
    logic [$clog2(DATA_WIDTH+1)-1:0] one_count;
    one_count = 0;
    for (int i = 0; i < DATA_WIDTH; i++) begin
      one_count += data_in[i];
    end


    qm_out[0] = data_in[0];
    if (one_count > 4 || (one_count == 4 && data_in[0] == 0)) begin
      // option 1 - rightside (of flowchart)
      for (int i = 1; i < 8; i++) begin
        qm_out[i] = ~(qm_out[i-1] ^ data_in[i]);
      end
      qm_out[8] = 0;
    end else begin
      // option 2 - leftside (of flowchart
      for (int i = 1; i < 8; i++) begin
        qm_out[i] = qm_out[i-1] ^ data_in[i];
      end
      qm_out[8] = 1;
    end
  end
endmodule  //end tm_choice
