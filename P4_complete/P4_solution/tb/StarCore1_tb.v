// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : StarCore1_tb.v
// Description : Integration testbench — runs test.prog and verifies results.
//               Expected values derived from simulating the official test program:
//
//   [0] LD  R0, 0(R0)    R0 = Mem[0] = 1
//   [1] LD  R1, 1(R0)    R1 = Mem[1] = 2
//   [2] ADD R2, R0, R1   R2 = 3
//   [3] ST  R2, 0(R1)    Mem[2] = 3   (addr=R1+0=2, word[2]=3)
//   [4] SUB R2, R0, R1   R2 = 1-2 = 0xFFFF
//   [5] AND R2, R0, R1   R2 = 1&2 = 0
//   [6] OR  R2, R0, R1   R2 = 1|2 = 3
//   [7] SLT R2, R0, R1   R2 = (1<2)=1
//   [8] ADD R0, R0, R0   R0 = 2
//   [9] BEQ R0, R1, +1   R0(2)==R1(2) → TAKEN, skip instr 10
//  [10] BNE R0, R1, +0   SKIPPED
//  [11] JMP 0             PC=0
//
//   Final state after first loop pass:
//     R0=2, R1=2, R2=1, Mem[2]=3
// =============================================================================

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module StarCore1_tb;

    reg clk;
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    StarCore1 uut (.clk(clk));

    initial begin
        $dumpfile("../waves/star.vcd");
        $dumpvars(0, StarCore1_tb);
    end

    integer fail_count;
    integer test_id;

    initial begin
        fail_count = 0;
        test_id    = 1;
    end

    task check16;
        input [15:0] got;
        input [15:0] expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: got = 0x%h (%0d), expected = 0x%h (%0d)",
                         id, got, got, expected, expected);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: value = 0x%h (%0d)", id, got, got);
        end
    endtask

    // Cycle-by-cycle execution trace
    always @(posedge clk) begin
        $display("%0t ns | PC=0x%h | instr=%b | R0=%3d R1=%3d R2=%3d R3=%3d | alu=%0d z=%b",
            $time,
            uut.DU.pc_current,
            uut.DU.instr,
            uut.DU.reg_file.reg_array[0],
            uut.DU.reg_file.reg_array[1],
            uut.DU.reg_file.reg_array[2],
            uut.DU.reg_file.reg_array[3],
            uut.DU.alu_result,
            uut.DU.zero_flag
        );
    end

    initial begin
        $display("=== StarCore-1 Integration Testbench ===");
        $display("");

        // Run for enough cycles to complete one full pass (12 instructions)
        `SIM_TIME;

        $display("");
        $display("--- Post-Simulation Verification ---");

        // R0: after LD(=1) then ADD R0,R0,R0 at instr 8 → R0=2
        $display("Checking R0 (expect 2 after ADD R0,R0,R0):");
        check16(uut.DU.reg_file.reg_array[0], 16'd2, test_id);
        test_id = test_id + 1;

        // R1: LD Mem[1]=2, unchanged after that
        $display("Checking R1 (expect 2 from LD):");
        check16(uut.DU.reg_file.reg_array[1], 16'd2, test_id);
        test_id = test_id + 1;

        // R2: last write is SLT R0<R1 = (1<2)=1 at instr 7
        $display("Checking R2 (expect 1 from SLT):");
        check16(uut.DU.reg_file.reg_array[2], 16'd1, test_id);
        test_id = test_id + 1;

        // Data memory word[2]: ST R2,0(R1) stored 3 at instr 3
        $display("Checking DataMem[2] (expect 3 from ST):");
        check16(uut.DU.dm.memory[2], 16'd3, test_id);
        test_id = test_id + 1;

        // Verify BEQ was taken (instr 10 skipped): if BNE ran it would
        // loop on itself (+0), so check PC loops back to 0 happened
        // (indirectly confirmed by R0=2, not the post-BNE-ADD value)

        $display("");
        $display("--- Final Register File State ---");
        $display("R0=0x%h  R1=0x%h  R2=0x%h  R3=0x%h",
            uut.DU.reg_file.reg_array[0], uut.DU.reg_file.reg_array[1],
            uut.DU.reg_file.reg_array[2], uut.DU.reg_file.reg_array[3]);
        $display("R4=0x%h  R5=0x%h  R6=0x%h  R7=0x%h",
            uut.DU.reg_file.reg_array[4], uut.DU.reg_file.reg_array[5],
            uut.DU.reg_file.reg_array[6], uut.DU.reg_file.reg_array[7]);

        $display("");
        $display("--- Final Data Memory State ---");
        $display("Mem[0]=0x%h  Mem[1]=0x%h  Mem[2]=0x%h  Mem[3]=0x%h",
            uut.DU.dm.memory[0], uut.DU.dm.memory[1],
            uut.DU.dm.memory[2], uut.DU.dm.memory[3]);

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d INTEGRATION TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d INTEGRATION TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
