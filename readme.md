# TPPE-LIF Multi-Neuron Spiking Neural Network System

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [System Components](#system-components)
4. [Data Flow](#data-flow)
5. [Directory Structure](#directory-structure)
6. [Module Descriptions](#module-descriptions)
7. [Getting Started](#getting-started)
8. [Simulation](#simulation)
9. [Parameters](#parameters)
10. [Design Decisions](#design-decisions)
11. [Future Work](#future-work)

---

## Overview

This project implements a hardware-accelerated Spiking Neural Network (SNN) system that combines:

- **TPPE (Temporal Pattern Processing Engine)**: Performs real-time temporal pattern matching on incoming spike streams
- **LIF (Leaky Integrate-and-Fire) Neurons**: Biologically-inspired neuron models that integrate synaptic inputs and generate output spikes
- **Multi-Neuron Architecture**: Supports 16 parallel neurons with independent thresholds and state
- **Fair Arbitration**: Round-robin arbiter ensures fair access to the output spike channel

The system is designed for hardware implementation on FPGAs and processes spike trains in real-time with configurable temporal windows and pattern matching thresholds.

### Key Features

- Temporal pattern matching with 16-timestep sliding window
- 16 parallel LIF neurons with independent dynamics
- Configurable firing thresholds per neuron
- Leak computation with fractional correction for accurate dynamics
- Backpressure-aware spike routing
- One-spike-per-scan-window guarantee per neuron
- Round-robin arbitration for output fairness

---

## Architecture

### High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TPPE-LIF Multi-System                             │
│                                                                       │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│  │  Input   │───▶│   TPPE   │───▶│  Event   │───▶│   LIF    │     │
│  │  Spike   │    │ (Part A) │    │  Router  │    │  Array   │     │
│  │  Stream  │    └──────────┘    └──────────┘    └──────────┘     │
│  └──────────┘                                            │           │
│                                                           │           │
│                    ┌───────────────────────────────────┐ │           │
│                    │                                   │ │           │
│                    ▼                                   ▼ ▼           │
│             ┌──────────┐                       ┌──────────┐         │
│             │  Spike   │◀──────────────────────│  Spike   │         │
│             │  Arbiter │                       │  FIFOs   │         │
│             └──────────┘                       └──────────┘         │
│                    │                                                 │
│                    ▼                                                 │
│             ┌──────────┐                                             │
│             │  Output  │                                             │
│             │  Spike   │                                             │
│             │  Stream  │                                             │
│             └──────────┘                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Pipeline Stages

```
Stage 1: Spike Compression
    Input: Raw spike train
    Process: 16-cycle shift register creates temporal pattern
    Output: 16-bit compressed pattern

Stage 2: Pattern Matching (TPPE)
    Input: Compressed pattern + weight patterns
    Process: Parallel AND + popcount for 4 weight patterns
    Output: Matching candidates with scores

Stage 3: Event Routing
    Input: Candidates (neuron_id, score)
    Process: Route scores to target neurons
    Output: Per-neuron score streams

Stage 4: LIF Integration
    Input: Scores per neuron
    Process: Accumulate, leak, integrate
    Output: Raw spike signals

Stage 5: Output Arbitration
    Input: Multi-neuron spike requests
    Process: Round-robin fair selection
    Output: Serialized spike stream
```

---

## System Components

### 1. TPPE (Temporal Pattern Processing Engine)

The TPPE performs spike-based pattern matching using temporal sliding windows.

**Components:**
- **Spike Compressor**: Captures last 16 timesteps of input spikes
- **Pattern Matcher**: Computes intersection scores against stored weight patterns
- **Candidate FIFO**: Buffers matching results

**Operation:**
1. Incoming spikes are shifted into a 16-bit register
2. Every cycle, the current pattern is compared against 4 parallel weight patterns
3. Intersection scores (popcount of AND operation) are computed
4. Candidates exceeding the threshold are forwarded

### 2. Event Router

Routes pattern matching results to the appropriate neurons.

**Function:**
- Decodes candidate neuron_id
- Activates corresponding neuron's score_valid signal
- One-hot routing with scan synchronization

### 3. LIF Neuron Array

Array of 16 independent Leaky Integrate-and-Fire neurons.

**Per-Neuron Components:**

```
┌─────────────────────────────────────────────────────┐
│                    LIF Neuron                        │
│                                                       │
│  Score Input                                         │
│      │                                                │
│      ▼                                                │
│  ┌────────────────┐                                  │
│  │ Score          │                                  │
│  │ Accumulator    │──▶ Fast Sum                      │
│  └────────────────┘                                  │
│                                                       │
│  Vmem ──▶ ┌────────────┐                            │
│           │ Leak Unit  │──▶ Leak Value               │
│           └────────────┘                              │
│              │                                         │
│              ▼                                         │
│           ┌────────────────┐                          │
│           │ Correction     │──▶ Fractional Correction│
│           │ Accumulator    │                          │
│           └────────────────┘                          │
│                                                       │
│  ┌─────────────────────────────────────┐             │
│  │  Pseudo Accumulator (Integrator)    │             │
│  │  Vmem(t+1) = Vmem(t) + Sum - Leak - Corr │       │
│  └─────────────────────────────────────┘             │
│                │                                      │
│                ▼                                      │
│         ┌─────────────┐                              │
│         │ Threshold   │──▶ Spike Output              │
│         │ Comparator  │                              │
│         └─────────────┘                              │
└─────────────────────────────────────────────────────┘
```

**LIF Dynamics:**

The membrane voltage evolves according to:

```
V_mem(t+1) = V_mem(t) + FastSum - Leak - Correction
```

Where:
- **FastSum**: Accumulated input scores during scan window
- **Leak**: `V_mem >> LEAK_SHIFT` (division by 16)
- **Correction**: Accumulated fractional bits from leak to prevent drift

**Firing Condition:**
```
if (V_mem >= Threshold && !fired_this_scan):
    Generate spike
    Set fired flag
    Reset V_mem
```

### 4. Spike Arbitration

**Round-Robin Arbiter:**
- Ensures fair access to output channel
- Prevents starvation
- Handles multiple simultaneous spike requests
- Maintains last-granted state for fairness

**Spike FIFO per Neuron:**
- Buffers spikes when arbiter is busy
- Decouples neuron firing from output availability
- Provides backpressure protection

---

## Data Flow

### Complete Data Flow Diagram

```
Input Spike Stream (1-bit per cycle)
        │
        ▼
┌───────────────────┐
│ Spike Compressor  │  16-cycle shift register
└───────────────────┘
        │
        ▼ (16-bit pattern)
┌───────────────────┐
│ Pattern Matcher   │  Parallel 4-way matching
│  - Weight 0       │
│  - Weight 1       │
│  - Weight 2       │
│  - Weight 3       │
└───────────────────┘
        │
        ▼ (neuron_id, col_id, score)
┌───────────────────┐
│ Candidate FIFO    │  Buffering
└───────────────────┘
        │
        ▼
┌───────────────────┐
│  Event Router     │  Route to neurons
└───────────────────┘
        │
        ├─────┬─────┬─────┬───── (16 parallel paths)
        ▼     ▼     ▼     ▼
     ┌────┐┌────┐┌────┐┌────┐
     │LIF ││LIF ││LIF ││LIF │  Independent neurons
     │ 0  ││ 1  ││ 2  ││ 3  │
     └────┘└────┘└────┘└────┘
        │     │     │     │
        ▼     ▼     ▼     ▼
     ┌────┐┌────┐┌────┐┌────┐
     │FIFO││FIFO││FIFO││FIFO│  Per-neuron buffering
     └────┘└────┘└────┘└────┘
        │     │     │     │
        └─────┴─────┴─────┘
                │
                ▼
        ┌──────────────┐
        │ Round-Robin  │  Fair arbitration
        │  Arbiter     │
        └──────────────┘
                │
                ▼
    Output Spike Stream (neuron_id + valid)
```

### Timing Diagram

```
Clock    : ___┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__
Spike_In :    1     0     1     1     0     1     0     1
Pattern  : 0001  0010  0101  1011  0110  1101  1010  0101
           
Candidate:             [N0,C0,S3]      [N1,C2,S4]
           
Router   :                   N0_valid=1  N1_valid=1
           
LIF[0]   : Vmem=5   Vmem=8   Vmem=11  Vmem=12
           
Spike[0] :                                    FIRE!
           
Output   :                                         [ID=0]
```

---

## Directory Structure

```
.
├── rtl/
│   ├── interconnect/          # Routing and arbitration modules
│   │   ├── event_router.v            # Routes candidates to neurons
│   │   ├── neuron_event_fifo.v       # Per-neuron event buffering
│   │   ├── round_robin_arbiter.v     # Fair spike arbitration
│   │   ├── simple_fifo.v             # Basic FIFO primitive
│   │   └── spike_fifo.v              # Spike buffering wrapper
│   │
│   ├── lif/                   # LIF neuron implementation
│   │   ├── leak_unit.v               # Membrane leak computation
│   │   ├── lif_array.v               # Array of 16 neurons
│   │   ├── lif_neuron_top.v          # Top-level neuron wrapper
│   │   ├── p_lif.v                   # Firing logic
│   │   ├── pseudo_accumulator.v      # Membrane integrator
│   │   └── score_accumulator.v       # Input score accumulation
│   │
│   ├── top/                   # System top-level
│   │   └── TPPE_LIF_MULTI_SYSTEM_FINAL.v  # Complete system
│   │
│   └── tppe/                  # Temporal pattern matching
│       ├── bitmask_generator.v       # Activity mask generation
│       ├── input_pattern_generator.v # Pattern preprocessing
│       ├── loas_candidate_fifo.v     # Candidate buffering
│       ├── loas_inner_join_parallel.v # Parallel pattern matching
│       ├── part_a_top.v              # TPPE top-level
│       ├── pattern_matcher.v         # Single pattern matcher
│       └── spike_compressor_temporal.v # Spike compression
│
├── sim/                       # Simulation outputs
│   ├── sim.out                       # Compiled simulation
│   └── tppe_lif_system.vcd           # Waveform dump
│
└── tb/                        # Testbenches
    └── tb_TPPE_LIF_MULTI_SYSTEM_STRESS.v  # System testbench
```

---

## Module Descriptions

### TPPE Modules

#### `spike_compressor_temporal.v`
- **Purpose**: Converts spike stream into temporal pattern
- **Inputs**: `spike_in` (1-bit)
- **Outputs**: `compressed_pattern` (16-bit)
- **Function**: 16-cycle shift register

#### `pattern_matcher.v`
- **Purpose**: Computes intersection score between input and weight patterns
- **Algorithm**: `score = popcount(input_pattern & weight_pattern)`
- **Latency**: Combinational (0 cycles)

#### `loas_inner_join_parallel.v`
- **Purpose**: Parallel 4-way pattern matching with threshold filtering
- **Inputs**: spike pattern, 4 weight patterns, threshold
- **Outputs**: First matching candidate (neuron_id, col_id, score)
- **Priority**: Lowest column ID wins

#### `loas_candidate_fifo.v`
- **Purpose**: Buffers candidates before routing
- **Depth**: Configurable (default 8)
- **Protocol**: Valid/ready handshaking

#### `part_a_top.v`
- **Purpose**: TPPE top-level integration
- **Function**: Connects compressor, matcher, and FIFO

### LIF Modules

#### `score_accumulator.v`
- **Purpose**: Accumulates input scores during scan window
- **Reset Conditions**: scan_start_en
- **Behavior**: Holds accumulated value when score_valid is low

#### `leak_unit.v`
- **Purpose**: Computes membrane leak value
- **Formula**: `leak = (vmem >> LEAK_SHIFT) + 1`
- **Note**: +1 ensures guaranteed decay

#### `correction_accumulator.v`
- **Purpose**: Accumulates fractional bits lost during leak shift
- **Inputs**: Lower LEAK_SHIFT bits of vmem
- **Enable**: Only when vmem >= (1 << LEAK_SHIFT)
- **Purpose**: Prevents long-term drift in membrane voltage

#### `pseudo_accumulator.v`
- **Purpose**: Membrane voltage integrator
- **Formula**: `vmem = vmem + fast_sum - leak - correction`
- **Clamp**: Underflow protection (clamp to 0)

#### `p_lif.v`
- **Purpose**: Firing logic and spike generation
- **Behavior**: 
  - Fires when vmem >= threshold
  - One spike per scan window
  - Resets fired flag on scan_start_en

#### `lif_neuron_top.v`
- **Purpose**: Integrates all LIF components for single neuron
- **Pipeline**: score_acc → leak → correction → integrator → fire

#### `lif_array.v`
- **Purpose**: Instantiates 16 parallel LIF neurons
- **Generation**: Uses Verilog generate block
- **Includes**: Per-neuron event FIFOs

### Interconnect Modules

#### `event_router.v`
- **Purpose**: Routes candidates to appropriate neurons
- **Method**: One-hot decoding of neuron_id
- **Reset**: Clears on scan_start_en

#### `simple_fifo.v`
- **Purpose**: 1-deep FIFO primitive
- **Protocol**: Valid/ready handshaking
- **States**: Empty, full

#### `spike_fifo.v`
- **Purpose**: Buffers neuron output spikes
- **Wrapper**: Around simple_fifo for spike_id

#### `neuron_event_fifo.v`
- **Purpose**: Buffers events before LIF processing
- **Usage**: One per neuron in lif_array

#### `round_robin_arbiter.v`
- **Purpose**: Fair arbitration of 16 spike channels
- **Algorithm**: Wrapping priority starting from last granted
- **State**: Maintains last_grant register
- **Latency**: 1 cycle

### Top-Level Module

#### `TPPE_LIF_MULTI_SYSTEM_FINAL.v`
- **Purpose**: Complete system integration
- **Submodules**: 
  - part_a_top (TPPE)
  - event_router
  - lif_array
  - 16x spike_fifo
  - round_robin_arbiter
- **Additional**: Scan window generator (16-cycle counter)

---

## Getting Started

### Prerequisites

- **Icarus Verilog**: Version 10.0 or later
- **GTKWave**: For waveform viewing (optional)
- **Make**: For build automation (optional)

### Installation

```bash
# Install Icarus Verilog (Ubuntu/Debian)
sudo apt-get install iverilog

# Install GTKWave (optional)
sudo apt-get install gtkwave
```

### Building

```bash
# Compile all design files
iverilog -g2012 -o sim/sim.out \
    rtl/tppe/*.v \
    rtl/lif/*.v \
    rtl/interconnect/*.v \
    rtl/top/*.v \
    tb/tb_TPPE_LIF_MULTI_SYSTEM_STRESS.v
```

---

## Simulation

### Running Testbench

```bash
# Run simulation
vvp sim/sim.out

# View waveforms
gtkwave sim/tppe_lif_system.vcd
```

### Expected Output

```
========================================
TPPE-LIF Multi-System Testbench
========================================

Configuration:
  T_WINDOW        = 16
  PARALLEL_FACTOR = 4
  NUM_NEURONS     = 16
  VMEM_W          = 16
  LEAK_SHIFT      = 4

Thresholds:
  Neuron[0] = 20 (easy)
  Neuron[1] = 30 (medium)
  Neuron[2] = 50 (hard)

[TEST 1] Simple pattern to fire neuron 0...
>>> [SPIKE OUT] Time=215000 | Cycle=17 | Neuron ID=0 <<<
>>> [SPIKE OUT] Time=285000 | Cycle=24 | Neuron ID=0 <<<

Total spikes generated: 10
*** SUCCESS: 10 spikes generated ***
```

### Testbench Structure

The testbench (`tb_TPPE_LIF_MULTI_SYSTEM_STRESS.v`) includes:

1. **Configuration**: Sets up parameters and thresholds
2. **Test 1**: Continuous spike train targeting neuron 0
3. **Test 2**: Spike train targeting neuron 1
4. **Monitoring**: 
   - Input spikes
   - Pattern compression
   - Candidates
   - Neuron membrane voltages
   - Output spikes

### Key Signals to Monitor

```
Signal                     | Description
---------------------------|----------------------------------
spike_in                   | Input spike stream
spike_pattern              | Compressed 16-bit pattern
cand_valid                 | Candidate generated
cand_neuron/score          | Candidate details
lif_score_valid[N]         | Score delivered to neuron N
vmem[N]                    | Membrane voltage of neuron N
spike_valid/spike_id       | Output spike stream
```

---

## Parameters

### System Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `T_WINDOW` | 16 | 8-32 | Temporal window size (timesteps) |
| `PARALLEL_FACTOR` | 4 | 1-16 | Number of parallel pattern matchers |
| `NUM_NEURONS` | 16 | 1-256 | Number of LIF neurons |
| `VMEM_W` | 16 | 8-32 | Membrane voltage bit width |
| `LEAK_SHIFT` | 4 | 1-8 | Leak division factor (2^LEAK_SHIFT) |
| `CORR_W` | 8 | 4-16 | Correction accumulator width |
| `FIFO_DEPTH` | 8 | 2-64 | Candidate FIFO depth |

### Per-Neuron Configuration

| Parameter | Type | Description |
|-----------|------|-------------|
| `threshold[N]` | 16-bit | Firing threshold for neuron N |
| `neuron_id` | 4-bit | Target neuron for TPPE candidates |

### Pattern Matching

| Parameter | Type | Description |
|-----------|------|-------------|
| `weight_patterns` | 4x16-bit | Stored temporal patterns |
| `intersection_threshold` | 5-bit | Minimum score for candidate |

---

## Design Decisions

### 1. Direct Spike Output (No Output Compression Unit)

**Decision**: Remove output_compression_unit, connect LIF spikes directly to FIFOs.

**Rationale**: 
- The output_compression_unit created handshaking deadlocks
- Spike FIFOs already provide necessary buffering
- Simpler design with one less handshaking layer
- Reduced latency from neuron firing to output

### 2. Score Accumulator Behavior

**Decision**: Maintain accumulated value when score_valid is low.

**Rationale**:
- Allows scores to accumulate over multiple cycles
- Prevents loss of synaptic inputs
- Only resets on explicit scan_start_en signal

### 3. Leak Computation with +1

**Decision**: `leak = (vmem >> LEAK_SHIFT) + 1`

**Rationale**:
- Guarantees decay even for small vmem values
- Prevents vmem from getting stuck at small values
- Ensures system eventually returns to rest state

### 4. Fractional Correction Accumulator

**Decision**: Accumulate fractional bits lost during leak shift.

**Rationale**:
- Prevents long-term drift in membrane voltage
- Improves accuracy of leak computation
- Only enabled when vmem is sufficiently large

### 5. One-Spike-Per-Scan Guarantee

**Decision**: LIF neurons can fire at most once per scan window.

**Rationale**:
- Simplifies temporal credit assignment
- Prevents neuron saturation
- Matches biological refractory period
- Reduces output spike bandwidth

### 6. Round-Robin Arbitration

**Decision**: Use fair round-robin instead of fixed priority.

**Rationale**:
- Prevents neuron starvation
- Fair access to output channel
- Simple hardware implementation
- Predictable worst-case latency

---

## Known Limitations

The current implementation is functionally complete and architecturally correct, but the following limitations are intentionally present:

1. **Scan-Window-Based Firing**  
   Neuron firing is evaluated at scan boundaries rather than continuously every cycle. This simplifies timing and avoids race conditions, but limits spike timing resolution.

2. **Single Spike per Neuron per Scan Window**  
   Each neuron can emit at most one spike per scan window. This prevents burst firing and enforces a coarse refractory behavior.

3. **Static Weights (Inference Only)**  
   Pattern weights are fixed. No on-chip learning or weight adaptation is implemented in this version.

4. **Single TPPE Instance**  
   A single TPPE is shared across all neurons, limiting throughput scalability. Multi-TPPE replication is left for future work.

5. **Integer Arithmetic Model**  
   All computations use integer arithmetic. Fixed-point or higher-precision variants are not included.

These constraints are design choices made to keep the system simple, verifiable, and extensible. They do not affect correctness of the implemented architecture.


## Future Work

### 1. Fixed-Point (FxP) Version

**Objective**: Implement fixed-point arithmetic version for better precision control.

**Proposed Changes**:
- Replace integer accumulation with Q-format fixed-point
- Configurable fractional bits (e.g., Q8.8, Q12.4)
- Saturating arithmetic for overflow protection
- Rounding modes for division/shift operations

**Benefits**:
- More accurate representation of biological dynamics
- Configurable precision vs. area tradeoffs
- Better match to floating-point reference models

**Challenges**:
- Increased complexity in accumulator logic
- Need for saturation/rounding logic
- Verification against floating-point models

### 2. Multi-Layer Support

**Objective**: Extend to multiple connected LIF layers.

**Proposed Architecture**:
```
Input → TPPE → LIF Layer 0 → TPPE → LIF Layer 1 → ... → Output
```

**Requirements**:
- Layer-to-layer spike routing
- Configurable inter-layer connectivity
- Multi-layer scan synchronization

### 3. Adaptive Thresholds

**Objective**: Implement homeostatic plasticity with adaptive firing thresholds.

**Mechanism**:
- Increase threshold after spike (refractory adaptation)
- Slowly decay threshold back to baseline
- Per-neuron adaptation state

### 4. STDP Learning

**Objective**: Add Spike-Timing-Dependent Plasticity for on-chip learning.

**Components**:
- Pre/post spike timing trackers
- Weight update logic
- Learning rate configuration

### 5. AXI-Stream Interface

**Objective**: Replace custom handshaking with industry-standard AXI-Stream.

**Benefits**:
- Easier IP integration
- Standard backpressure protocol
- Compatibility with Xilinx/Intel IP

### 6. Power Optimization

**Objective**: Reduce dynamic and static power consumption.

**Techniques**:
- Clock gating for inactive neurons
- Fine-grained power domains
- Event-driven computation (only compute on spike)

### 7. Multi-Core Scaling

**Objective**: Scale to thousands of neurons with multi-core architecture.

**Approach**:
- Partition neurons across multiple cores
- Network-on-chip for inter-core routing
- Distributed arbitration

### 8. Hardware Verification

**Objective**: Formal verification of critical properties.

**Properties to Verify**:
- No spike loss under backpressure
- Fairness of arbitration
- One-spike-per-scan guarantee
- Membrane voltage bounds

---

## References

### Academic Papers

1. LoAS: Fully Temporal-Parallel Dataflow for Dual-Sparse Spiking Neural Networks
### Design Documentation

- Icarus Verilog Documentation: http://iverilog.icarus.com/
- SystemVerilog IEEE Standard 1800-2017
- Xilinx UltraScale+ Architecture: Configurable Logic Block User Guide

---


