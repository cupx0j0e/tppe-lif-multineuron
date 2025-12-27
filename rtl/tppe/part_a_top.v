`timescale 1ns/1ps
`default_nettype none

module part_a_top #(
    // -----------------------------
    // Parameters (same as TB)
    // -----------------------------
    parameter integer T_WINDOW        = 16,
    parameter integer PARALLEL_FACTOR = 4,
    parameter integer NEURON_ID_W     = 4,
    parameter integer COL_ID_W        = 4,
    parameter integer SCORE_W         = $clog2(T_WINDOW+1),
    parameter integer FIFO_DEPTH      = 8
)(
    // -----------------------------
    // Clock & reset
    // -----------------------------
    input  wire clk,
    input  wire rst_n,

    // -----------------------------
    // Inputs (from TB)
    // -----------------------------
    input  wire                   spike_in,
    input  wire                   enable,
    input  wire                   weight_valid,

    input  wire [NEURON_ID_W-1:0] neuron_id,
    input  wire [COL_ID_W-1:0]    col_base,
    input  wire [SCORE_W-1:0]     intersection_threshold,
    input  wire [PARALLEL_FACTOR*T_WINDOW-1:0] weight_patterns,

    // -----------------------------
    // Outputs (candidate stream)
    // -----------------------------
    output wire                   cand_valid,
    output wire [NEURON_ID_W-1:0] cand_neuron,
    output wire [COL_ID_W-1:0]    cand_col,
    output wire [SCORE_W-1:0]     cand_score
);

    // ==================================================
    // Internal wires (EXACTLY from TB)
    // ==================================================
    wire [T_WINDOW-1:0] spike_pattern;

    wire ij_valid;
    wire ij_ready;
    wire [NEURON_ID_W-1:0] ij_neuron;
    wire [COL_ID_W-1:0]    ij_col;
    wire [SCORE_W-1:0]     ij_score;

    wire fifo_ready;

    // ==================================================
    // 1. Spike compressor
    // ==================================================
    spike_compressor_temporal #(
        .T_WINDOW(T_WINDOW)
    ) u_compressor (
        .clk                (clk),
        .rst_n              (rst_n),
        .spike_in           (spike_in),
        .compressed_pattern (spike_pattern)
    );

    // ==================================================
    // 2. Inner join (TPPE core)
    // ==================================================
    loas_inner_join_parallel #(
        .T_WINDOW        (T_WINDOW),
        .PARALLEL_FACTOR (PARALLEL_FACTOR),
        .NEURON_ID_W     (NEURON_ID_W),
        .COL_ID_W        (COL_ID_W),
        .SCORE_W         (SCORE_W)
    ) u_inner_join (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .enable                 (enable),

        .neuron_id              (neuron_id),
        .col_base               (col_base),
        .spike_pattern          (spike_pattern),

        .weight_patterns        (weight_patterns),
        .intersection_threshold (intersection_threshold),
        .weight_valid           (weight_valid),

        .fifo_valid             (ij_valid),
        .fifo_ready             (ij_ready),
        .fifo_neuron            (ij_neuron),
        .fifo_col               (ij_col),
        .fifo_score             (ij_score)
    );

    // ==================================================
    // 3. Candidate FIFO
    // ==================================================
    loas_candidate_fifo #(
        .DEPTH        (FIFO_DEPTH),
        .NEURON_ID_W  (NEURON_ID_W),
        .COL_ID_W     (COL_ID_W),
        .SCORE_W      (SCORE_W)
    ) u_fifo (
        .clk          (clk),
        .rst_n        (rst_n),

        .in_valid     (ij_valid),
        .in_ready     (ij_ready),
        .in_neuron    (ij_neuron),
        .in_col       (ij_col),
        .in_score     (ij_score),

        .out_valid    (cand_valid),
        .out_ready    (fifo_ready),
        .out_neuron   (cand_neuron),
        .out_col      (cand_col),
        .out_score    (cand_score)
    );

    // Always consume (same as TB)
    assign fifo_ready = 1'b1;

endmodule

`default_nettype wire

