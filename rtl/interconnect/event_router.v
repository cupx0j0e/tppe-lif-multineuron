module event_router #(
    parameter integer NUM_NEURONS = 16,
    parameter integer NEURON_ID_W = 4,
    parameter integer SCORE_W     = 4
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   scan_start_en,

    input  wire                   cand_valid,
    input  wire [NEURON_ID_W-1:0] cand_neuron,
    input  wire [SCORE_W-1:0]     cand_score,

    output reg  [NUM_NEURONS-1:0] lif_score_valid,
    output reg  [NUM_NEURONS*SCORE_W-1:0] lif_score
);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || scan_start_en) begin
            lif_score_valid <= '0;
            lif_score       <= '0;
        end else begin
            if (cand_valid) begin
                // Route to the specific neuron
                lif_score_valid[cand_neuron] <= 1'b1;
                lif_score[cand_neuron*SCORE_W +: SCORE_W] <= cand_score;
            end else begin
                // Hold the valid signal for one cycle, then clear
                lif_score_valid <= '0;
            end
        end
    end

endmodule
