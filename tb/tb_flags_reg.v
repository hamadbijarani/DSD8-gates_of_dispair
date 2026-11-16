`timescale 1ns/1ps

module tb_flags_reg;

    reg clk, rst_n, flags_we;
    reg [3:0] flags_in;
    wire [3:0] flags_out;
    integer errors;

    flags_reg dut (
        .clk(clk), .rst_n(rst_n),
        .flags_we(flags_we), .flags_in(flags_in),
        .flags_out(flags_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst_n = 0; flags_we = 0; flags_in = 4'h0;
        @(posedge clk); #1;

        if (flags_out !== 4'h0) begin errors = errors + 1; $display("reset not zero"); end

        rst_n = 1;
        flags_we = 1; flags_in = 4'hA;
        @(posedge clk); #1;
        if (flags_out !== 4'hA) begin errors = errors + 1; $display("write failed"); end

        flags_we = 0; flags_in = 4'h5;
        @(posedge clk); #1;
        if (flags_out !== 4'hA) begin errors = errors + 1; $display("hold failed"); end

        flags_we = 1; flags_in = 4'h5;
        @(posedge clk); #1;
        if (flags_out !== 4'h5) begin errors = errors + 1; $display("second write failed"); end

        rst_n = 0;
        @(posedge clk); #1;
        if (flags_out !== 4'h0) begin errors = errors + 1; $display("sync reset failed"); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
