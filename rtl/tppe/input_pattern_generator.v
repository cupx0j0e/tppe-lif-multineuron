`timescale 1ns/1ps
`default_nettype none

module input_pattern_generator #(
    parameter integer T_WINDOW = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   spike_in,
    output wire [T_WINDOW-1:0]    spike_pattern_out,
    output wire                   activity_mask_out
);

    // Internal signal
    wire [T_WINDOW-1:0] spike_pattern;

    // Temporal spike compression
    spike_compressor_temporal #(
        .T_WINDOW(T_WINDOW)
    ) u_spike_compressor (
        .clk      (clk),
        .rst_n    (rst_n),
        .spike_in (spike_in),
        .compressed_pattern (spike_pattern)
    );

    // Activity mask generation
    bitmask_generator #(
        .T_WINDOW(T_WINDOW)
    ) u_bitmask_generator (
        .pattern          (spike_pattern),
        .activity_bitmask(activity_mask_out)
    );

    // Output assignment
    assign spike_pattern_out = spike_pattern;

endmodule

`default_nettype wire

