module p_lif #(
    parameter integer VMEM_W = 16,
    parameter integer NEURON_ID_W = 4
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   scan_start_en,
    input  wire [VMEM_W-1:0]      vmem,
    input  wire [VMEM_W-1:0]      threshold,
    input  wire [NEURON_ID_W-1:0] neuron_id,

    output reg                    spike,
    output reg                    reset_vmem,
    output reg  [NEURON_ID_W-1:0] spike_id
);

    reg fired;
    reg [VMEM_W-1:0] vmem_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike      <= 0;
            reset_vmem <= 0;
            fired      <= 0;
            vmem_prev  <= 0;
        end
        else begin
            // Capture vmem from previous cycle
            vmem_prev <= vmem;
            
            // Default: clear control signals
            spike      <= 0;
            reset_vmem <= 0;

            // On scan start, check if we should fire based on PREVIOUS vmem
            // (before the scan reset clears it)
            if (scan_start_en) begin
                if (!fired && vmem_prev >= threshold) begin
                    spike      <= 1;
                    reset_vmem <= 1;
                    spike_id   <= neuron_id;
                    fired      <= 1;
                end else begin
                    fired <= 0;  // Clear for new scan
                end
            end
            // During scan window, check for immediate firing
            else if (!fired && vmem >= threshold) begin
                spike      <= 1;
                reset_vmem <= 1;
                spike_id   <= neuron_id;
                fired      <= 1;
            end
        end
    end

endmodule
