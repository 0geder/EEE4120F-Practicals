// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : ALU_Control.v
// Description : Maps {ALUOp, Opcode} -> ALU_Cnt using casex with don't-cares.
//               ALUOp: 10=mem(ADD), 01=branch(SUB), 00=R-type(decode opcode)

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ALU_Control (
    input  [1:0] ALUOp,
    input  [3:0] Opcode,
    output reg [2:0] ALU_Cnt
);

    wire [5:0] control_in;
    assign control_in = {ALUOp, Opcode};

    always @(*) begin
        casex (control_in)
            6'b10xxxx : ALU_Cnt = 3'b000; // LD/ST  -> ADD (address calc)
            6'b01xxxx : ALU_Cnt = 3'b001; // Branch -> SUB (comparison)
            6'b000010 : ALU_Cnt = 3'b000; // ADD
            6'b000011 : ALU_Cnt = 3'b001; // SUB
            6'b000100 : ALU_Cnt = 3'b010; // INV
            6'b000101 : ALU_Cnt = 3'b011; // SHL
            6'b000110 : ALU_Cnt = 3'b100; // SHR
            6'b000111 : ALU_Cnt = 3'b101; // AND
            6'b001000 : ALU_Cnt = 3'b110; // OR
            6'b001001 : ALU_Cnt = 3'b111; // SLT
            default   : ALU_Cnt = 3'b000; // safe default
        endcase
    end

endmodule
