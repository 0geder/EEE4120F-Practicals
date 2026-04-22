// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
//
// GROUP NUMBER: 22
//
// MEMBERS:
//   - Member 1 Samson Okuthe, OKTSAM001
//   - Member 2 Nyakallo Peete, PTXNYA001

// File        : ALU.v
// Description : 16-bit Arithmetic and Logic Unit (ALU).

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ALU (
    input  [15:0] a,
    input  [15:0] b,
    input  [ 2:0] alu_control,
    output reg [15:0] result,
    output         zero
);

    assign zero = (result == 16'd0);

    always @(*) begin
        case (alu_control)
            3'b000 : result = a + b;           // ADD
            3'b001 : result = a - b;           // SUB
            3'b010 : result = ~a;              // INV
            3'b011 : result = a << b[3:0];     // SHL
            3'b100 : result = a >> b[3:0];     // SHR
            3'b101 : result = a & b;           // AND
            3'b110 : result = a | b;           // OR
            3'b111 : result = (a < b) ? 16'd1 : 16'd0; // SLT (unsigned)
            default: result = a + b;
        endcase
    end

endmodule
