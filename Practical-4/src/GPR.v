// =========================================================================
// Practical 4: StarCore-1 — Single-Cycle Processor in Verilog
// =========================================================================
// File        : GPR.v
// Description : General Purpose Register File. 8 x 16-bit. 2 async read,
//               1 sync write. All regs init to 0.

`timescale 1ns / 1ps
`include "../src/Parameter.v"

module GPR (
    input        clk,
    input        reg_write_en,
    input  [2:0] reg_write_dest,
    input  [15:0] reg_write_data,
    input  [2:0] reg_read_addr_1,
    output [15:0] reg_read_data_1,
    input  [2:0] reg_read_addr_2,
    output [15:0] reg_read_data_2
);

    reg [15:0] reg_array [7:0];

    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1)
            reg_array[i] <= 16'd0;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (reg_write_en)
            reg_array[reg_write_dest] <= reg_write_data;
    end

    // Asynchronous reads
    assign reg_read_data_1 = reg_array[reg_read_addr_1];
    assign reg_read_data_2 = reg_array[reg_read_addr_2];

endmodule
