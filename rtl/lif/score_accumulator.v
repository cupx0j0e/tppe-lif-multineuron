`timescale 1ns / 1ps

module score_accumulator #(
    parameter integer SCORE_W = 4,
    parameter integer VMEM_W  = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   scan_start_en,
    input  wire                   score_valid,
    input  wire [SCORE_W-1:0]     score_in,
    output reg  [VMEM_W-1:0]      sum_out
);

    always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_out <= 0;
    end
    else if (scan_start_en) begin
        sum_out <= 0;
    end
    else if (score_valid) begin
        sum_out <= sum_out + score_in;
    end
    else begin
        sum_out <= 0;   // <<< THIS LINE IS NON-NEGOTIABLE
    end
end

endmodule

