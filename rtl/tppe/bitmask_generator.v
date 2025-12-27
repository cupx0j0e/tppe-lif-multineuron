`timescale 1ns/1ps
`default_nettype none

module bitmask_generator #(
    parameter integer T_WINDOW = 16
)(
    input  wire [T_WINDOW-1:0] pattern,
    output wire                activity_bitmask
);

    // Activity bitmask: 1 if any spike exists in the window
    assign activity_bitmask = |pattern;

endmodule

`default_nettype wire

