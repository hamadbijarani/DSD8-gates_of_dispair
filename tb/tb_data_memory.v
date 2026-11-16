`timescale 1ns/1ps

module tb_data_memory;

    reg clk, we;
    reg [7:0] addr, wdata;
    wire [7:0] rdata;
    integer errors;
    integer i;

    data_memory dut (
        .clk(clk), .addr(addr), .we(we),
        .wdata(wdata), .rdata(rdata)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            addr = i; #1;
            if (rdata !== 8'h00) begin
                errors = errors + 1;
                $display("addr %0d not zero at start", i);
            end
        end

        we = 1; addr = 8'h12; wdata = 8'hAB;
        @(posedge clk); #1;
        we = 0;

        addr = 8'h12; #1;
        if (rdata !== 8'hAB) begin errors = errors + 1; $display("write failed"); end

        addr = 8'h13; #1;
        if (rdata !== 8'h00) begin errors = errors + 1; $display("neighbour corrupted"); end

        addr = 8'hFF; wdata = 8'h5A; we = 1;
        @(posedge clk); #1;
        we = 0;
        addr = 8'hFF; #1;
        if (rdata !== 8'h5A) begin errors = errors + 1; $display("top addr failed"); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
