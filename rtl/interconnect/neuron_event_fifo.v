module neuron_event_fifo #(
    parameter integer SCORE_W = 4
)(
    input  wire clk,
    input  wire rst_n,

    input  wire score_valid,
    input  wire [SCORE_W-1:0] score_in,
    output wire score_ready,

    output wire fifo_valid,
    output wire [SCORE_W-1:0] fifo_score,
    input  wire fifo_ready
);

    simple_fifo #(
        .WIDTH(SCORE_W)
    ) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(score_valid),
        .in_data(score_in),
        .in_ready(score_ready),
        .out_valid(fifo_valid),
        .out_data(fifo_score),
        .out_ready(fifo_ready)
    );

endmodule

