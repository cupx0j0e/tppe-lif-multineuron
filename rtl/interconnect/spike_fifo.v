module spike_fifo #(
    parameter integer NEURON_ID_W = 4
)(
    input  wire clk,
    input  wire rst_n,

    input  wire spike_in,
    input  wire [NEURON_ID_W-1:0] spike_id_in,

    output wire spike_ready,

    output wire spike_valid,
    output wire [NEURON_ID_W-1:0] spike_id_out,
    input  wire spike_accept
);

    simple_fifo #(
        .WIDTH(NEURON_ID_W)
    ) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(spike_in),
        .in_data(spike_id_in),
        .in_ready(spike_ready),
        .out_valid(spike_valid),
        .out_data(spike_id_out),
        .out_ready(spike_accept)
    );

endmodule

