module synchronizer #(
    parameter DEPTH = 2,
    parameter WIDTH = 1
) (
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] data_in,  //unsync_in
    output logic [WIDTH-1:0] data_out  //sync_out
);
    logic [WIDTH-1:0] sync[DEPTH-1:0];

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < DEPTH; i = i + 1) begin
                sync[i] <= 0;
            end
        end else begin
            sync[DEPTH-1] <= data_in;
            for (int i = 1; i < DEPTH; i = i + 1) begin
                sync[i-1] <= sync[i];
            end
        end
    end
    assign data_out = sync[0];
endmodule
