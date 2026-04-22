// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : DataMemory_tb.v
// =============================================================================
`timescale 1ns / 1ps
`include "../src/Parameter.v"

module DataMemory_tb;

    reg        clk;
    reg  [15:0] mem_access_addr;
    reg  [15:0] mem_write_data;
    reg        mem_write_en;
    reg        mem_read;
    wire [15:0] mem_read_data;

    DataMemory uut (
        .clk             (clk),
        .mem_access_addr (mem_access_addr),
        .mem_write_data  (mem_write_data),
        .mem_write_en    (mem_write_en),
        .mem_read        (mem_read),
        .mem_read_data   (mem_read_data)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("../waves/dm_tb.vcd");
        $dumpvars(0, DataMemory_tb);
    end

    integer fail_count;
    integer test_id;
    initial begin
        fail_count = 0; test_id = 1;
        mem_write_en = 1'b0; mem_read = 1'b0;
        mem_access_addr = 16'd0; mem_write_data = 16'd0;
    end

    task check16;
        input [15:0] got;
        input [15:0] expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: got=0x%h, expected=0x%h", id, got, expected);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: value=0x%h", id, got);
        end
    endtask

    integer i;

    initial begin
        $display("=== DataMemory Testbench ===");
        @(posedge clk); #1; // let init settle

        // ── Group 1: Verify $readmemb initialisation ──────────────
        // test.data: [0]=1,[1]=2,[2]=3,[3]=4,[4]=5,[5]=6,[6]=7,[7]=8
        $display("--- Group 1: Verify $readmemb initialisation ---");
        for (i = 0; i < 8; i = i + 1) begin
            mem_access_addr = i[15:0];  // addr[2:0] = word index
            mem_read = 1'b1; #5;
            check16(mem_read_data, i[15:0] + 16'd1, test_id);
            test_id = test_id + 1;
        end
        mem_read = 1'b0;

        // ── Group 2: mem_read=0 gates output to 0 ────────────────
        $display("--- Group 2: Output is 0 when mem_read=0 ---");
        mem_access_addr = 16'd0; mem_read = 1'b0; #5;
        check16(mem_read_data, 16'd0, test_id); test_id = test_id + 1;

        // ── Group 3: Synchronous write then read back ─────────────
        $display("--- Group 3: Synchronous write then read back ---");
        mem_access_addr = 16'd2; mem_write_data = 16'hABCD;
        mem_write_en = 1'b1; mem_read = 1'b0;
        @(posedge clk); #1;
        mem_write_en = 1'b0; mem_read = 1'b1; #5;
        check16(mem_read_data, 16'hABCD, test_id); test_id = test_id + 1;

        // ── Group 4: Disabled write does not change memory ────────
        $display("--- Group 4: Disabled write leaves memory unchanged ---");
        mem_access_addr = 16'd4; mem_write_data = 16'hDEAD;
        mem_write_en = 1'b0;
        @(posedge clk); #1;
        mem_read = 1'b1; #5;
        check16(mem_read_data, 16'd5, test_id); test_id = test_id + 1; // original value
        mem_read = 1'b0;

        // ── Group 5: Write to max address (word[7]) ───────────────
        $display("--- Group 5: Write and read word[7] ---");
        mem_access_addr = 16'd7; mem_write_data = 16'h1234;
        mem_write_en = 1'b1;
        @(posedge clk); #1;
        mem_write_en = 1'b0; mem_read = 1'b1; #5;
        check16(mem_read_data, 16'h1234, test_id); test_id = test_id + 1;

        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
