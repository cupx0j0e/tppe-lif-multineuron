`timescale 1ns / 1ps

module leak_unit #(
    parameter integer VMEM_W = 16,
    parameter integer SHIFT  = 4
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [VMEM_W-1:0]      vmem_in,
    output reg  [VMEM_W-1:0]      leak_out
);

    always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        leak_out <= {VMEM_W{1'b0}};
    end
    else if (vmem_in != 0) begin
        leak_out <= (vmem_in >> SHIFT) + 1'b1; // GUARANTEED DECAY
    end
    else begin
        leak_out <= {VMEM_W{1'b0}};
    end
end

endmodule

