// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : DataMemory.v
// Description : 8-word data RAM. Sync write, async read (gated by mem_read).
//               Address indexing: ram_addr = mem_access_addr[2:0]

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module DataMemory (
    input        clk,
    input  [15:0] mem_access_addr,
    input  [15:0] mem_write_data,
    input        mem_write_en,
    input        mem_read,
    output [15:0] mem_read_data
);

    reg [`COL-1:0] memory [`ROW_D-1:0];

    // Word address: lower 3 bits of byte address
    wire [2:0] ram_addr = mem_access_addr[2:0];

    integer log_fd;
    initial begin
        $readmemb("./test.data", memory, 0, 7);
    end

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write_en)
            memory[ram_addr] <= mem_write_data;
    end

    // Combinational gated read
    assign mem_read_data = mem_read ? memory[ram_addr] : 16'd0;

endmodule