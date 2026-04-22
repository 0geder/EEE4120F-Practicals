// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : ControlUnit.v
// Description : Decodes 4-bit opcode into all processor control signals.
//               Purely combinational. Safe defaults prevent latches.

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ControlUnit (
    input  [3:0] opcode,
    output reg [1:0] alu_op,
    output reg       jump,
    output reg       beq,
    output reg       bne,
    output reg       mem_read,
    output reg       mem_write,
    output reg       alu_src,
    output reg       reg_dst,
    output reg       mem_to_reg,
    output reg       reg_write
);

    always @(*) begin
        // Safe defaults — no writes, no branches, no jumps
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        beq        = 1'b0;
        bne        = 1'b0;
        alu_op     = 2'b00;
        jump       = 1'b0;

        case (opcode)
            4'b0000: begin  // LD
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_op     = 2'b10;
            end

            4'b0001: begin  // ST
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b10;
            end

            // R-type: ADD, SUB, INV, SHL, SHR, AND, OR, SLT
            4'b0010, 4'b0011, 4'b0100, 4'b0101,
            4'b0110, 4'b0111, 4'b1000, 4'b1001: begin
                reg_dst   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 2'b00;
            end

            4'b1010: begin  // Reserved — NOP, all outputs at safe defaults
            end

            4'b1011: begin  // BEQ
                beq    = 1'b1;
                alu_op = 2'b01;
            end

            4'b1100: begin  // BNE
                bne    = 1'b1;
                alu_op = 2'b01;
            end

            4'b1101: begin  // JMP
                jump = 1'b1;
            end

            default: begin  // undefined — safe defaults
            end
        endcase
    end

endmodule
