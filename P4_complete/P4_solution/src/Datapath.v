// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : Datapath.v
// Description : Full StarCore-1 datapath. Wires all sub-components together.
//               Instance names MUST match the integration testbench:
//                 im       = InstructionMemory
//                 reg_file = GPR
//                 alu_ctrl = ALU_Control
//                 alu_unit = ALU
//                 dm       = DataMemory

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module Datapath (
    input        clk,
    input        jump,
    input        beq,
    input        bne,
    input        mem_read,
    input        mem_write,
    input        alu_src,
    input        reg_dst,
    input        mem_to_reg,
    input        reg_write,
    input  [1:0] alu_op,
    output [3:0] opcode
);

    // ── Program Counter ───────────────────────────────────────────
    reg  [15:0] pc_current;
    wire [15:0] pc_next;
    wire [15:0] pc2;

    initial begin
        pc_current <= 16'd0;
    end

    always @(posedge clk) begin
        pc_current <= pc_next;
    end

    assign pc2 = pc_current + 16'd2;

    // ── Instruction Memory ────────────────────────────────────────
    wire [15:0] instr;

    InstructionMemory im (
        .pc         (pc_current),
        .instruction(instr)
    );

    assign opcode = instr[15:12];

    // ── Register File Addresses ───────────────────────────────────
    wire [2:0] reg_read_addr_1 = instr[11:9];  // RS1
    wire [2:0] reg_read_addr_2 = instr[8:6];   // RS2 (also I-type WS)
    wire [2:0] reg_write_dest;

    // RegDst mux: 1 = R-type WS [5:3], 0 = I-type WS [8:6]
    assign reg_write_dest = reg_dst ? instr[5:3] : instr[8:6];

    // ── Register File ─────────────────────────────────────────────
    wire [15:0] reg_read_data_1, reg_read_data_2;
    wire [15:0] reg_write_data;

    GPR reg_file (
        .clk             (clk),
        .reg_write_en    (reg_write),
        .reg_write_dest  (reg_write_dest),
        .reg_write_data  (reg_write_data),
        .reg_read_addr_1 (reg_read_addr_1),
        .reg_read_data_1 (reg_read_data_1),
        .reg_read_addr_2 (reg_read_addr_2),
        .reg_read_data_2 (reg_read_data_2)
    );

    // ── Sign Extension: 6-bit → 16-bit ───────────────────────────
    wire [15:0] ext_im;
    assign ext_im = {{10{instr[5]}}, instr[5:0]};

    // ── ALUSrc Mux ────────────────────────────────────────────────
    wire [15:0] alu_operand_b;
    assign alu_operand_b = alu_src ? ext_im : reg_read_data_2;

    // ── ALU Control ───────────────────────────────────────────────
    wire [2:0] alu_control;

    ALU_Control alu_ctrl (
        .ALUOp  (alu_op),
        .Opcode (instr[15:12]),
        .ALU_Cnt(alu_control)
    );

    // ── ALU ───────────────────────────────────────────────────────
    wire [15:0] alu_result;
    wire        zero_flag;

    ALU alu_unit (
        .a          (reg_read_data_1),
        .b          (alu_operand_b),
        .alu_control(alu_control),
        .result     (alu_result),
        .zero       (zero_flag)
    );

    // ── Branch / Jump PC Logic ────────────────────────────────────
    wire [15:0] pc_branch;
    wire        beq_taken, bne_taken;
    wire [15:0] pc_after_branch;
    wire [15:0] pc_jump;

    assign pc_branch       = pc2 + {ext_im[14:0], 1'b0};
    assign beq_taken       = beq & zero_flag;
    assign bne_taken       = bne & ~zero_flag;
    assign pc_after_branch = (beq_taken | bne_taken) ? pc_branch : pc2;
    assign pc_jump         = {pc2[15:13], instr[11:0], 1'b0};
    assign pc_next         = jump ? pc_jump : pc_after_branch;

    // ── Data Memory ───────────────────────────────────────────────
    wire [15:0] mem_read_data;

    DataMemory dm (
        .clk            (clk),
        .mem_access_addr(alu_result),
        .mem_write_data (reg_read_data_2),
        .mem_write_en   (mem_write),
        .mem_read       (mem_read),
        .mem_read_data  (mem_read_data)
    );

    // ── Write-back Mux ────────────────────────────────────────────
    assign reg_write_data = mem_to_reg ? mem_read_data : alu_result;

endmodule
