// =============================================================================
// EEE4120F Practical 4 — StarCore-1 Processor
// File        : GPR_tb.v
// =============================================================================
`timescale 1ns / 1ps
`include "../src/Parameter.v"

module GPR_tb;

    reg        clk;
    reg        reg_write_en;
    reg  [2:0] reg_write_dest;
    reg  [15:0] reg_write_data;
    reg  [2:0] reg_read_addr_1;
    reg  [2:0] reg_read_addr_2;
    wire [15:0] reg_read_data_1;
    wire [15:0] reg_read_data_2;

    GPR uut (
        .clk              (clk),
        .reg_write_en     (reg_write_en),
        .reg_write_dest   (reg_write_dest),
        .reg_write_data   (reg_write_data),
        .reg_read_addr_1  (reg_read_addr_1),
        .reg_read_data_1  (reg_read_data_1),
        .reg_read_addr_2  (reg_read_addr_2),
        .reg_read_data_2  (reg_read_data_2)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("../waves/gpr_tb.vcd");
        $dumpvars(0, GPR_tb);
    end

    integer fail_count;
    integer test_id;
    initial begin fail_count = 0; test_id = 1; end

    task check16;
        input [15:0] got;
        input [15:0] expected;
        input [63:0] id;
        begin
            if (got !== expected) begin
                $display("FAIL [T%0d]: got = 0x%h, expected = 0x%h", id, got, expected);
                fail_count = fail_count + 1;
            end else
                $display("PASS [T%0d]: value = 0x%h", id, got);
        end
    endtask

    // Unique value per register for independence testing
    reg [15:0] vals [0:7];
    integer i;

    initial begin
        $display("=== GPR Testbench ===");
        reg_write_en    = 1'b0;
        reg_write_dest  = 3'd0;
        reg_write_data  = 16'd0;
        reg_read_addr_1 = 3'd0;
        reg_read_addr_2 = 3'd0;

        vals[0] = 16'hA000; vals[1] = 16'hB001; vals[2] = 16'hC002; vals[3] = 16'hD003;
        vals[4] = 16'hE004; vals[5] = 16'hF005; vals[6] = 16'h1006; vals[7] = 16'h2007;

        @(posedge clk); #1; // let init settle

        // ── Group 1: Write and read back all 8 registers ─────────
        $display("--- Test Group 1: Write and read back all 8 registers ---");
        for (i = 0; i < 8; i = i + 1) begin
            reg_write_en   = 1'b1;
            reg_write_dest = i[2:0];
            reg_write_data = vals[i];
            @(posedge clk); #1;
            reg_write_en = 1'b0;
            reg_read_addr_1 = i[2:0]; #2;
            check16(reg_read_data_1, vals[i], test_id);
            test_id = test_id + 1;
        end

        // ── Group 2: Disabled write must not modify register ──────
        $display("--- Test Group 2: Disabled write must not modify register ---");
        reg_write_en   = 1'b0;
        reg_write_dest = 3'd0;
        reg_write_data = 16'hDEAD; // must NOT be written
        @(posedge clk); #1;
        reg_read_addr_1 = 3'd0; #2;
        check16(reg_read_data_1, vals[0], test_id); // original value still there
        test_id = test_id + 1;

        // ── Group 3: Simultaneous dual-port read ──────────────────
        $display("--- Test Group 3: Simultaneous dual-port read ---");
        reg_read_addr_1 = 3'd1;
        reg_read_addr_2 = 3'd3;
        #2;
        check16(reg_read_data_1, vals[1], test_id); test_id = test_id + 1;
        check16(reg_read_data_2, vals[3], test_id); test_id = test_id + 1;

        // ── Group 4: Read during write (observe write-before-read) ─
        $display("--- Test Group 4: Read address matches write address during write ---");
        reg_write_en    = 1'b1;
        reg_write_dest  = 3'd2;
        reg_write_data  = 16'hCAFE;
        reg_read_addr_1 = 3'd2;
        #2; // before clock edge — should see OLD value (async read)
        $display("INFO [T%0d]: Read during write = 0x%h (old value before posedge)",
                 test_id, reg_read_data_1);
        test_id = test_id + 1;
        @(posedge clk); #1;
        reg_write_en = 1'b0;
        #2;
        check16(reg_read_data_1, 16'hCAFE, test_id); // new value after write
        test_id = test_id + 1;

        // ── Summary ───────────────────────────────────────────────
        $display("");
        if (fail_count == 0)
            $display("=== ALL %0d TESTS PASSED ===", test_id - 1);
        else
            $display("=== %0d / %0d TESTS FAILED ===", fail_count, test_id - 1);

        $finish;
    end

endmodule
