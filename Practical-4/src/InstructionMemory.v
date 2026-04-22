// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : InstructionMemory.v
// Description : 16-word instruction ROM. Loaded from ./test/test.prog.

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module InstructionMemory (
    input  [15:0] pc,
    output [15:0] instruction
);

    reg [`COL-1:0] memory [`ROW_I-1:0];

    // PC is byte-addressed; word index = pc[4:1]
    wire [3:0] rom_addr = pc[4:1];

    initial begin
        $readmemb("./test.prog", memory, 0, 14);
    end

    assign instruction = memory[rom_addr];

endmodule