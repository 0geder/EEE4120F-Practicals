// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : DataMemory_tb.v
// Description : Testbench for the Data Memory module (Task 4).
//               Verifies synchronous write, gated combinational read,
//               write followed by immediate read, and disabled-write safety.
//
// Run:
//   iverilog -Wall -I ../src -o ../build/dm_sim ../src/DataMemory.v DataMemory_tb.v
//   cd ../test && ../build/dm_sim
//   gtkwave ../waves/dm_tb.vcd &
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
        fail_count      = 0;
        test_id         = 1;
        mem_write_en    = 1'b0;
        mem_read        = 1'b0;
        mem_access_addr = 16'd0;
        mem_write_data  = 16'd0;

        $display("=== DataMemory Testbench ===");

        // ------------------------------------------------------------------
        // TEST GROUP 1: Read back initial values loaded from test.data
        // ------------------------------------------------------------------
        $display("--- Group 1: Verify $readmemb initialisation ---");

        // TODO: Read each of the 8 memory locations and verify against
        //       the known contents of your test.data file.
        //       Remember: only mem_access_addr[2:0] is used as the index.
        //       Address 16'd0 -> word 0, address 16'd2 -> word 2, etc.
        //       (Or use address 16'd0 -> word 0, address 16'd1 -> word 1,
        //        since only the lower 3 bits matter.)
        //
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'h0001)  // expected value from test.data line 0
        //           $display("FAIL [T%0d]: addr=0 got=0x%h exp=0x0001", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]", test_id);
        //       test_id = test_id + 1;
        @(posedge clk); #1; // let init settle

        // test.data: [0]=1,[1]=2,[2]=3,[3]=4,[4]=5,[5]=6,[6]=7,[7]=8
        mem_access_addr = 16'd0; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd1) begin $display("FAIL [T%0d]: addr=0 got=%d exp=1", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd1; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd2) begin $display("FAIL [T%0d]: addr=1 got=%d exp=2", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd2; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd3) begin $display("FAIL [T%0d]: addr=2 got=%d exp=3", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd3; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd4) begin $display("FAIL [T%0d]: addr=3 got=%d exp=4", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd4; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd5) begin $display("FAIL [T%0d]: addr=4 got=%d exp=5", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd5; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd6) begin $display("FAIL [T%0d]: addr=5 got=%d exp=6", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd6; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd7) begin $display("FAIL [T%0d]: addr=6 got=%d exp=7", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd7; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'd8) begin $display("FAIL [T%0d]: addr=7 got=%d exp=8", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;


        // ------------------------------------------------------------------
        // TEST GROUP 2: Write new values to all 8 locations, then read back
        // ------------------------------------------------------------------
        $display("--- Group 2: Write then read all 8 locations ---");

        // TODO: Write a distinct value to each of the 8 addresses using
        //       mem_write_en and posedge clk, then read each back.
        //
        //       // Write to address 0
        //       mem_write_en    = 1'b1;
        //       mem_access_addr = 16'd0;
        //       mem_write_data  = 16'hABCD;
        //       @(posedge clk); #1;
        //       mem_write_en    = 1'b0;
        //
        //       // Read back from address 0
        //       mem_read = 1'b1;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'hABCD) ...
        //       test_id = test_id + 1;
        mem_read = 1'b0; // disable read during writes
        mem_access_addr = 16'd0; mem_write_data = 16'hABCD; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd1; mem_write_data = 16'h1234; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd2; mem_write_data = 16'hDEAD; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd3; mem_write_data = 16'hBEEF; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd4; mem_write_data = 16'hCAFE; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd5; mem_write_data = 16'hFEED; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd6; mem_write_data = 16'hFACE; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_access_addr = 16'd7; mem_write_data = 16'hC0DE; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_write_en = 1'b0;

        // Read back and verify
        mem_read = 1'b1; mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'hABCD) begin $display("FAIL [T%0d]: addr=0 got=%h exp=ABCD", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd1; #5;
        if (mem_read_data !== 16'h1234) begin $display("FAIL [T%0d]: addr=1 got=%h exp=1234", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd2; #5;
        if (mem_read_data !== 16'hDEAD) begin $display("FAIL [T%0d]: addr=2 got=%h exp=DEAD", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd3; #5;
        if (mem_read_data !== 16'hBEEF) begin $display("FAIL [T%0d]: addr=3 got=%h exp=BEEF", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd4; #5;
        if (mem_read_data !== 16'hCAFE) begin $display("FAIL [T%0d]: addr=4 got=%h exp=CAFE", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd5; #5;
        if (mem_read_data !== 16'hFEED) begin $display("FAIL [T%0d]: addr=5 got=%h exp=FEED", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd6; #5;
        if (mem_read_data !== 16'hFACE) begin $display("FAIL [T%0d]: addr=6 got=%h exp=FACE", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd7; #5;
        if (mem_read_data !== 16'hC0DE) begin $display("FAIL [T%0d]: addr=7 got=%h exp=C0DE", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]", test_id); test_id = test_id + 1;


        // ------------------------------------------------------------------
        // TEST GROUP 3: mem_read = 0 must produce 16'd0 output
        // ------------------------------------------------------------------
        $display("--- Group 3: mem_read disabled -> output must be 0 ---");

        // TODO: De-assert mem_read and verify the output is 16'd0 regardless
        //       of the address.
        //
        //       mem_read = 1'b0;
        //       mem_access_addr = 16'd0; #5;
        //       if (mem_read_data !== 16'd0)
        //           $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data);
        //       else
        //           $display("PASS [T%0d]: output = 0 when mem_read=0", test_id);
        //       test_id = test_id + 1;
        mem_read = 1'b0; mem_access_addr = 16'd0; #5;
        if (mem_read_data !== 16'd0) begin $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]: output = 0 when mem_read=0", test_id); test_id = test_id + 1;
        mem_access_addr = 16'd5; #5;
        if (mem_read_data !== 16'd0) begin $display("FAIL [T%0d]: mem_read=0 but output=%h", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]: output = 0 when mem_read=0", test_id); test_id = test_id + 1;


        // ------------------------------------------------------------------
        // TEST GROUP 4: Write then immediately read on the next cycle
        // ------------------------------------------------------------------
        $display("--- Group 4: Write followed by immediate read ---");

        // TODO: Write to address 3, then on the very next cycle read back
        //       from address 3 and confirm the new value is returned.
        mem_access_addr = 16'd3; mem_write_data = 16'h5555; mem_write_en = 1'b1; @(posedge clk); #1;
        mem_write_en = 1'b0; mem_read = 1'b1; #5;
        if (mem_read_data !== 16'h5555) begin $display("FAIL [T%0d]: write-then-read got=%h exp=5555", test_id, mem_read_data); fail_count = fail_count + 1; end else $display("PASS [T%0d]: write-then-read", test_id); test_id = test_id + 1;


        // ------------------------------------------------------------------
        // TEST GROUP 5: Disabled write must not alter memory
        // ------------------------------------------------------------------
        $display("--- Group 5: mem_write_en=0 must not overwrite memory ---");

        // TODO: Assert mem_write_en=0, clock one cycle, then read and confirm
        //       the previous value is unchanged.
        mem_access_addr = 16'd2; mem_write_data = 16'h9999; mem_write_en = 1'b0; @(posedge clk); #1;
        mem_read = 1'b1; #5;
        if (mem_read_data !== 16'hDEAD) begin $display("FAIL [T%0d]: disabled write changed data", test_id); fail_count = fail_count + 1; end else $display("PASS [T%0d]: disabled write", test_id); test_id = test_id + 1;


        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);
        $finish;
    end

endmodule
