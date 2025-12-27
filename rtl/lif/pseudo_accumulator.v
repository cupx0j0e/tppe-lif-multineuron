`timescale 1ns / 1ps
module pseudo_accumulator #(
    parameter integer VMEM_W = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   reset_scan,
    input  wire [VMEM_W-1:0]      fast_sum,
    input  wire [VMEM_W-1:0]      leak,
    input  wire [VMEM_W-1:0]      corr,
    output reg  [VMEM_W-1:0]      vmem
);
    wire [VMEM_W:0] vmem_next_ext;
    wire [VMEM_W-1:0] vmem_next;
    
    assign vmem_next_ext =
          {1'b0, vmem}
        + {1'b0, fast_sum}
        - {1'b0, leak}
        - {1'b0, corr};
        
    assign vmem_next =
    vmem_next_ext[VMEM_W]
        ? {VMEM_W{1'b0}}          // clamp to 0 on underflow
        : vmem_next_ext[VMEM_W-1:0];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || reset_scan) begin
            vmem <= {VMEM_W{1'b0}};
        end
        else begin
            vmem <= vmem_next;
        end
    end
endmodule
