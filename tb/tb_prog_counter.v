`timescale 1ns/1ps

module tb_prog_counter;

    reg clk, rst_n, pc_en, pc_load;
    reg [8:0] branch_addr;
    wire [8:0] pc;
    integer errors;

    prog_counter dut (
        .clk(clk), .rst_n(rst_n),
        .pc_en(pc_en), .pc_load(pc_load),
        .branch_addr(branch_addr), .pc(pc)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task tick;
        begin @(posedge clk); #1; end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; pc_en = 0; pc_load = 0; branch_addr = 0;
        tick; tick;
        if (pc !== 9'h000) begin errors = errors + 1; $display("reset failed: pc=%03h", pc); end
        rst_n = 1;

        pc_en = 1; pc_load = 0;
        tick; tick; tick;
        if (pc !== 9'h003) begin errors = errors + 1; $display("increment failed: pc=%03h", pc); end

        pc_en = 0;
        tick; tick;
        if (pc !== 9'h003) begin errors = errors + 1; $display("hold failed: pc=%03h", pc); end

        pc_en = 1; pc_load = 1; branch_addr = 9'h1AB;
        tick;
        if (pc !== 9'h1AB) begin errors = errors + 1; $display("load failed: pc=%03h", pc); end

        pc_en = 1; pc_load = 1; branch_addr = 9'h1FF;
        tick;
        pc_en = 1; pc_load = 0;
        tick;
        if (pc !== 9'h000) begin errors = errors + 1; $display("wrap failed: pc=%03h", pc); end

        rst_n = 0;
        tick;
        if (pc !== 9'h000) begin errors = errors + 1; $display("sync reset failed: pc=%03h", pc); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
