`default_nettype none
module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);
	// your code here
    logic [32:0] running_tot;
    logic [32:0] running_sum_x;
    logic [32:0] running_sum_y;
    typedef enum {SUMMING, DIVIDING} calc_state_t;
    calc_state_t calc_state;
    logic x_div_valid;
    logic y_div_valid;
    logic x_done;
    logic y_done;
    logic [32:0] x_out_buf;
    logic [32:0] y_out_buf;

    divider div_x (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(running_sum_x),
        .divisor_in(running_tot),
        .data_valid_in(tabulate_in),
        .quotient_out(x_out_buf),
        .remainder_out(),
        .data_valid_out(x_div_valid),
        .error_out(),
        .busy_out()
    );
    divider div_y (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(running_sum_y),
        .divisor_in(running_tot),
        .data_valid_in(tabulate_in),
        .quotient_out(y_out_buf),
        .remainder_out(),
        .data_valid_out(y_div_valid),
        .error_out(),
        .busy_out()
    );

    always_ff @(posedge clk_in) begin
    if (rst_in) begin
        running_tot <= 0;
        running_sum_x <= 0;
        running_sum_y <= 0;
        calc_state <= SUMMING;
        x_done <= 0;
        y_done <= 0;
        x_out <= 0;
        y_out <= 0;
        valid_out <= 0;
    end else begin
        case (calc_state)
            SUMMING: begin
                valid_out <= 0;
                if (tabulate_in) begin
                    if (running_tot > 0) begin
                        calc_state <= DIVIDING;
                    end else begin
                        calc_state <= SUMMING;
                    end
                end else if (x_in == 0 && y_in == 0) begin
                    running_tot <= valid_in;
                    running_sum_x <= 0;
                    running_sum_y <= 0;
                end else begin
                    if (valid_in) begin
                        running_tot <= running_tot + 1; 
                        running_sum_x <= running_sum_x + x_in;
                        running_sum_y <= running_sum_y + y_in;
                    end
                end
                
            end
            DIVIDING: begin
                if (x_div_valid) begin
                    x_out <= x_out_buf;
                    x_done <= 1;
                end
                if (y_div_valid) begin
                    y_out <= y_out_buf;
                    y_done <= 1;
                end
                if (x_done && y_done) begin
                    valid_out <= 1;
                    calc_state <= SUMMING;
                    x_done <= 0;
                    y_done <= 0;
                end
            end
            endcase  
        end
    end

endmodule

`default_nettype wire
