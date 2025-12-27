module round_robin_arbiter #(
    parameter integer NUM_NEURONS = 16,
    parameter integer NEURON_ID_W = 4
)(
    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_NEURONS-1:0] req_valid,
    output reg  [NUM_NEURONS-1:0] req_grant,

    output reg                    spike_valid,
    output reg  [NEURON_ID_W-1:0] spike_id,
    input  wire                   spike_ready
);

    reg [NEURON_ID_W-1:0] last_grant;
    integer i;
    reg found;

    always @(*) begin
        req_grant   = '0;
        spike_valid = 1'b0;
        spike_id    = '0;
        found       = 1'b0;

        for (i = 1; i <= NUM_NEURONS; i = i + 1) begin
            int idx;
            idx = (last_grant + i) % NUM_NEURONS;

            if (req_valid[idx] && !found && spike_ready) begin
                found       = 1'b1;
                spike_valid = 1'b1;
                spike_id    = idx[NEURON_ID_W-1:0];
                req_grant[idx] = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_grant <= '0;
        end else if (spike_valid && spike_ready) begin
            last_grant <= spike_id;
        end
    end

endmodule

