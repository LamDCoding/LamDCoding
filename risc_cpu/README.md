# FPGA RISC-V RV32I Pipelined CPU

> A production-quality, 5-stage pipelined 32-bit RISC-V CPU implemented in Verilog,  
> designed for FPGA deployment (Xilinx Nexys 4 DDR / Intel DE10-Lite).

```
  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
  │    IF    │──▶│    ID    │──▶│    EX    │──▶│   MEM    │──▶│    WB    │
  │  Fetch   │   │  Decode  │   │ Execute  │   │  Memory  │   │ Writeback│
  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
       ↑               ↑               │                │
       └── Hazard Det ─┘   Forwarding ─┴────────────────┘
```

---

## Table of Contents

1. [Why RISC-V? — The Big Picture](#1-why-risc-v--the-big-picture)
2. [Project Structure](#2-project-structure)
3. [Quick Start](#3-quick-start)
4. [Architecture Deep Dive](#4-architecture-deep-dive)
   - [4.1 Instruction Set Architecture (ISA)](#41-instruction-set-architecture-isa)
   - [4.2 Instruction Encoding](#42-instruction-encoding)
   - [4.3 The 5-Stage Pipeline](#43-the-5-stage-pipeline)
   - [4.4 ALU — The Math Engine](#44-alu--the-math-engine)
   - [4.5 Register File](#45-register-file)
   - [4.6 Control Unit](#46-control-unit)
   - [4.7 Immediate Generator](#47-immediate-generator)
   - [4.8 Pipeline Registers](#48-pipeline-registers)
   - [4.9 Data Hazards & Forwarding](#49-data-hazards--forwarding)
   - [4.10 Load-Use Stall](#410-load-use-stall)
   - [4.11 Control Hazards & Branch Predictor](#411-control-hazards--branch-predictor)
   - [4.12 Memory Subsystem](#412-memory-subsystem)
   - [4.13 Peripherals — UART TX & GPIO](#413-peripherals--uart-tx--gpio)
   - [4.14 Top-Level Integration](#414-top-level-integration)
5. [Simulation & Testing](#5-simulation--testing)
6. [Programming the CPU — The Assembler](#6-programming-the-cpu--the-assembler)
7. [FPGA Deployment](#7-fpga-deployment)
   - [7.1 Xilinx Nexys 4 DDR (Vivado)](#71-xilinx-nexys-4-ddr-vivado)
   - [7.2 Intel DE10-Lite (Quartus)](#72-intel-de10-lite-quartus)
8. [Performance & Area Estimates](#8-performance--area-estimates)
9. [Extending the CPU](#9-extending-the-cpu)
10. [Glossary](#10-glossary)

---

## 1. Why RISC-V? — The Big Picture

Before touching a line of Verilog, it's worth understanding *why* this project matters to companies like AMD, Intel, and Qualcomm.

### RISC vs. CISC

| Property | RISC (e.g., RISC-V, ARM) | CISC (e.g., x86) |
|---|---|---|
| Instruction size | Fixed (32 bits) | Variable (1–15 bytes) |
| Instructions per cycle | ~1 | < 1 (complex decode) |
| Memory access | Load/Store only | Many instructions access memory |
| Pipeline friendly | ✅ Yes — simple decode | Requires micro-op translation |
| Hardware complexity | Simple | Very complex |

**RISC-V** is the open-source instruction set architecture (ISA) that has taken the industry by storm. SiFive, Western Digital, NVIDIA, Google, and many others use RISC-V cores in production silicon. By building one from scratch you will understand:

- How a CPU fetches, decodes, and executes instructions every clock cycle
- Why pipelining multiplies throughput
- How data and control hazards arise and how hardware solves them in nanoseconds
- How peripherals like UART and GPIO map to memory addresses
- How RTL (Register Transfer Level) code becomes real FPGA gates or silicon

---

## 2. Project Structure

```
risc_cpu/
├── src/
│   ├── core/                   ← The "brain" of the CPU
│   │   ├── alu.v               ← 32-bit Arithmetic Logic Unit
│   │   ├── register_file.v     ← 32 × 32-bit register file
│   │   ├── control_unit.v      ← Opcode → control signals decoder
│   │   ├── alu_decoder.v       ← funct3/funct7 → ALU operation
│   │   ├── immediate_gen.v     ← Sign-extend immediates
│   │   ├── forwarding_unit.v   ← Data hazard bypass paths
│   │   ├── hazard_detection.v  ← Load-use stall + branch flush
│   │   └── branch_predictor.v  ← 2-bit saturating counter BHT
│   ├── pipeline/               ← Inter-stage registers
│   │   ├── if_id_reg.v         ← IF → ID latch
│   │   ├── id_ex_reg.v         ← ID → EX latch
│   │   ├── ex_mem_reg.v        ← EX → MEM latch
│   │   └── mem_wb_reg.v        ← MEM → WB latch
│   ├── memory/                 ← FPGA-friendly memory models
│   │   ├── instr_mem.v         ← Instruction ROM (1K × 32-bit)
│   │   └── data_mem.v          ← Data RAM, byte-addressable (4 KB)
│   ├── peripherals/            ← I/O devices
│   │   ├── uart_tx.v           ← 8N1 UART transmitter
│   │   └── gpio.v              ← 16-bit LED/switch I/O
│   └── cpu_top.v               ← Top-level integration module
├── tb/                         ← Testbenches (simulation only)
│   ├── tb_alu.v                ← 32 ALU operation tests
│   ├── tb_register_file.v      ← 12 register file tests
│   ├── tb_control_unit.v       ← 10 opcode decode tests
│   ├── tb_hazard_forwarding.v  ← 15 hazard/forwarding tests
│   ├── tb_cpu_top.v            ← 7 full pipeline integration tests
│   └── tb_cpu_prog.hex         ← Test program (ADD/SW/LW/BEQ)
├── programs/                   ← Pre-assembled programs
│   ├── fibonacci.hex           ← First 10 Fibonacci numbers
│   ├── bubble_sort.hex         ← Sort 8 integers
│   └── led_blink.hex           ← Blink FPGA LEDs
├── assembler/
│   ├── assembler.py            ← Full RV32I assembler in Python
│   └── programs/
│       ├── fibonacci.asm
│       ├── bubble_sort.asm
│       └── led_blink.asm
├── constraints/
│   ├── nexys4ddr.xdc           ← Xilinx Nexys 4 DDR pin constraints
│   └── de10_lite.sdc           ← Intel DE10-Lite timing constraints
└── Makefile                    ← Build & simulate with iverilog
```

---

## 3. Quick Start

### Prerequisites

```bash
# Linux / WSL
sudo apt-get install -y iverilog    # Icarus Verilog simulator
sudo apt-get install -y gtkwave     # Waveform viewer (optional)
python3 --version                   # Python 3.8+ for assembler
```

### Run All Tests

```bash
cd risc_cpu/
make all
```

Expected output:
```
=== Simulating ALU ===
ALU TB: 32 PASS, 0 FAIL — ALL ALU TESTS PASSED
=== Simulating Register File ===
RegFile TB: 12 PASS, 0 FAIL — ALL REGISTER FILE TESTS PASSED
=== Simulating Control Unit ===
CtrlUnit TB: 10 PASS, 0 FAIL — ALL CONTROL UNIT TESTS PASSED
=== Simulating Hazard/Forwarding Units ===
Hazard+Fwd TB: 15 PASS, 0 FAIL — ALL HAZARD/FORWARDING TESTS PASSED
=== Simulating Full CPU ===
CPU Top TB: 7 PASS, 0 FAIL after 201 cycles — ALL CPU INTEGRATION TESTS PASSED
```

### Assemble and Run a Program

```bash
# Assemble Fibonacci program
python3 assembler/assembler.py assembler/programs/fibonacci.asm programs/fibonacci.hex

# View result (hex words)
cat programs/fibonacci.hex

# Copy it as the CPU test image, then simulate
cp programs/fibonacci.hex tb/tb_cpu_prog.hex
make sim_cpu
```

### View Waveforms

```bash
make sim_cpu         # generates tb_cpu_top.vcd
gtkwave tb_cpu_top.vcd
```

---

## 4. Architecture Deep Dive

This section builds your understanding from the ground up, one concept at a time.

---

### 4.1 Instruction Set Architecture (ISA)

An ISA is the **contract between software and hardware**. It defines what instructions a CPU can execute. Think of it as the CPU's "API".

This CPU implements **RISC-V RV32I** — the base 32-bit integer instruction set. Every instruction is exactly **32 bits wide** (one 32-bit word).

#### The 47 RV32I Instructions

| Category | Instructions | Operation |
|---|---|---|
| **Arithmetic** | ADD, ADDI, SUB | Integer add/subtract |
| **Logical** | AND, ANDI, OR, ORI, XOR, XORI | Bitwise operations |
| **Shift** | SLL, SLLI, SRL, SRLI, SRA, SRAI | Left/right shift (logical & arithmetic) |
| **Compare** | SLT, SLTI, SLTU, SLTIU | Set-if-less-than (signed & unsigned) |
| **Upper imm** | LUI, AUIPC | Load 20-bit upper immediate |
| **Loads** | LW, LH, LB, LHU, LBU | Load word/halfword/byte from memory |
| **Stores** | SW, SH, SB | Store word/halfword/byte to memory |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU | Conditional branch |
| **Jump** | JAL, JALR | Unconditional jump + link |

---

### 4.2 Instruction Encoding

RISC-V defines **6 instruction formats**. The position of `rs1`, `rs2`, `rd`, `funct3`, and `funct7` is almost always in the same bit positions — this is a deliberate choice to simplify hardware decode.

```
 31        25 24     20 19     15 14  12 11      7 6       0
┌───────────┬─────────┬─────────┬──────┬─────────┬─────────┐
│  funct7   │   rs2   │   rs1   │funct3│   rd    │ opcode  │  R-type
├───────────┴─────────┼─────────┼──────┼─────────┼─────────┤
│       imm[11:0]     │   rs1   │funct3│   rd    │ opcode  │  I-type
├──────────┬──────────┼─────────┼──────┼─────────┼─────────┤
│imm[11:5] │   rs2   │   rs1   │funct3│imm[4:0] │ opcode  │  S-type
├──────────┴──────────┼─────────┼──────┼─────────┼─────────┤
│    imm[12|10:5]     │   rs1   │funct3│imm[4:1|11]│opcode │  B-type
├─────────────────────┴─────────┴──────┼─────────┼─────────┤
│              imm[31:12]              │   rd    │ opcode  │  U-type
├──────────────────────────────────────┴─────────┼─────────┤
│         imm[20|10:1|11|19:12]        │   rd    │ opcode  │  J-type
└─────────────────────────────────────────────────┴─────────┘
```

Key **opcode** values:

| Opcode (binary) | Instruction type |
|---|---|
| `0110011` | R-type (ADD, SUB, AND …) |
| `0010011` | I-type arithmetic (ADDI, ANDI …) |
| `0000011` | Load (LW, LH, LB …) |
| `0100011` | Store (SW, SH, SB) |
| `1100011` | Branch (BEQ, BNE …) |
| `1101111` | JAL |
| `1100111` | JALR |
| `0110111` | LUI |
| `0010111` | AUIPC |

---

### 4.3 The 5-Stage Pipeline

A **pipeline** is like an assembly line. Instead of completing one instruction before starting the next, multiple instructions are in different stages simultaneously. This multiplies throughput.

```
Clock cycle:    1    2    3    4    5    6    7    8
Instr 1:       [IF] [ID] [EX] [MEM][WB]
Instr 2:            [IF] [ID] [EX] [MEM][WB]
Instr 3:                 [IF] [ID] [EX] [MEM][WB]
Instr 4:                      [IF] [ID] [EX] [MEM][WB]
```

After filling the pipeline (cycle 5+), we complete **1 instruction per clock cycle** — this is called 1 IPC (Instructions Per Cycle), compared to 5 cycles per instruction without pipelining.

#### The 5 Stages

| Stage | Module | Work Done |
|---|---|---|
| **IF** — Instruction Fetch | `instr_mem.v` | Read 32-bit instruction at PC address; PC ← PC + 4 |
| **ID** — Instruction Decode | `control_unit.v`, `register_file.v`, `immediate_gen.v` | Decode opcode, read rs1/rs2, generate immediate |
| **EX** — Execute | `alu.v`, `alu_decoder.v`, `forwarding_unit.v` | Perform ALU operation; compute branch target; evaluate branch condition |
| **MEM** — Memory | `data_mem.v` | Load from or store to data memory |
| **WB** — Write Back | `register_file.v` | Write result back to destination register rd |

Between each pair of stages sits a **pipeline register** (a set of flip-flops) that captures the outputs of one stage and holds them stable for the next stage to read.

---

### 4.4 ALU — The Math Engine

The ALU (`src/core/alu.v`) is the computational heart of the CPU. It takes two 32-bit operands and a 4-bit control signal, and produces a 32-bit result plus status flags.

#### ALU Control Encoding

| `alu_ctrl[3:0]` | Operation | Description |
|---|---|---|
| `0000` | ADD | `a + b` |
| `0001` | SUB | `a - b` |
| `0010` | AND | `a & b` |
| `0011` | OR  | `a \| b` |
| `0100` | XOR | `a ^ b` |
| `0101` | SLL | `a << b[4:0]` (logical left shift) |
| `0110` | SRL | `a >> b[4:0]` (logical right shift) |
| `0111` | SRA | `a >>> b[4:0]` (arithmetic right shift — preserves sign) |
| `1000` | SLT | `$signed(a) < $signed(b) ? 1 : 0` |
| `1001` | SLTU | `a < b ? 1 : 0` (unsigned comparison) |
| `1010` | PASSB | `b` (passes immediate through — used by LUI) |
| `1011` | AUIPC | `a + b` (same as ADD, used for PC-relative addressing) |

#### Status Flags

| Flag | Meaning | Used by |
|---|---|---|
| `zero` | Result == 0 | BEQ, BNE (combined with branch logic) |
| `negative` | Result[31] == 1 | Signed comparisons |
| `overflow` | Signed overflow occurred | Debugging, optional traps |
| `carry_out` | Unsigned carry/borrow | SLTU, debugging |

**Arithmetic right shift (SRA)** is important for signed integers. When you shift a negative number right, the sign bit is replicated (not filled with 0). In Verilog:
```verilog
result = $signed(a) >>> b[4:0];   // SRA — sign bit extended
result = a >> b[4:0];              // SRL — zero extended
```

---

### 4.5 Register File

The register file (`src/core/register_file.v`) holds the CPU's **32 general-purpose registers**, each 32 bits wide. In RISC-V these are named `x0` through `x31`.

#### Key Properties

- **x0 is hardwired to 0** — writes to x0 are silently discarded. This simplifies instruction encoding (e.g., `ADD x0, x1, x2` is a no-op).
- **Two asynchronous read ports** — both `rs1` and `rs2` can be read in the same cycle with no delay.
- **One synchronous write port** — `rd` is written on the rising clock edge at the end of WB.

#### RISC-V Register ABI (Application Binary Interface)

| Register | ABI Name | Conventional Use |
|---|---|---|
| x0 | zero | Always 0 |
| x1 | ra | Return address |
| x2 | sp | Stack pointer |
| x3 | gp | Global pointer |
| x4 | tp | Thread pointer |
| x5–x7 | t0–t2 | Temporaries |
| x8–x9 | s0–s1 | Saved registers |
| x10–x11 | a0–a1 | Function arguments / return values |
| x12–x17 | a2–a7 | Function arguments |
| x18–x27 | s2–s11 | Saved registers |
| x28–x31 | t3–t6 | Temporaries |

---

### 4.6 Control Unit

The control unit (`src/core/control_unit.v`) is a **pure combinational decoder**: it reads the 7-bit opcode and outputs a set of control signals that tell every other module what to do this cycle.

#### Control Signals

| Signal | Width | Meaning |
|---|---|---|
| `reg_write` | 1 | Write to register file in WB |
| `mem_read` | 1 | Read from data memory (Load) |
| `mem_write` | 1 | Write to data memory (Store) |
| `mem_to_reg[1:0]` | 2 | WB mux: `00`=ALU result, `01`=mem data, `10`=PC+4, `11`=immediate |
| `alu_src` | 1 | ALU operand B: `0`=rs2, `1`=immediate |
| `branch` | 1 | This is a branch instruction |
| `jump` | 1 | This is a JAL (unconditional jump) |
| `jalr` | 1 | This is a JALR |
| `alu_op[1:0]` | 2 | ALU decoder hint: `00`=add, `01`=sub, `10`=R-type, `11`=I-type |

The `alu_op` signal feeds the **ALU Decoder** (`src/core/alu_decoder.v`), which uses `alu_op + funct3 + funct7[5]` to produce the final 4-bit `alu_ctrl` for the ALU.

---

### 4.7 Immediate Generator

Immediates are constants encoded directly inside the instruction word. Because different instruction formats scatter the immediate bits in different positions (to keep `rs1`, `rs2`, `rd` in fixed locations), the **Immediate Generator** (`src/core/immediate_gen.v`) reassembles and **sign-extends** them to 32 bits.

```
I-type: instr[31:20]                         → sign-extend to 32 bits
S-type: {instr[31:25], instr[11:7]}          → sign-extend to 32 bits
B-type: {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}  → ×2
U-type: {instr[31:12], 12'b0}               → already 32 bits (upper 20)
J-type: {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0} → ×2
```

The `1'b0` appended to B-type and J-type immediates ensures branch/jump targets are always **2-byte aligned** (the LSB of a RISC-V PC is always 0 for 32-bit instructions).

---

### 4.8 Pipeline Registers

Each pipeline register is a set of D flip-flops that captures the outputs of one stage at the clock edge, creating a stable snapshot for the next stage. They carry **both data and control signals** forward.

```verilog
// Simplified: ID/EX pipeline register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        // Insert a "bubble" (NOP) — all control signals = 0
        id_ex_reg_write  <= 1'b0;
        id_ex_mem_read   <= 1'b0;
        // ...
    end else if (!stall) begin
        id_ex_pc         <= if_id_pc;
        id_ex_rs1_data   <= rs1_data;
        id_ex_rs2_data   <= rs2_data;
        id_ex_imm        <= imm;
        id_ex_reg_write  <= reg_write;
        // ...
    end
    // If stall: hold current values (do nothing)
end
```

Key behaviors:
- **`rst_n`**: Active-low synchronous reset — clears all registers to 0.
- **`flush`**: Overrides the register with zeros (a "bubble" or NOP) — used to cancel in-flight instructions on a taken branch.
- **`stall`**: Holds the current values — used during a load-use hazard to wait one cycle.

---

### 4.9 Data Hazards & Forwarding

#### The Problem

A **data hazard** occurs when an instruction needs the result of a previous instruction that hasn't been written back yet.

```asm
ADD  x3, x1, x2    # x3 = x1 + x2  (result written in WB, 2 cycles later)
SUB  x4, x3, x5    # NEEDS x3!  — data hazard
```

Without forwarding, we'd need to stall 2 cycles between these instructions.

#### The Solution: Forwarding (Bypass)

The Forwarding Unit (`src/core/forwarding_unit.v`) detects that the ALU result from a *later* pipeline stage can be **forwarded directly** to the ALU input of the current EX stage — bypassing the register file.

```
        EX/MEM Register    MEM/WB Register
              │                  │
              ▼                  ▼
ALU operand ──┤◄─ forward_a=10  ─┤◄─ forward_a=01
              │                  │
              └──────────────────┴──── forward_a=00 (use register file)
```

| `forward_a[1:0]` | ALU Operand A Source |
|---|---|
| `00` | Register file (rs1) — no hazard |
| `10` | EX/MEM ALU result (1-cycle-old) |
| `01` | MEM/WB result (2-cycles-old) |

The same logic applies to `forward_b` (operand B / rs2).

**Forwarding condition** (EX/MEM → EX):
```verilog
if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs1)
    forward_a = 2'b10;
```

---

### 4.10 Load-Use Stall

Forwarding solves most data hazards, but one case cannot be forwarded: a **load immediately followed by a use**.

```asm
LW  x3, 0(x1)    # Memory data won't be available until end of MEM stage
ADD x4, x3, x5   # Needs x3 at start of EX — one cycle too early!
```

The Hazard Detection Unit (`src/core/hazard_detection.v`) detects this and injects a **one-cycle stall**:
1. **PC** is held (not incremented)
2. **IF/ID register** is held (instruction not consumed)
3. **ID/EX register** is cleared to a NOP (bubble inserted)

```
Clock:  1    2    3    4    5    6    7
LW:    [IF] [ID] [EX] [MEM][WB]
        stall: ──────────────────▶
ADD:        [IF] [ID] [--] [EX] [MEM][WB]
                       ↑ bubble
```

---

### 4.11 Control Hazards & Branch Predictor

#### The Problem

When the CPU fetches a branch instruction, it doesn't know whether the branch will be taken until the EX stage (3 cycles later). By then, it has already fetched 2 instructions after the branch that may be wrong.

#### Static Flush Strategy

This CPU resolves branches in the **EX stage** and uses a **flush** strategy: if the branch is taken, the two wrongly-fetched instructions in IF and ID are flushed (turned into bubbles).

```
Clock:  1    2    3    4    5    6
BEQ:   [IF] [ID] [EX] [MEM][WB]
Instr2:     [IF] [ID]  ← FLUSH (bubble) if branch taken
Instr3:          [IF]  ← FLUSH (bubble) if branch taken
Target:               [IF] [ID] [EX]...
```

**Penalty**: 2 cycles per taken branch.

#### 2-Bit Saturating Counter Branch Predictor

To reduce branch penalties, the **Branch Predictor** (`src/core/branch_predictor.v`) predicts whether a branch will be taken *before* reaching the EX stage, using a **Branch History Table (BHT)**.

```
States:  SN (Strongly Not-taken) ──▶ WN (Weakly Not-taken) ──▶ WT (Weakly Taken) ──▶ ST (Strongly Taken)
         00                          01                          10                    11

Taken branch:   state moves RIGHT (toward ST)
Not-taken:      state moves LEFT  (toward SN)
```

The BHT has **16 entries**, indexed by `PC[5:2]` (4 bits of the branch PC). Each entry is a 2-bit saturating counter. If the prediction was wrong, the pipeline is flushed and the counter is updated toward the correct direction.

Typical branch predictor accuracy for loops: **>90%** (loop-back branches are almost always taken).

---

### 4.12 Memory Subsystem

#### Instruction Memory (`src/memory/instr_mem.v`)

- **1024 words × 32 bits = 4 KB** of instruction ROM
- Initialized from a `.hex` file using `$readmemh`
- Synchronous read (registered output, 1-cycle latency)
- On FPGA: implemented as Block RAM (BRAM)

```verilog
// In cpu_top.v, change the program:
instr_mem #(.HEX_FILE("programs/fibonacci.hex")) imem (...)
```

#### Data Memory (`src/memory/data_mem.v`)

- **4096 bytes = 4 KB** byte-addressable RAM
- Supports byte (`LB`/`SB`), halfword (`LH`/`SH`), and word (`LW`/`SW`) accesses
- Sign- and zero-extension on loads (controlled by `funct3`)

```
funct3 for loads:
  000 = LB  → sign-extend byte
  001 = LH  → sign-extend halfword
  010 = LW  → full 32-bit word
  100 = LBU → zero-extend byte
  101 = LHU → zero-extend halfword
```

#### Memory Map

| Address Range | Device |
|---|---|
| `0x0000_0000` – `0x0000_0FFF` | Data RAM (4 KB) |
| `0x1000_0000` | GPIO base register |
| `0x2000_0000` | UART TX data register |

---

### 4.13 Peripherals — UART TX & GPIO

#### UART TX (`src/peripherals/uart_tx.v`)

UART (Universal Asynchronous Receiver/Transmitter) is the simplest serial communication protocol. This core implements **8N1** format:
- 1 start bit (low)
- 8 data bits (LSB first)
- 1 stop bit (high)

```
IDLE:  ───────────┐
START: low 1 bit  │
DATA:  8 bits     └─┐ bit0 ┐ bit1 ┐ ... ┐ bit7
STOP:  high 1 bit                         └─────────
```

The `CLKS_PER_BIT` parameter sets the baud rate: for a 100 MHz clock and 115200 baud, `CLKS_PER_BIT = 100_000_000 / 115_200 ≈ 868`.

Writing any value to address `0x2000_0000` transmits that byte over UART. This is how you can **printf-debug your CPU programs** over USB to a terminal.

#### GPIO (`src/peripherals/gpio.v`)

- **16-bit output register** → drives FPGA LEDs
- **16-bit input** → reads FPGA slide switches
- Write `0x1000_0000` to set LED pattern (e.g., `SW 0x00FF, 0(gp)` turns on lower 8 LEDs)

---

### 4.14 Top-Level Integration

`src/cpu_top.v` wires all the modules together. Here's a simplified view of the datapath:

```
                     ┌──────────────────────────────────────────────┐
                     │                  Hazard Detection             │
                     │         (stall, flush_if, flush_id)           │
                     └──┬───────────────────┬────────────────────────┘
                        │                   │
  ┌─────┐   ┌────────┐  │  ┌─────────────┐  │  ┌───────────────┐
  │ PC  │──▶│  IMEM  │──┴─▶│   IF/ID     │──┴─▶│    ID/EX      │
  └──▲──┘   └────────┘     │  Register   │     │   Register    │──▶┐
     │                     └─────────────┘     └───────────────┘   │
     │                           │                    │             │
     │                     ┌─────┴──────┐       ┌────┴────┐        │
     │                     │  Control   │       │Fwd Unit │        │
     │                     │   Unit     │       └────┬────┘        │
     │                     └─────┬──────┘            │             │
     │                     ┌─────┴──────┐       ┌────▼────┐        │
     │                     │  Reg File  │       │   ALU   │        │
     │                     └────────────┘       └────┬────┘        │
     │                                               │             │
     │                                        ┌──────▼──────┐     │
     │                                        │   EX/MEM    │◀────┘
     │                                        │  Register   │
     │                                        └──────┬──────┘
     │                                               │
     │    ┌────────────────────────────────────┐     │
     │    │         Branch Predictor           │─────┘
     │    └────────────────────────────────────┘
     │                                        ┌──────▼──────┐
     │                                        │    DMEM     │
     │                                        └──────┬──────┘
     │                                        ┌──────▼──────┐
     └────────────────────────────────────────│   MEM/WB    │
          (PC mux: PC+4, branch, jump)        │  Register   │
                                              └──────┬──────┘
                                                     │ WB mux
                                              ┌──────▼──────┐
                                              │  Reg File   │
                                              │   (write)   │
                                              └─────────────┘
```

---

## 5. Simulation & Testing

The test strategy follows **unit → integration**: verify each module in isolation before testing them together.

### Running Individual Tests

```bash
make sim_alu      # 32 ALU operation tests
make sim_regfile  # 12 register file tests
make sim_ctrl     # 10 control unit decode tests
make sim_hazard   # 15 forwarding + hazard tests
make sim_cpu      # 7 full pipeline integration tests
make all          # Run all 74 tests
```

### Test Summary

| Testbench | Module Under Test | Tests |
|---|---|---|
| `tb_alu.v` | `alu.v` | ADD/SUB edge cases, all shifts, SLT/SLTU, flags |
| `tb_register_file.v` | `register_file.v` | x0=0, dual-port, write-enable, sequential writes |
| `tb_control_unit.v` | `control_unit.v` | All 9 valid opcodes + invalid opcode default |
| `tb_hazard_forwarding.v` | `forwarding_unit.v`, `hazard_detection.v` | All forward cases, load-use, branch flush, combined |
| `tb_cpu_top.v` | `cpu_top.v` (all modules) | ADDI, ADD, SW, LW, BEQ over 201 pipeline cycles |

### Viewing Waveforms

After `make sim_cpu`, a file `tb_cpu_top.vcd` is generated. Open it in GTKWave:

```bash
gtkwave tb_cpu_top.vcd
```

In GTKWave, search for and add these signals:
- `clk`, `rst_n` — clock and reset
- `dbg_pc` — program counter (should increment by 4 each cycle, or hold on stall)
- `if_id_instr` — instruction in ID stage
- `id_ex_alu_result` (in EX stage)
- `gpio_out` — LED output

---

## 6. Programming the CPU — The Assembler

The Python assembler (`assembler/assembler.py`) converts RISC-V assembly source code into hex files loadable by the instruction memory.

### Supported Instructions

All 47 RV32I instructions, plus these **pseudo-instructions**:

| Pseudo | Expands to | Description |
|---|---|---|
| `NOP` | `ADDI x0, x0, 0` | No operation |
| `MV rd, rs` | `ADDI rd, rs, 0` | Copy register |
| `LI rd, imm` | `ADDI rd, x0, imm` | Load small immediate |
| `J offset` | `JAL x0, offset` | Unconditional jump (discard link) |
| `RET` | `JALR x0, x1, 0` | Return from function |
| `BEQZ rs, lbl` | `BEQ rs, x0, lbl` | Branch if zero |
| `BNEZ rs, lbl` | `BNE rs, x0, lbl` | Branch if non-zero |
| `NOT rd, rs` | `XORI rd, rs, -1` | Bitwise NOT |
| `NEG rd, rs` | `SUB rd, x0, rs` | Negate |

### Usage

```bash
# Assemble a single file
python3 assembler/assembler.py input.asm output.hex

# Assemble all programs
make assemble
```

### Assembly Example — Fibonacci

```asm
# fibonacci.asm — Compute first 10 Fibonacci numbers
        addi  x4, x0, 512       # base address = 0x200
        addi  x1, x0, 0         # fib(0) = 0
        addi  x2, x0, 1         # fib(1) = 1
        sw    x1, 0(x4)         # store fib(0)
        sw    x2, 4(x4)         # store fib(1)
        addi  x5, x0, 2         # loop counter i = 2
        addi  x6, x0, 10        # loop limit = 10
loop:
        add   x3, x1, x2        # fib(i) = fib(i-2) + fib(i-1)
        slli  x7, x5, 2         # byte offset = i * 4
        add   x8, x4, x7        # address = base + offset
        sw    x3, 0(x8)         # store result
        mv    x1, x2            # advance: fib(n-2) ← fib(n-1)
        mv    x2, x3            # advance: fib(n-1) ← fib(n)
        addi  x5, x5, 1         # i++
        blt   x5, x6, loop      # if i < 10, loop again
done:
        nop
```

Assemble and check output:
```bash
python3 assembler/assembler.py assembler/programs/fibonacci.asm /tmp/fib.hex
cat /tmp/fib.hex
# 00000093  ← addi x1, x0, 0  (actually: addi x4, x0, 512 first)
# ...
```

---

## 7. FPGA Deployment

### 7.1 Xilinx Nexys 4 DDR (Vivado)

**Board specs:** Artix-7 XC7A100T, 100 MHz oscillator, 16 switches, 16 LEDs, USB-UART bridge.

#### Step 1 — Create a Vivado Project

1. Open **Vivado 2020.x** or later
2. Create a new **RTL Project** named `riscv_cpu`
3. Add all files from `src/` (Core, Pipeline, Memory, Peripherals, `cpu_top.v`)
4. Add constraints: `constraints/nexys4ddr.xdc`
5. Set top module to `cpu_top`

#### Step 2 — Configure Parameters

In the constraint file, or by editing `cpu_top.v` instantiation:
```verilog
cpu_top #(
    .IMEM_HEX("programs/fibonacci.hex"),
    .UART_BPS(868)        // 100 MHz / 115200 baud ≈ 868
) u_cpu (
    .clk       (CLK100MHZ),
    .rst_n     (CPU_RESETN),
    .gpio_out  (LED),
    .gpio_in   ({8'b0, SW}),
    .uart_tx_pin(UART_TXD_IN)
);
```

#### Step 3 — Run Implementation

```
Flow Navigator → Run Synthesis → Run Implementation → Generate Bitstream
```

#### Step 4 — Program the FPGA

```
Open Hardware Manager → Auto Connect → Program Device → select .bit file
```

#### Step 5 — Observe Output

- The LEDs show `gpio_out[15:0]` — run `led_blink.hex` to see them toggle
- Connect a USB-UART terminal (PuTTY, minicom) at **115200 baud** to see UART output

---

### 7.2 Intel DE10-Lite (Quartus)

**Board specs:** MAX 10 10M50DAF484C7G, 50 MHz oscillator, 10 LEDs, 10 switches.

#### Step 1 — Create a Quartus Project

1. Open **Quartus Prime 20.x** or later
2. Create new project for device `10M50DAF484C7G`
3. Add all `src/` files
4. Add `constraints/de10_lite.sdc` for timing constraints
5. Set `cpu_top` as the top-level entity

#### Step 2 — Adjust Clock Parameter

The DE10-Lite runs at **50 MHz**, so update the UART divisor:
```verilog
.UART_BPS(434)        // 50 MHz / 115200 ≈ 434
```

#### Step 3 — Pin Assignment

Open **Pin Planner** and assign (or use the provided `.sdc`):
- `clk` → `P11` (50 MHz MAX10 clock)
- `rst_n` → `B8` (KEY0)
- `gpio_out[9:0]` → LED pins
- `gpio_in[9:0]` → SW pins
- `uart_tx_pin` → `V10` (UART TX to FTDI)

#### Step 4 — Compile and Program

```
Processing → Start Compilation
```

Then use **Programmer** to upload the `.sof` file.

---

## 8. Performance & Area Estimates

### Timing (Synthesis estimates)

| FPGA Family | Achievable Fmax | CPI (avg) |
|---|---|---|
| Xilinx Artix-7 (Nexys 4) | ~120 MHz | ~1.1 |
| Intel MAX 10 (DE10-Lite) | ~90 MHz | ~1.1 |
| Xilinx Kintex-7 | ~180 MHz | ~1.1 |

**Average CPI of ~1.1** means approximately 10% overhead from stalls (load-use stalls and branch mispredictions).

### Area (Approximate)

| Resource | Artix-7 Usage | % of XC7A100T |
|---|---|---|
| LUTs | ~4,500 | ~9% |
| FFs (Flip-Flops) | ~2,200 | ~2% |
| BRAMs (36K) | 2 | ~1% |
| DSPs | 0 | 0% |

The CPU uses **only LUTs, FFs, and BRAMs** — no DSP blocks — keeping it portable across any FPGA family.

---

## 9. Extending the CPU

This project is designed as a solid foundation. Here are natural next steps:

### Beginner Extensions
- **RV32M** — Multiply/Divide extension (`MUL`, `DIV`, `REM`) — add a multi-cycle multiplier in EX
- **More GPIO** — Add a 7-segment display controller
- **Timer peripheral** — Memory-mapped countdown timer with interrupt

### Intermediate Extensions
- **Interrupt controller** — Add CSRs (`mtvec`, `mepc`, `mcause`) and trap handling
- **I-cache** — Add a direct-mapped instruction cache to hide memory latency
- **Branch delay slot** — Change to a 1-slot delay architecture (like MIPS classic)
- **UART RX** — Complete the UART with a receive path

### Advanced Extensions
- **RV32F** — Single-precision floating point (adds 32 FP registers, FPU)
- **Out-of-order execution** — Tomasulo's algorithm with a reorder buffer (ROB)
- **Superscalar** — Fetch and issue 2 instructions per cycle
- **AXI4-Lite bus** — Replace memory-mapped I/O with an industry-standard bus (used in Xilinx IPs)
- **Cache hierarchy** — L1 I$+D$ + L2 unified cache with write-back and LRU replacement

---

## 10. Glossary

| Term | Definition |
|---|---|
| **ALU** | Arithmetic Logic Unit — performs integer arithmetic and logic operations |
| **ABI** | Application Binary Interface — convention for register usage across function calls |
| **BHT** | Branch History Table — table of per-branch prediction counters |
| **BRAM** | Block RAM — dedicated hard memory blocks on an FPGA |
| **CPI** | Cycles Per Instruction — lower is better; ideal pipeline = 1.0 |
| **CSR** | Control and Status Register — special registers for interrupt/privilege control |
| **Fmax** | Maximum clock frequency achievable after placement and routing |
| **FF** | Flip-Flop — 1-bit storage element clocked on a clock edge |
| **Forwarding** | Bypassing the register file to deliver a result directly to a waiting consumer |
| **Hazard** | A condition that prevents the next pipeline stage from proceeding correctly |
| **ISA** | Instruction Set Architecture — the programmer-visible interface of the CPU |
| **IPC** | Instructions Per Cycle — higher is better; a 5-stage pipeline targets 1.0 |
| **LUT** | Look-Up Table — the basic programmable logic cell of an FPGA |
| **RISC** | Reduced Instruction Set Computer — simple, fixed-size instructions, load/store memory model |
| **RTL** | Register Transfer Level — hardware description at the flip-flop level (Verilog/VHDL) |
| **RV32I** | RISC-V base 32-bit integer instruction set |
| **Sign-extend** | Replicate the sign bit (MSB) to fill wider bit widths |
| **Stall** | Pause the pipeline by holding PC and IF/ID and inserting a bubble into ID/EX |
| **UART** | Universal Asynchronous Receiver/Transmitter — simple serial communication protocol |
| **VCD** | Value Change Dump — waveform file format read by GTKWave |

---

*Built by Derrick Lam — Computer Hardware Engineering, Toronto Metropolitan University*  
*Designed for FPGA deployment on Xilinx Nexys 4 DDR and Intel DE10-Lite*
