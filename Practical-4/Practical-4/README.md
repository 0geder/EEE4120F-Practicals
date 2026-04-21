# Practical 4: StarCore-1: Single-Cycle Processor in Verilog

## Overview

Practical 4 involves implementing a complete single-cycle processor called **StarCore-1** using Verilog. You will build the processor incrementally across **8 tasks**, starting from individual components and finishing with the fully integrated CPU.

The practical uses **Icarus Verilog** for simulation and **GTKWave** for waveform inspection.

---

## Problem Description

### StarCore-1 Processor Architecture

StarCore-1 is a 16-bit single-cycle processor with the following properties:

- **Word width:** 16 bits
- **Registers:** 8 general-purpose registers (R0–R7), each 16 bits wide
- **Instruction memory:** 16 words × 16 bits (loaded from `test/test.prog`)
- **Data memory:** 8 words × 16 bits (loaded from `test/test.data`)
- **Clock:** Single positive-edge-triggered clock; memories write synchronously, reads are combinational

#### Instruction Set Architecture (ISA)

| Opcode (4-bit) | Mnemonic | Type   | Description                       |
| -------------- | -------- | ------ | --------------------------------- |
| `0000`       | LD       | I-type | Load from data memory to register |
| `0001`       | ST       | I-type | Store register to data memory     |
| `0010`       | ADD      | R-type | R[WS] = R[RS1] + R[RS2]           |
| `0011`       | SUB      | R-type | R[WS] = R[RS1] - R[RS2]           |
| `0100`       | INV      | R-type | R[WS] = ~R[RS1]  (bitwise NOT)    |
| `0101`       | SHL      | R-type | R[WS] = R[RS1] << R[RS2][3:0]     |
| `0110`       | SHR      | R-type | R[WS] = R[RS1] >> R[RS2][3:0]     |
| `0111`       | AND      | R-type | R[WS] = R[RS1] & R[RS2]           |
| `1000`       | OR       | R-type | R[WS] = R[RS1]\| R[RS2]           |
| `1001`       | SLT      | R-type | R[WS] = (R[RS1] < R[RS2]) ? 1 : 0 |
| `1010`       | —       | —     | Reserved (no-op)                  |
| `1011`       | BEQ      | I-type | Branch if R[RS1] == R[RS2]        |
| `1100`       | BNE      | I-type | Branch if R[RS1] != R[RS2]        |
| `1101`       | JMP      | I-type | Unconditional jump                |

#### Instruction Encoding (16-bit)

```
R-type:   [15:12] opcode | [11:9] RS1 | [8:6] RS2 | [5:3] WS  | [2:0] unused
I-type:   [15:12] opcode | [11:9] RS1 | [8:6] WS  | [5:0] immediate (signed)
```

---

## Folder Structure

```
Practical-4/
├── Makefile                   # Build and simulation automation
├── src/
│   ├── Parameter.v            # Shared compile-time constants
│   ├── ALU.v                  # Task 1 — 16-bit ALU
│   ├── GPR.v                  # Task 2 — Register file (R0–R7)
│   ├── InstructionMemory.v    # Task 3 — ROM (loads test.prog)
│   ├── DataMemory.v           # Task 4 — RAM (loads test.data)
│   ├── ALU_Control.v          # Task 5 — ALU control decoder
│   ├── ControlUnit.v          # Task 6 — Main control unit
│   ├── Datapath.v             # Task 7 — Full datapath integration
│   └── StarCore1.v            # Task 8 — Top-level processor module
├── tb/
│   ├── ALU_tb.v               # Testbench for Task 1
│   ├── GPR_tb.v               # Testbench for Task 2
│   ├── InstructionMemory_tb.v # Testbench for Task 3
│   ├── DataMemory_tb.v        # Testbench for Task 4
│   ├── ALU_Control_tb.v       # Testbench for Task 5
│   ├── ControlUnit_tb.v       # Testbench for Task 6
│   └── StarCore1_tb.v         # Integration testbench for Tasks 7 & 8
├── test/
│   ├── test.prog              # Binary instruction memory contents (16 lines)
│   └── test.data              # Binary data memory initial contents (8 lines)
├── build/                     # Compiled simulation executables (auto-created)
└── waves/                     # VCD waveform output files (auto-created)
```

