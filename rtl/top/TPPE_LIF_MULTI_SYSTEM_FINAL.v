`timescale 1ns/1ps
`default_nettype none

module TPPE_LIF_MULTI_SYSTEM_FINAL #(
    parameter integer T_WINDOW        = 16,
    parameter integer PARALLEL_FACTOR = 4,
    parameter integer NUM_NEURONS     = 16,
    parameter integer NEURON_ID_W     = 4,
    parameter integer COL_ID_W        = 4,
    parameter integer SCORE_W         = $clog2(T_WINDOW+1),
    parameter integer FIFO_DEPTH      = 8,
    parameter integer VMEM_W          = 16,
    parameter integer LEAK_SHIFT      = 4,
    parameter integer CORR_W          = 8
)(
    input  wire clk,
    input  wire rst_n,
    // Spike stream
    input  wire spike_in,
    // TPPE config
    input  wire enable,
    input  wire weight_valid,
    input  wire [NEURON_ID_W-1:0] neuron_id,
    input  wire [COL_ID_W-1:0]    col_base,
    input  wire [PARALLEL_FACTOR*T_WINDOW-1:0] weight_patterns,
    input  wire [SCORE_W-1:0]     intersection_threshold,
    // Per-neuron thresholds
    input  wire [NUM_NEURONS*VMEM_W-1:0] thresholds,
    // Final spike output
    output wire                   spike_valid,
    output wire [NEURON_ID_W-1:0] spike_id,
    input  wire                   spike_ready
);
    // ============================================================
    // Scan window generator
    // ============================================================
    reg [$clog2(T_WINDOW)-1:0] scan_cnt;
    reg scan_start_en;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt      <= '0;
            scan_start_en <= 1'b0;
        end else begin
            scan_start_en <= 1'b0;
            if (scan_cnt == T_WINDOW-1) begin
                scan_cnt      <= '0;
                scan_start_en <= 1'b1;
            end else begin
                scan_cnt <= scan_cnt + 1'b1;
            end
        end
    end

    // ============================================================
    // TPPE (Part A)
    // ============================================================
    wire cand_valid;
    wire [NEURON_ID_W-1:0] cand_neuron;
    wire [COL_ID_W-1:0]    cand_col;
    wire [SCORE_W-1:0]     cand_score;

    part_a_top #(
        .T_WINDOW(T_WINDOW),
        .PARALLEL_FACTOR(PARALLEL_FACTOR),
        .NEURON_ID_W(NEURON_ID_W),
        .COL_ID_W(COL_ID_W),
        .SCORE_W(SCORE_W),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_part_a (
        .clk(clk),
        .rst_n(rst_n),
        .spike_in(spike_in),
        .enable(enable),
        .weight_valid(weight_valid),
        .neuron_id(neuron_id),
        .col_base(col_base),
        .intersection_threshold(intersection_threshold),
        .weight_patterns(weight_patterns),
        .cand_valid(cand_valid),
        .cand_neuron(cand_neuron),
        .cand_col(cand_col),
        .cand_score(cand_score)
    );

    // ============================================================
    // Event router (TPPE → neuron lanes)
    // ============================================================
    wire [NUM_NEURONS-1:0] lif_score_valid;
    wire [NUM_NEURONS*SCORE_W-1:0] lif_score;

    event_router #(
        .NUM_NEURONS(NUM_NEURONS),
        .NEURON_ID_W(NEURON_ID_W),
        .SCORE_W(SCORE_W)
    ) u_router (
        .clk(clk),
        .rst_n(rst_n),
        .scan_start_en(scan_start_en),
        .cand_valid(cand_valid),
        .cand_neuron(cand_neuron),
        .cand_score(cand_score),
        .lif_score_valid(lif_score_valid),
        .lif_score(lif_score)
    );

    // ============================================================
    // LIF neuron array (with per-neuron event FIFOs)
    // ============================================================
    wire [NUM_NEURONS-1:0] lif_spike_raw;

    lif_array #(
        .NUM_NEURONS(NUM_NEURONS),
        .SCORE_W(SCORE_W),
        .VMEM_W(VMEM_W),
        .NEURON_ID_W(NEURON_ID_W),
        .LEAK_SHIFT(LEAK_SHIFT),
        .CORR_W(CORR_W)
    ) u_lif_array (
        .clk(clk),
        .rst_n(rst_n),
        .scan_start_en(scan_start_en),
        .lif_score_valid(lif_score_valid),
        .lif_score(lif_score),
        .thresholds(thresholds),
        .spike_vec(lif_spike_raw)
    );

    // ============================================================
    // Per-neuron spike FIFOs
    // ============================================================
    wire [NUM_NEURONS-1:0] spike_fifo_valid;
    wire [NUM_NEURONS-1:0] spike_fifo_ready;
    wire [NUM_NEURONS*NEURON_ID_W-1:0] spike_fifo_id;

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : SPIKE_FIFO_GEN
            spike_fifo #(
                .NEURON_ID_W(NEURON_ID_W)
            ) u_spike_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .spike_in(lif_spike_raw[i]),
                .spike_id_in(i[NEURON_ID_W-1:0]),
                .spike_ready(),
                .spike_valid(spike_fifo_valid[i]),
                .spike_id_out(spike_fifo_id[i*NEURON_ID_W +: NEURON_ID_W]),
                .spike_accept(spike_fifo_ready[i])
            );
        end
    endgenerate

    // ============================================================
    // Round-robin arbiter (fair + backpressure-safe)
    // ============================================================
    round_robin_arbiter #(
        .NUM_NEURONS(NUM_NEURONS),
        .NEURON_ID_W(NEURON_ID_W)
    ) u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(spike_fifo_valid),
        .req_grant(spike_fifo_ready),
        .spike_valid(spike_valid),
        .spike_id(spike_id),
        .spike_ready(spike_ready)
    );

endmodule

`default_nettype wire
