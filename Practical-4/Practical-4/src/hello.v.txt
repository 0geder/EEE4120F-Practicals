// hello.v -- installation verification

module hello;

initial begin
    $display("iverilog is working! Time = %0t", $time);
    $finish;
end

endmodule