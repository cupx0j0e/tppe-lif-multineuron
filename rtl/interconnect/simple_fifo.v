`timescale 1ns/1ps
`default_nettype none

module simple_fifo #(
    parameter integer WIDTH = 8
)(
    input  wire clk,
    input  wire rst_n,

    input  wire             in_valid,
    input  wire [WIDTH-1:0] in_data,
    output wire             in_ready,

    output wire             out_valid,
    output wire [WIDTH-1:0] out_data,
    input  wire             out_ready
);

    reg full;
    reg [WIDTH-1:0] data;

    assign in_ready  = ~full;
    assign out_valid = full;
    assign out_data  = data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full <= 1'b0;
        end else begin
            // push
            if (in_valid && in_ready) begin
                data <= in_data;
                full <= 1'b1;
            end
            // pop
            if (out_valid && out_ready) begin
                full <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire

