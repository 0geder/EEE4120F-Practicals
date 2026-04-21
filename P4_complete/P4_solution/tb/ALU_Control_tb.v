// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : ALU_Control_tb.v
// =============================================================================
`timescale 1ns / 1ps
`include "../src/Parameter.v"

module ALU_Control_tb;

    reg  [1:0] ALUOp;
    reg  [3:0] Opcode;
    wire [2:0] ALU_Cnt;

    ALU_Control uut (
        .ALUOp   (ALUOp),
        .Opcode  (Opcode),
        .ALU_Cnt (ALU_Cnt)
    );

    initial begin
        $dumpfile("../waves/ac_tb.vcd");
        $dumpvars(0, ALU_Control_tb);
    end

    integer fail_count;
    integer test_id;
    initial begin fail_count = 0; test_id = 1; end

    task check_cnt;
        input [2:0] got;
        input [2:0] expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: ALU_Cnt = %b, expected = %b", id, got, expected);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: ALU_Cnt = %b", id, got);
        end
    endtask

    initial begin
        $display("=== ALU_Control Testbench ===");

        // ── ALUOp=10: memory access — always ADD (000) ────────────
        $display("--- ALUOp=10: all opcodes should map to ADD (000) ---");
        ALUOp=2'b10; Opcode=4'h0; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1;
        ALUOp=2'b10; Opcode=4'h1; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1;
        ALUOp=2'b10; Opcode=4'hF; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1;

        // ── ALUOp=01: branch — always SUB (001) ───────────────────
        $display("--- ALUOp=01: all opcodes should map to SUB (001) ---");
        ALUOp=2'b01; Opcode=4'hB; #10; check_cnt(ALU_Cnt, 3'b001, test_id); test_id=test_id+1; // BEQ
        ALUOp=2'b01; Opcode=4'hC; #10; check_cnt(ALU_Cnt, 3'b001, test_id); test_id=test_id+1; // BNE
        ALUOp=2'b01; Opcode=4'h0; #10; check_cnt(ALU_Cnt, 3'b001, test_id); test_id=test_id+1; // any

        // ── ALUOp=00: R-type — decode from opcode ─────────────────
        $display("--- ALUOp=00: decode per opcode ---");
        ALUOp=2'b00; Opcode=4'h2; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1; // ADD
        ALUOp=2'b00; Opcode=4'h3; #10; check_cnt(ALU_Cnt, 3'b001, test_id); test_id=test_id+1; // SUB
        ALUOp=2'b00; Opcode=4'h4; #10; check_cnt(ALU_Cnt, 3'b010, test_id); test_id=test_id+1; // INV
        ALUOp=2'b00; Opcode=4'h5; #10; check_cnt(ALU_Cnt, 3'b011, test_id); test_id=test_id+1; // SHL
        ALUOp=2'b00; Opcode=4'h6; #10; check_cnt(ALU_Cnt, 3'b100, test_id); test_id=test_id+1; // SHR
        ALUOp=2'b00; Opcode=4'h7; #10; check_cnt(ALU_Cnt, 3'b101, test_id); test_id=test_id+1; // AND
        ALUOp=2'b00; Opcode=4'h8; #10; check_cnt(ALU_Cnt, 3'b110, test_id); test_id=test_id+1; // OR
        ALUOp=2'b00; Opcode=4'h9; #10; check_cnt(ALU_Cnt, 3'b111, test_id); test_id=test_id+1; // SLT

        // ── Default: undefined R-type opcode -> ADD (000) ─────────
        $display("--- Default (ALUOp=00, undefined opcode) -> ADD (000) ---");
        ALUOp=2'b00; Opcode=4'hA; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1;
        ALUOp=2'b00; Opcode=4'hF; #10; check_cnt(ALU_Cnt, 3'b000, test_id); test_id=test_id+1;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
