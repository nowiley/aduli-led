`include "math/divider.sv"
`default_nettype none
module center_of_mass (
    input wire clk_in,
    input wire rst_in,
    input wire [10:0] x_in,
    input wire [9:0] y_in,
    input wire valid_in,
    input wire tabulate_in,
    output logic [10:0] x_out,
    output logic [9:0] y_out,
    output logic valid_out
);
    enum {
        AQUIRE,
        CALCULATE_X,
        // WAIT_X,
        CALCULATE_Y
        // WAIT_Y
    } calc_state;

    logic [31:0] p_count;
    logic [31:0] x_sum;
    logic [31:0] y_sum;

    logic div_start;
    logic [31:0] div_in;
    logic [31:0] div_out;
    logic div_valid;
    divider divider_m (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(div_in),
        .divisor_in(p_count),
        .data_valid_in(div_start),
        .quotient_out(div_out),
        //.remainder_out(),
        .data_valid_out(div_valid)
        //.error_out(),
        //.busy_out()
    );

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            p_count <= 0;
            x_sum <= 0;
            y_sum <= 0;
            valid_out <= 0;
            calc_state <= AQUIRE;

        end else begin
            case (calc_state)
                AQUIRE: begin
                    valid_out <= 0;
                    if (tabulate_in) begin  // let's get dividing
                        div_in <= x_sum;
                        div_start <= 1;
                        calc_state <= CALCULATE_X;
                    end else if (valid_in) begin
                        x_sum   <= x_sum + x_in;
                        y_sum   <= y_sum + y_in;
                        p_count <= p_count + 1;
                    end
                end
                CALCULATE_X: begin
                    if (div_valid) begin
                        x_out <= div_out;
                        div_in <= y_sum;
                        div_start <= 1;
                        calc_state <= CALCULATE_Y;
                    end else begin
                        div_start <= 0;
                    end
                end
                CALCULATE_Y: begin
                    div_start <= 0;
                    // clean up and wait for divisions to end
                    p_count <= 0;
                    x_sum <= 0;
                    y_sum <= 0;

                    if (div_valid) begin
                        y_out <= div_out;
                        valid_out <= 1;
                        calc_state <= AQUIRE;
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire
