module lif_array #(
    parameter integer NUM_NEURONS = 16,
    parameter integer SCORE_W     = 4,
    parameter integer VMEM_W      = 16,
    parameter integer NEURON_ID_W = 4,
    parameter integer LEAK_SHIFT  = 4,
    parameter integer CORR_W      = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire scan_start_en,

    input  wire [NUM_NEURONS-1:0] lif_score_valid,
    input  wire [NUM_NEURONS*SCORE_W-1:0] lif_score,

    input  wire [NUM_NEURONS*VMEM_W-1:0] thresholds,

    output wire [NUM_NEURONS-1:0] spike_vec
);

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : LIF_GEN

            wire ev_valid, ev_ready;
            wire [SCORE_W-1:0] ev_score;

            neuron_event_fifo #(
                .SCORE_W(SCORE_W)
            ) u_event_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .score_valid(lif_score_valid[i]),
                .score_in(lif_score[i*SCORE_W +: SCORE_W]),
                .score_ready(),
                .fifo_valid(ev_valid),
                .fifo_score(ev_score),
                .fifo_ready(ev_ready)
            );

            lif_neuron_top #(
                .SCORE_W(SCORE_W),
                .VMEM_W(VMEM_W),
                .NEURON_ID_W(NEURON_ID_W),
                .LEAK_SHIFT(LEAK_SHIFT),
                .CORR_W(CORR_W)
            ) lif (
                .clk(clk),
                .rst_n(rst_n),
                .score_valid(ev_valid),
                .score_in(ev_score),
                .scan_start_en(scan_start_en),
                .threshold(thresholds[i*VMEM_W +: VMEM_W]),
                .neuron_id(i[NEURON_ID_W-1:0]),
                .spike_valid(spike_vec[i]),
                .spike_id(),
                .spike_ready(ev_ready)
            );
        end
    endgenerate

endmodule