---

## Tasks

### Task 1: ALU (`src/ALU.v`)

Implement a purely combinational 16-bit ALU with 8 operations selected by a 3-bit `alu_control` signal.

| `alu_control` | Operation | Expression                           |
| --------------- | --------- | ------------------------------------ |
| `3'b000`      | ADD       | `result = a + b`                   |
| `3'b001`      | SUB       | `result = a - b`                   |
| `3'b010`      | INV       | `result = ~a`                      |
| `3'b011`      | SHL       | `result = a << b[3:0]`             |
| `3'b100`      | SHR       | `result = a >> b[3:0]`             |
| `3'b101`      | AND       | `result = a & b`                   |
| `3'b110`      | OR        | `result = a \| b`                   |
| `3'b111`      | SLT       | `result = (a < b) ? 16'd1 : 16'd0` |

Also implement the `zero` flag as a continuous assignment: `assign zero = (result == 16'd0);`

---

### Task 2: General Purpose Register File (`src/GPR.v`)

Implement a register file with 8 × 16-bit registers (R0–R7):

- **Two asynchronous read ports** (combinational, update immediately)
- **One synchronous write port** (writes on `posedge clk` when `reg_write_en` is asserted)
- All registers initialised to `16'd0` at simulation start

---

### Task 3: Instruction Memory (`src/InstructionMemory.v`)

Implement a combinational ROM:

- 16 words × 16 bits, loaded from `./test/test.prog` using `$readmemb`
- The PC is byte-addressed; derive the word index as `rom_addr = pc[4:1]`
- Drive the `instruction` output combinationally from `memory[rom_addr]`

---

### Task 4: Data Memory (`src/DataMemory.v`)

Implement a RAM with:

- 8 words × 16 bits, loaded from `./test/test.data` using `$readmemb`
- **Synchronous writes** on `posedge clk` when `mem_write_en` is asserted
- **Combinational reads** gated by `mem_read`; output `16'd0` when `mem_read` is de-asserted
- Word address derived as `ram_addr = mem_access_addr[2:0]`

---

### Task 5: ALU Control Unit (`src/ALU_Control.v`)

Decode the 2-bit `ALUOp` (from the main control unit) and the 4-bit `Opcode` into the 3-bit `ALU_Cnt` that drives the ALU.

Concatenate them into a 6-bit `control_in = {ALUOp, Opcode}` and use a `casex` statement:

| `control_in` | `ALU_Cnt` | Instruction                |
| -------------- | ----------- | -------------------------- |
| `6'b10xxxx`  | `3'b000`  | LD, ST (ADD for address)   |
| `6'b01xxxx`  | `3'b001`  | BEQ, BNE (SUB for compare) |
| `6'b000010`  | `3'b000`  | ADD                        |
| `6'b000011`  | `3'b001`  | SUB                        |
| `6'b000100`  | `3'b010`  | INV                        |
| `6'b000101`  | `3'b011`  | SHL                        |
| `6'b000110`  | `3'b100`  | SHR                        |
| `6'b000111`  | `3'b101`  | AND                        |
| `6'b001000`  | `3'b110`  | OR                         |
| `6'b001001`  | `3'b111`  | SLT                        |

---

### Task 6: Main Control Unit (`src/ControlUnit.v`)

Decode the 4-bit `opcode` and assert the appropriate control signals. Use an `always @(*)` block with safe defaults set before the `case` statement to prevent latches.

