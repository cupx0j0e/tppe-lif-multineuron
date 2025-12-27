`timescale 1ns/1ps
`default_nettype none

module tb_TPPE_LIF_MULTI_SYSTEM_FINAL;

    // ============================================================
    // Parameters (matching DUT)
    // ============================================================
    localparam integer T_WINDOW        = 16;
    localparam integer PARALLEL_FACTOR = 4;
    localparam integer NUM_NEURONS     = 16;
    localparam integer NEURON_ID_W     = 4;
    localparam integer COL_ID_W        = 4;
    localparam integer SCORE_W         = $clog2(T_WINDOW+1);
    localparam integer FIFO_DEPTH      = 8;
    localparam integer VMEM_W          = 16;
    localparam integer LEAK_SHIFT      = 4;
    localparam integer CORR_W          = 8;
    
    localparam CLK_PERIOD = 10;

    // ============================================================
    // Testbench signals
    // ============================================================
    reg clk;
    reg rst_n;
    
    // TPPE inputs
    reg spike_in;
    reg enable;
    reg weight_valid;
    reg [NEURON_ID_W-1:0] neuron_id;
    reg [COL_ID_W-1:0]    col_base;
    reg [PARALLEL_FACTOR*T_WINDOW-1:0] weight_patterns;
    reg [SCORE_W-1:0]     intersection_threshold;
    
    // Neuron thresholds
    reg [NUM_NEURONS*VMEM_W-1:0] thresholds;
    
    // Output spike stream
    wire spike_valid;
    wire [NEURON_ID_W-1:0] spike_id;
    reg  spike_ready;

    // ============================================================
    // DUT instantiation
    // ============================================================
    TPPE_LIF_MULTI_SYSTEM_FINAL #(
        .T_WINDOW(T_WINDOW),
        .PARALLEL_FACTOR(PARALLEL_FACTOR),
        .NUM_NEURONS(NUM_NEURONS),
        .NEURON_ID_W(NEURON_ID_W),
        .COL_ID_W(COL_ID_W),
        .SCORE_W(SCORE_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .VMEM_W(VMEM_W),
        .LEAK_SHIFT(LEAK_SHIFT),
        .CORR_W(CORR_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .spike_in(spike_in),
        .enable(enable),
        .weight_valid(weight_valid),
        .neuron_id(neuron_id),
        .col_base(col_base),
        .weight_patterns(weight_patterns),
        .intersection_threshold(intersection_threshold),
        .thresholds(thresholds),
        .spike_valid(spike_valid),
        .spike_id(spike_id),
        .spike_ready(spike_ready)
    );

    // ============================================================
    // Clock generation
    // ============================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ============================================================
    // Monitoring and display
    // ============================================================
    integer spike_count;
    integer cycle_count;
    
    // Monitor output spikes
    always @(posedge clk) begin
        if (spike_valid && spike_ready) begin
            $display(">>> [SPIKE OUT] Time=%0t | Cycle=%0d | Neuron ID=%0d <<<", 
                     $time, cycle_count, spike_id);
            spike_count = spike_count + 1;
        end
    end

    // Monitor input spikes
    always @(posedge clk) begin
        if (spike_in) begin
            $display("[SPIKE IN]  Time=%0t | Cycle=%0d", $time, cycle_count);
        end
    end

    // Monitor TPPE candidates
    always @(posedge clk) begin
        if (dut.cand_valid) begin
            $display("[CANDIDATE] Time=%0t | Cycle=%0d | Neuron=%0d | Col=%0d | Score=%0d",
                     $time, cycle_count, dut.cand_neuron, dut.cand_col, dut.cand_score);
        end
    end

    // Monitor scan windows
    always @(posedge clk) begin
        if (dut.scan_start_en) begin
            $display("[SCAN START] Time=%0t | Cycle=%0d | =====================", 
                     $time, cycle_count);
            // Show neuron states at scan boundaries
            $display("  Neuron[0] vmem=%0d, threshold=%0d", 
                     dut.u_lif_array.LIF_GEN[0].lif.vmem,
                     dut.thresholds[0*VMEM_W +: VMEM_W]);
            $display("  Neuron[1] vmem=%0d, threshold=%0d", 
                     dut.u_lif_array.LIF_GEN[1].lif.vmem,
                     dut.thresholds[1*VMEM_W +: VMEM_W]);
            $display("  Neuron[2] vmem=%0d, threshold=%0d", 
                     dut.u_lif_array.LIF_GEN[2].lif.vmem,
                     dut.thresholds[2*VMEM_W +: VMEM_W]);
        end
    end

    // Cycle counter
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    // Monitor event router activity - Neuron 0
    always @(posedge clk) begin
        if (dut.lif_score_valid[0]) begin
            $display("[ROUTER]    Time=%0t | Neuron[0] receives score=%0d",
                     $time, dut.lif_score[0*SCORE_W +: SCORE_W]);
        end
    end

    // Monitor event router activity - Neuron 1
    always @(posedge clk) begin
        if (dut.lif_score_valid[1]) begin
            $display("[ROUTER]    Time=%0t | Neuron[1] receives score=%0d",
                     $time, dut.lif_score[1*SCORE_W +: SCORE_W]);
        end
    end

    // Monitor event router activity - Neuron 2
    always @(posedge clk) begin
        if (dut.lif_score_valid[2]) begin
            $display("[ROUTER]    Time=%0t | Neuron[2] receives score=%0d",
                     $time, dut.lif_score[2*SCORE_W +: SCORE_W]);
        end
    end

    // Monitor neuron 0 integration and firing
    always @(posedge clk) begin
        if (dut.u_lif_array.LIF_GEN[0].lif.score_valid) begin
            $display("  [NEURON 0] vmem=%0d, fast_sum=%0d, leak=%0d, score_in=%0d",
                     dut.u_lif_array.LIF_GEN[0].lif.vmem,
                     dut.u_lif_array.LIF_GEN[0].lif.fast_sum,
                     dut.u_lif_array.LIF_GEN[0].lif.leak,
                     dut.u_lif_array.LIF_GEN[0].lif.score_in);
        end
        if (dut.u_lif_array.LIF_GEN[0].lif.spike_raw) begin
            $display("  *** [NEURON 0 RAW SPIKE] vmem=%0d, threshold=%0d ***",
                     dut.u_lif_array.LIF_GEN[0].lif.vmem,
                     dut.thresholds[0*VMEM_W +: VMEM_W]);
        end
        if (dut.lif_spike_raw[0]) begin
            $display("  *** [NEURON 0 SPIKE VEC] lif_spike_raw[0]=1 ***");
        end
        if (dut.spike_fifo_valid[0]) begin
            $display("  *** [NEURON 0 FIFO OUT] valid=1, id=%0d ***",
                     dut.spike_fifo_id[0*NEURON_ID_W +: NEURON_ID_W]);
        end
    end

    // Monitor neuron 1 integration and firing
    always @(posedge clk) begin
        if (dut.u_lif_array.LIF_GEN[1].lif.score_valid) begin
            $display("  [NEURON 1] vmem=%0d, fast_sum=%0d, leak=%0d, score_in=%0d",
                     dut.u_lif_array.LIF_GEN[1].lif.vmem,
                     dut.u_lif_array.LIF_GEN[1].lif.fast_sum,
                     dut.u_lif_array.LIF_GEN[1].lif.leak,
                     dut.u_lif_array.LIF_GEN[1].lif.score_in);
        end
        if (dut.u_lif_array.LIF_GEN[1].lif.spike_raw) begin
            $display("  *** [NEURON 1 RAW SPIKE] vmem=%0d, threshold=%0d ***",
                     dut.u_lif_array.LIF_GEN[1].lif.vmem,
                     dut.thresholds[1*VMEM_W +: VMEM_W]);
        end
    end

    // Monitor neuron 2 integration
    always @(posedge clk) begin
        if (dut.u_lif_array.LIF_GEN[2].lif.score_valid) begin
            $display("  [NEURON 2] vmem=%0d, fast_sum=%0d, leak=%0d, score_in=%0d",
                     dut.u_lif_array.LIF_GEN[2].lif.vmem,
                     dut.u_lif_array.LIF_GEN[2].lif.fast_sum,
                     dut.u_lif_array.LIF_GEN[2].lif.leak,
                     dut.u_lif_array.LIF_GEN[2].lif.score_in);
        end
    end

    // ============================================================
    // Test stimulus
    // ============================================================
    initial begin
        // Initialize waveform dump
        $dumpfile("tppe_lif_system.vcd");
        $dumpvars(0, tb_TPPE_LIF_MULTI_SYSTEM_FINAL);
        
        // Initialize signals
        rst_n = 0;
        spike_in = 0;
        enable = 0;
        weight_valid = 0;
        neuron_id = 0;
        col_base = 0;
        weight_patterns = 0;
        intersection_threshold = 3;
        spike_ready = 1;
        spike_count = 0;
        cycle_count = 0;
        
        // Initialize thresholds (lower for easier testing)
        thresholds = {NUM_NEURONS{16'd1000}};  // High default
        thresholds[0*VMEM_W +: VMEM_W] = 16'd20;   // Neuron 0: easy to fire
        thresholds[1*VMEM_W +: VMEM_W] = 16'd30;   // Neuron 1: medium
        thresholds[2*VMEM_W +: VMEM_W] = 16'd50;   // Neuron 2: harder
        
        $display("\n========================================");
        $display("TPPE-LIF Multi-System Testbench");
        $display("========================================\n");
        $display("Configuration:");
        $display("  T_WINDOW        = %0d", T_WINDOW);
        $display("  PARALLEL_FACTOR = %0d", PARALLEL_FACTOR);
        $display("  NUM_NEURONS     = %0d", NUM_NEURONS);
        $display("  VMEM_W          = %0d", VMEM_W);
        $display("  LEAK_SHIFT      = %0d (leak = vmem/16)", LEAK_SHIFT);
        $display("\nThresholds:");
        $display("  Neuron[0] = %0d (easy)", thresholds[0*VMEM_W +: VMEM_W]);
        $display("  Neuron[1] = %0d (medium)", thresholds[1*VMEM_W +: VMEM_W]);
        $display("  Neuron[2] = %0d (hard)", thresholds[2*VMEM_W +: VMEM_W]);
        $display("  Others    = 1000 (disabled)");
        $display("\n========================================\n");

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("[RESET] System reset released at time %0t", $time);
        repeat(2) @(posedge clk);

        // ========================================
        // Test 1: Simple pattern to fire neuron 0
        // ========================================
        $display("\n[TEST 1] Simple pattern to fire neuron 0 (threshold=20)...\n");
        
        enable = 1;
        neuron_id = 0;
        col_base = 0;
        intersection_threshold = 3;
        
        // Pattern that will match well
        weight_patterns[0*T_WINDOW +: T_WINDOW] = 16'hFFFF;  // Match everything
        weight_patterns[1*T_WINDOW +: T_WINDOW] = 16'hAAAA;
        weight_patterns[2*T_WINDOW +: T_WINDOW] = 16'hCCCC;
        weight_patterns[3*T_WINDOW +: T_WINDOW] = 16'hF0F0;
        
        weight_valid = 1;
        
        // Send continuous spikes for 2 scan windows
        repeat(32) begin
            spike_in = 1;
            @(posedge clk);
        end
        spike_in = 0;
        
        repeat(20) @(posedge clk);
        
        // ========================================
        // Test 2: Target neuron 1
        // ========================================
        $display("\n[TEST 2] Targeting neuron 1 (threshold=30)...\n");
        
        neuron_id = 1;
        col_base = 4;
        
        repeat(40) begin
            spike_in = 1;
            @(posedge clk);
        end
        spike_in = 0;
        
        repeat(20) @(posedge clk);

        // ========================================
        // Summary
        // ========================================
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $display("Total simulation time: %0t ns", $time);
        $display("Total clock cycles: %0d", cycle_count);
        $display("Total spikes generated: %0d", spike_count);
        $display("\nChecking internal states:");
        $display("  Scan counter: %0d", dut.scan_cnt);
        $display("  Candidate valid: %0b", dut.cand_valid);
        
        // Check neuron states
        $display("\nFinal neuron membrane voltages:");
        $display("  Neuron[0] vmem=%0d (threshold=%0d)", 
                 dut.u_lif_array.LIF_GEN[0].lif.vmem,
                 thresholds[0*VMEM_W +: VMEM_W]);
        $display("  Neuron[1] vmem=%0d (threshold=%0d)", 
                 dut.u_lif_array.LIF_GEN[1].lif.vmem,
                 thresholds[1*VMEM_W +: VMEM_W]);
        $display("  Neuron[2] vmem=%0d (threshold=%0d)", 
                 dut.u_lif_array.LIF_GEN[2].lif.vmem,
                 thresholds[2*VMEM_W +: VMEM_W]);
        
        // Check if neurons fired
        if (spike_count == 0) begin
            $display("\n*** WARNING: NO SPIKES WERE GENERATED! ***");
            $display("*** Check neuron integration and firing logic ***");
        end else begin
            $display("\n*** SUCCESS: %0d spikes generated ***", spike_count);
        end
        
        $display("\n========================================\n");
        
        repeat(10) @(posedge clk);
        $finish;
    end

    // ============================================================
    // Timeout watchdog
    // ============================================================
    initial begin
        #(CLK_PERIOD * 5000);
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule

`default_nettype wire
