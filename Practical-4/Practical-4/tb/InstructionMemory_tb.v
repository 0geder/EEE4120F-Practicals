// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : InstructionMemory_tb.v
// Description : Testbench for the Instruction Memory module (Task 3).
//               Walks the PC through all valid addresses and verifies the
//               correct instruction word is output combinationally.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/im_sim ../src/InstructionMemory.v InstructionMemory_tb.v
//   cd ../test && ../build/im_sim
//   gtkwave ../waves/im_tb.vcd &
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module InstructionMemory_tb;

    reg  [15:0] pc;
    wire [15:0] instruction;

    InstructionMemory uut (.pc(pc), .instruction(instruction));

    initial begin
        $dumpfile("../waves/im_tb.vcd");
        $dumpvars(0, InstructionMemory_tb);
    end

    integer fail_count;
    integer test_id;
    // Expected instruction words — these must match the contents of test.prog.
    // Update these values after you finalise your test.prog file.
    reg [15:0] expected [0:14];

    initial begin
        fail_count = 0;
        test_id    = 1;

        $display("=== InstructionMemory Testbench ===");

        // TODO: Load the expected values to match your test.prog file.
        //       For example, if your first instruction is ADD R2,R0,R1 (0010000001010000):
        //           expected[0]  = 16'b0010000001010000;
        //       Fill in all 15 entries to match your test.prog exactly.
        //
        //       expected[0]  = 16'bXXXXXXXXXXXXXXXX;
        //       expected[1]  = 16'bXXXXXXXXXXXXXXXX;
        //       ... (fill all 15)
        // Populate expected array from test.prog contents
        expected[0]  = 16'b0000010000000000; // LD  R0, 0(R0)
        expected[1]  = 16'b0000010001000001; // LD  R1, 1(R0)
        expected[2]  = 16'b0010000001010000; // ADD R2, R0, R1
        expected[3]  = 16'b0001001010000000; // ST  R2, 0(R1)
        expected[4]  = 16'b0011000001010000; // SUB R2, R0, R1
        expected[5]  = 16'b0111000001010000; // AND R2, R0, R1
        expected[6]  = 16'b1000000001010000; // OR  R2, R0, R1
        expected[7]  = 16'b1001000001010000; // SLT R2, R0, R1
        expected[8]  = 16'b0010000000000000; // ADD R0, R0, R0
        expected[9]  = 16'b1011000001000001; // BEQ R0, R1, +1
        expected[10] = 16'b1100000001000000; // BNE R0, R1, +0
        expected[11] = 16'b1101000000000000; // JMP 0
        expected[12] = 16'b0000000000000000; // (padding)
        expected[13] = 16'b0000000000000000; // (padding)
        expected[14] = 16'b0000000000000000; // (padding)

        // TODO: Walk PC through addresses 0, 2, 4, ... 28 (14 instructions).
        //       At each address, verify instruction == expected[rom_index].
        //       Verify also that the output is combinational (no clock needed).
        //
        //       For each address:
        //           pc = 16'd0; #5;  // set PC, wait for combinational output
        //           if (instruction !== expected[0])
        //               $display("FAIL [T%0d]: PC=0 got %b exp %b",
        //                        test_id, instruction, expected[0]);
        //           else
        //               $display("PASS [T%0d]: PC=0 instr=%b", test_id, instruction);
        //           test_id = test_id + 1;
        //
        //           pc = 16'd2; #5;
        //           ... and so on.
        // Walk PC through all 15 word-aligned addresses (0, 2, 4 ... 28)
        // Output is combinational — no clock needed, just settle time
        for (i = 0; i < 15; i = i + 1) begin
            pc = i * 2; #5;
            if (instruction !== expected[i]) begin
                $display("FAIL [T%0d]: PC=0x%h  got=%b  exp=%b",
                         test_id, pc, instruction, expected[i]);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: PC=0x%h  instr=%b", test_id, pc, instruction);
            test_id = test_id + 1;
        end

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