| Opcode         | Instr    | RegDst | ALUSrc | MemToReg | RegWrite | MemRd | MemWr | BEQ | BNE | ALUOp     | Jump |
| -------------- | -------- | ------ | ------ | -------- | -------- | ----- | ----- | --- | --- | --------- | ---- |
| `0000`       | LD       | 0      | 1      | 1        | 1        | 1     | 0     | 0   | 0   | `2'b10` | 0    |
| `0001`       | ST       | 0      | 1      | 0        | 0        | 0     | 1     | 0   | 0   | `2'b10` | 0    |
| `0010–1001` | R-type   | 1      | 0      | 0        | 1        | 0     | 0     | 0   | 0   | `2'b00` | 0    |
| `1010`       | Reserved | 0      | 0      | 0        | 0        | 0     | 0     | 0   | 0   | `2'b00` | 0    |
| `1011`       | BEQ      | 0      | 0      | 0        | 0        | 0     | 0     | 1   | 0   | `2'b01` | 0    |
| `1100`       | BNE      | 0      | 0      | 0        | 0        | 0     | 0     | 0   | 1   | `2'b01` | 0    |
| `1101`       | JMP      | 0      | 0      | 0        | 0        | 0     | 0     | 0   | 0   | `2'b00` | 1    |

---

### Task 7: Datapath (`src/Datapath.v`)

Wire all Tasks 1–6 together inside the `Datapath` module following the data-flow order described in the file header. Key implementation points:

1. **Program Counter**: initialise to `16'd0`; update to `pc_next` on every `posedge clk`; compute `pc2 = pc_current + 2`
2. **Instruction Memory**: instantiate as `im`; drive `opcode = instr[15:12]`
3. **RegDst mux**: `reg_write_dest = reg_dst ? instr[5:3] : instr[8:6]`
4. **GPR**: instantiate as `reg_file`
5. **Sign extension**: `ext_im = { {10{instr[5]}}, instr[5:0] }`
6. **ALUSrc mux**: `alu_operand_b = alu_src ? ext_im : reg_read_data_2`
7. **ALU_Control**: instantiate as `alu_ctrl`
8. **ALU**: instantiate as `alu_unit`
9. **Branch/Jump PC logic** (all continuous assignments):
   ```verilog
   assign pc_branch       = pc2 + {ext_im[14:0], 1'b0};
   assign beq_taken       = beq & zero_flag;
   assign bne_taken       = bne & ~zero_flag;
   assign pc_after_branch = (beq_taken | bne_taken) ? pc_branch : pc2;
   assign pc_jump         = {pc2[15:13], instr[11:0], 1'b0};
   assign pc_next         = jump ? pc_jump : pc_after_branch;
   ```
10. **DataMemory**: instantiate as `dm`
11. **MemToReg mux**: `reg_write_data = mem_to_reg ? mem_read_data : alu_result`

> **Note on instance names:** The integration testbench uses hierarchical references `uut.DU.*`, `uut.DU.reg_file.*`, and `uut.DU.dm.*`. Your instance names in `Datapath.v` and `StarCore1.v` **must** match exactly: `DU` for Datapath, `CU` for ControlUnit, `reg_file` for GPR, `dm` for DataMemory.

---

### Task 8: Top-Level Processor (`src/StarCore1.v`)

Connect the `Datapath` and `ControlUnit` modules using internal control wires. The only external port is `clk`.

1. Declare all internal control wires: `jump`, `beq`, `bne`, `mem_read`, `mem_write`, `alu_src`, `reg_dst`, `mem_to_reg`, `reg_write`, `alu_op [1:0]`, `opcode [3:0]`
2. Instantiate `Datapath` as `DU` and `ControlUnit` as `CU`, connecting all wires between them

---

## Compilation and Simulation

### Prerequisites

Install Icarus Verilog and GTKWave:

```bash
sudo apt install iverilog gtkwave
```

### Using the Makefile

All commands must be run from the `skeleton/` directory.

