`timescale 1ns/1ps
`default_nettype none

module loas_candidate_fifo #(
    parameter integer DEPTH        = 16,
    parameter integer PTR_W        = $clog2(DEPTH),
    parameter integer NEURON_ID_W  = 4,
    parameter integer COL_ID_W     = 4,
    parameter integer SCORE_W      = 4
)(
    input  wire clk,
    input  wire rst_n,

    input  wire in_valid,
    output wire in_ready,
    input  wire [NEURON_ID_W-1:0] in_neuron,
    input  wire [COL_ID_W-1:0]    in_col,
    input  wire [SCORE_W-1:0]     in_score,

    output reg  out_valid,
    input  wire out_ready,
    output reg  [NEURON_ID_W-1:0] out_neuron,
    output reg  [COL_ID_W-1:0]    out_col,
    output reg  [SCORE_W-1:0]     out_score
);

    // --------------------------------------------------
    // FIFO storage
    // --------------------------------------------------
    reg [NEURON_ID_W-1:0] nmem [0:DEPTH-1];
    reg [COL_ID_W-1:0]    cmem [0:DEPTH-1];
    reg [SCORE_W-1:0]     smem [0:DEPTH-1];

    // Write & read pointers (+1 bit for wrap tracking)
    reg [PTR_W:0] wp, rp;

    // FIFO not full
    assign in_ready = ((wp - rp) < DEPTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wp        <= '0;
            rp        <= '0;
            out_valid <= 1'b0;
        end
        else begin
            // ------------------------------
            // Write side
            // ------------------------------
            if (in_valid && in_ready) begin
                nmem[wp[PTR_W-1:0]] <= in_neuron;
                cmem[wp[PTR_W-1:0]] <= in_col;
                smem[wp[PTR_W-1:0]] <= in_score;
                wp <= wp + 1'b1;
            end

            // ------------------------------
            // Read side
            // ------------------------------
            if (!out_valid && wp != rp) begin
                out_valid  <= 1'b1;
                out_neuron <= nmem[rp[PTR_W-1:0]];
                out_col    <= cmem[rp[PTR_W-1:0]];
                out_score  <= smem[rp[PTR_W-1:0]];
            end
            else if (out_valid && out_ready) begin
                out_valid <= 1'b0;
                rp <= rp + 1'b1;
            end
        end
    end

endmodule

`default_nettype wire

