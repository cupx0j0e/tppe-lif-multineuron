`timescale 1ns/1ps
`default_nettype none

module loas_inner_join_parallel #(
    parameter integer T_WINDOW        = 16,
    parameter integer PARALLEL_FACTOR = 4,
    parameter integer NEURON_ID_W     = 4,
    parameter integer COL_ID_W        = 4,
    parameter integer SCORE_W         = $clog2(T_WINDOW+1)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,

    input  wire [NEURON_ID_W-1:0] neuron_id,
    input  wire [COL_ID_W-1:0]    col_base,
    input  wire [T_WINDOW-1:0]    spike_pattern,

    input  wire [PARALLEL_FACTOR*T_WINDOW-1:0] weight_patterns,
    input  wire [SCORE_W-1:0]     intersection_threshold,
    input  wire                   weight_valid,

    output reg                    fifo_valid,
    input  wire                   fifo_ready,
    output reg  [NEURON_ID_W-1:0] fifo_neuron,
    output reg  [COL_ID_W-1:0]    fifo_col,
    output reg  [SCORE_W-1:0]     fifo_score
);

    // --------------------------------------------------
    // 1. Parallel pattern matching
    // --------------------------------------------------
    wire [PARALLEL_FACTOR-1:0] hit;
    wire [PARALLEL_FACTOR*SCORE_W-1:0] score;

    genvar i;
    generate
        for (i = 0; i < PARALLEL_FACTOR; i = i + 1) begin : PM_GEN
            pattern_matcher #(
                .T_WINDOW(T_WINDOW)
            ) pm (
                .input_pattern (spike_pattern),
                .weight_pattern(weight_patterns[i*T_WINDOW +: T_WINDOW]),
                .match_score   (score[i*SCORE_W +: SCORE_W])
            );

            assign hit[i] =
                (score[i*SCORE_W +: SCORE_W] >= intersection_threshold);
        end
    endgenerate

    // --------------------------------------------------
    // 2. Priority encoder (picks first hit)
    // --------------------------------------------------
    integer k;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_valid <= 1'b0;
            found      <= 1'b0;
        end
        else if (enable && weight_valid) begin
            fifo_valid <= 1'b0;
            found      <= 1'b0;

            if (fifo_ready) begin
                for (k = 0; k < PARALLEL_FACTOR; k = k + 1) begin
                    if (hit[k] && !found) begin
                        fifo_valid  <= 1'b1;
                        fifo_neuron <= neuron_id;
                        fifo_col    <= col_base + k;
                        fifo_score  <= score[k*SCORE_W +: SCORE_W];
                        found       <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire

