// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : StarCore1.v
// Description : Top-level module. Connects Datapath (DU) and ControlUnit (CU).

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module StarCore1 (
    input clk
);

    // Internal control wires
    wire        jump;
    wire        beq;
    wire        bne;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;
    wire        reg_dst;
    wire        mem_to_reg;
    wire        reg_write;
    wire [1:0]  alu_op;
    wire [3:0]  opcode;

    // Datapath instance — MUST be named DU (testbench uses uut.DU.*)
    Datapath DU (
        .clk       (clk),
        .jump      (jump),
        .beq       (beq),
        .bne       (bne),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .reg_dst   (reg_dst),
        .mem_to_reg(mem_to_reg),
        .reg_write (reg_write),
        .alu_op    (alu_op),
        .opcode    (opcode)
    );

    // ControlUnit instance — MUST be named CU (testbench uses uut.CU.*)
    ControlUnit CU (
        .opcode    (opcode),
        .alu_op    (alu_op),
        .jump      (jump),
        .beq       (beq),
        .bne       (bne),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .reg_dst   (reg_dst),
        .mem_to_reg(mem_to_reg),
        .reg_write (reg_write)
    );

endmodule
