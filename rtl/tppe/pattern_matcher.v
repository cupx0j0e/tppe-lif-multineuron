`timescale 1ns/1ps
`default_nettype none

module pattern_matcher #(
    parameter integer T_WINDOW = 16,
    parameter integer SCORE_W  = $clog2(T_WINDOW+1)
)(
    input  wire [T_WINDOW-1:0] input_pattern,
    input  wire [T_WINDOW-1:0] weight_pattern,
    output wire [SCORE_W-1:0]  match_score
);

    wire [T_WINDOW-1:0] match_bits;
    assign match_bits = input_pattern & weight_pattern;

    integer i;
    reg [SCORE_W-1:0] sum;

    always @(*) begin
        sum = '0;
        for (i = 0; i < T_WINDOW; i = i + 1)
            sum = sum + match_bits[i];
    end

    assign match_score = sum;

endmodule

`default_nettype wire 
