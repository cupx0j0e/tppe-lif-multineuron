`timescale 1ns / 1ps

module lif_neuron_top #(
    parameter integer SCORE_W     = 4,
    parameter integer VMEM_W      = 16,
    parameter integer NEURON_ID_W = 4,
    parameter integer LEAK_SHIFT  = 4,
    parameter integer CORR_W      = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // -----------------------------
    // Synaptic input
    // -----------------------------
    input  wire                   score_valid,
    input  wire [SCORE_W-1:0]     score_in,
    input  wire                   scan_start_en,

    // -----------------------------
    // Neuron configuration
    // -----------------------------
    input  wire [VMEM_W-1:0]      threshold,
    input  wire [NEURON_ID_W-1:0] neuron_id,

    // -----------------------------
    // Spike output interface
    // -----------------------------
    output wire                   spike_valid,
    output wire [NEURON_ID_W-1:0] spike_id,
    input  wire                   spike_ready
);

    // --------------------------------------------------
    // Internal signals
    // --------------------------------------------------
    wire [VMEM_W-1:0] fast_sum;
    wire [VMEM_W-1:0] leak;
    wire [VMEM_W-1:0] corr;
    wire [VMEM_W-1:0] vmem;
    wire              spike_raw;
    wire              reset_vmem_from_fire;
    
    wire corr_enable;
    assign corr_enable = (vmem >= (1 << LEAK_SHIFT));


    // --------------------------------------------------
    // 1. Synaptic accumulation (temporal sum)
    // --------------------------------------------------
    score_accumulator #(
        .SCORE_W(SCORE_W),
        .VMEM_W (VMEM_W)
    ) u_score_acc (
        .clk           (clk),
        .rst_n         (rst_n),
        .scan_start_en (scan_start_en),
        .score_valid   (score_valid),
        .score_in      (score_in),
        .sum_out       (fast_sum)
    );

    // --------------------------------------------------
    // 2. Leak computation
    // --------------------------------------------------
    leak_unit #(
        .VMEM_W (VMEM_W),
        .SHIFT  (LEAK_SHIFT)
    ) u_leak (
        .clk      (clk),
        .rst_n    (rst_n),
        .vmem_in  (vmem),
        .leak_out (leak)
    );

    // --------------------------------------------------
    // 3. Fractional correction accumulation
    // --------------------------------------------------
    correction_accumulator #(
        .VMEM_W (VMEM_W),
        .CORR_W (CORR_W)
    ) u_corr (
        .clk           (clk),
        .rst_n         (rst_n),
        .clear         (1'b0),
        .scan_start_en (scan_start_en),
        .frac_in       ({ {(CORR_W-LEAK_SHIFT){1'b0}}, vmem[LEAK_SHIFT-1:0] }),
        .enable        (corr_enable),
        .corr_out      (corr)
    );


    // --------------------------------------------------
    // 4. Membrane voltage integration (pure integrator)
    // --------------------------------------------------
    pseudo_accumulator #(
        .VMEM_W(VMEM_W)
    ) u_vmem (
        .clk        (clk),
        .rst_n      (rst_n),
        .reset_scan (scan_start_en || reset_vmem_from_fire),
        .fast_sum   (fast_sum),
        .leak       (leak),
        .corr       (corr),
        .vmem       (vmem)
    );

    // --------------------------------------------------
    // 5. Firing logic with one-spike-per-scan guarantee
    // --------------------------------------------------
    p_lif #(
        .VMEM_W      (VMEM_W),
        .NEURON_ID_W (NEURON_ID_W)
    ) u_fire (
        .clk           (clk),
        .rst_n         (rst_n),
        .scan_start_en (scan_start_en),
        .vmem          (vmem),
        .threshold     (threshold),
        .neuron_id     (neuron_id),
        .spike         (spike_raw),
        .reset_vmem    (reset_vmem_from_fire),
        .spike_id      ()
    );

    // --------------------------------------------------
    // 6. Output directly - NO compression unit needed!
    // The spike_fifo in the top level handles buffering
    // --------------------------------------------------
    assign spike_valid = spike_raw;
    assign spike_id = neuron_id;

endmodule
