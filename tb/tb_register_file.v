`timescale 1ns/1ps

module tb_register_file;

    reg clk, rst_n, we;
    reg [2:0] ra1, ra2, wa;
    reg [7:0] wd;
    wire [7:0] rd1, rd2;
    integer errors;
    integer i;

    register_file dut (
        .clk(clk), .rst_n(rst_n),
        .ra1(ra1), .ra2(ra2), .rd1(rd1), .rd2(rd2),
        .we(we), .wa(wa), .wd(wd)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task tick;
        begin @(posedge clk); #1; end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; we = 0; wa = 0; wd = 0; ra1 = 0; ra2 = 0;
        tick;

        for (i = 0; i < 8; i = i + 1) begin
            ra1 = i; ra2 = i;
            #1;
            if (rd1 !== 8'h00 || rd2 !== 8'h00) begin
                errors = errors + 1;
                $display("reset reg %0d not zero", i);
            end
        end

        rst_n = 1;

        for (i = 0; i < 8; i = i + 1) begin
            we = 1; wa = i; wd = 8'hA0 + i;
            tick;
        end
        we = 0;

        for (i = 0; i < 8; i = i + 1) begin
            ra1 = i; ra2 = i;
            #1;
            if (rd1 !== 8'hA0 + i || rd2 !== 8'hA0 + i) begin
                errors = errors + 1;
                $display("readback reg %0d wrong: %02h %02h", i, rd1, rd2);
            end
        end

        ra1 = 2; ra2 = 5; we = 0; wa = 2; wd = 8'h7E;
        #1;
        if (rd1 !== 8'hA2) begin errors = errors + 1; $display("we=0 wrote"); end

        we = 1; wa = 2; wd = 8'h33;
        #1;
        tick;
        ra1 = 2; #1;
        if (rd1 !== 8'h33) begin errors = errors + 1; $display("write failed"); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
