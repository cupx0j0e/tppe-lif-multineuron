`timescale 1ns/1ps
`default_nettype none

module spike_compressor_temporal #(
    parameter integer T_WINDOW = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   spike_in,
    output reg  [T_WINDOW-1:0]    compressed_pattern
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compressed_pattern <= {T_WINDOW{1'b0}};
        end
        else begin
            // Shift left and insert current spike
            compressed_pattern <= {
                compressed_pattern[T_WINDOW-2:0],
                spike_in
            };
        end
    end

endmodule

`default_nettype wire