| Command              | Description                                            |
| -------------------- | ------------------------------------------------------ |
| `make alu`         | Compile and run ALU testbench (Task 1)                 |
| `make gpr`         | Compile and run GPR testbench (Task 2)                 |
| `make imem`        | Compile and run InstructionMemory testbench (Task 3)   |
| `make dmem`        | Compile and run DataMemory testbench (Task 4)          |
| `make aluctrl`     | Compile and run ALU_Control testbench (Task 5)         |
| `make ctrl`        | Compile and run ControlUnit testbench (Task 6)         |
| `make integration` | Compile and run full processor testbench (Tasks 7 & 8) |
| `make all`         | Run all testbenches in order                           |
| `make waves`       | Open integration waveform in GTKWave                   |
| `make clean`       | Remove all compiled outputs and waveform files         |

### Manual Compilation (Without Makefile)

**Single module example (ALU):**

```bash
iverilog -Wall -I src/ -o build/alu_sim src/ALU.v tb/ALU_tb.v
cd test && ../build/alu_sim
```

**Full processor integration:**

```bash
iverilog -Wall -I src/ -o build/star_sim \
    src/Parameter.v src/ALU.v src/GPR.v \
    src/InstructionMemory.v src/DataMemory.v \
    src/ALU_Control.v src/ControlUnit.v \
    src/Datapath.v src/StarCore1.v \
    tb/StarCore1_tb.v
cd test && ../build/star_sim
```

### Viewing Waveforms in GTKWave

After running the integration testbench, open the generated waveform:

```bash
make waves
# or directly:
gtkwave waves/star.vcd &
```

Useful signals to inspect in GTKWave:

- `uut.DU.pc_current` — Program Counter
- `uut.DU.instr` — Fetched instruction
- `uut.DU.alu_result` — ALU output
- `uut.DU.zero_flag` — ALU zero flag
- `uut.DU.reg_file.reg_array[N]` — Register RN value
- `uut.DU.dm.memory[N]` — Data memory word N
- `uut.CU.reg_write`, `uut.CU.alu_op` — Control unit outputs

---

## Test Program

The provided test program (`test/test.prog`) exercises the following sequence of instructions (one 16-bit binary value per line):

```
0000010000000000   # LD  R0, R0+0   — load Mem[0] into R0
0000010001000001   # LD  R1, R0+1   — load Mem[1] into R1
0010000001010000   # ADD R2, R0, R1 — R2 = R0 + R1
0001001010000000   # ST  R2, R1+0   — store R2 to Mem[R1+0]
0011000001010000   # SUB R2, R0, R1
0111000001010000   # AND R2, R0, R1
1000000001010000   # OR  R2, R0, R1
1001000001010000   # SLT R2, R0, R1
0010000000000000   # ADD R0, R0, R0
1011000001000001   # BEQ R0, R1, +1
1100000001000000   # BNE R0, R1, +0
1101000000000000   # JMP 0x000
```

---

## Common Issues and Tips

**"Unable to bind wire/reg/memory" errors on the integration testbench:**
This is expected when compiling against the skeleton. The integration testbench references internal signals (e.g. `uut.DU.pc_current`) that only exist after `Datapath.v` is implemented. These errors disappear once you complete Task 7.

**Simulation produces no output / processor hangs at PC=0:**
Check that `pc_current` is updated correctly on `posedge clk` and that `pc_next` is driven by a continuous assignment not left as `16'bx`.

**Testbench trace block commented out in `StarCore1_tb.v`:**
Uncomment the `always @(posedge clk)` trace block after implementing `Datapath.v` for a cycle-by-cycle execution log. This is your primary debugging tool.

**Adjusting simulation length:**
If your program needs more clock cycles to complete, increase `SIM_TIME` in `src/Parameter.v`. At 10 ns per clock the default `#640` gives 64 clock cycles.

**Non-blocking vs blocking assignments:**

- Use `<=` (non-blocking) inside `always @(posedge clk)` blocks (registers, memory writes)
- Use `=` (blocking) inside combinational `always @(*)` blocks (ALU, control unit)
- Use `assign` for purely combinational wires
