`timescale 1ns/1ps

module tb_dsd8_cpu;

    reg clk, rst_n;
    wire [8:0] imem_addr;
    wire [15:0] imem_data;
    wire [7:0] io_port, io_wdata;
    reg  [7:0] io_rdata;
    wire io_rd, io_wr;
    reg  io_ready;
    wire halted, retire;
    wire [8:0] retire_pc;
    wire [15:0] retire_ir;
    wire retire_rf_we, retire_mem_we;
    wire [2:0] retire_rf_addr;
    wire [7:0] retire_rf_data, retire_mem_addr, retire_mem_data;
    wire [3:0] retire_flags;

    integer errors;
    integer cycles;
    integer retired;
    reg [7:0] leds;

    dsd8_cpu dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata),
        .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready),
        .halted(halted), .retire(retire),
        .retire_pc(retire_pc), .retire_ir(retire_ir),
        .retire_rf_we(retire_rf_we), .retire_rf_addr(retire_rf_addr),
        .retire_rf_data(retire_rf_data),
        .retire_mem_we(retire_mem_we), .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data), .retire_flags(retire_flags)
    );

    instr_memory #(.IMAGE("tb/cpu_test.hex")) imem (
        .clk(clk), .addr(imem_addr), .data(imem_data)
    );

    initial begin
        io_rdata = 8'h00;
        io_ready = 1'b1;
    end

    always @(posedge clk) begin
        if (retire) retired = retired + 1;
        if (io_wr && io_port == 8'h02) leds <= io_wdata;
    end

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0; cycles = 0; retired = 0; leds = 8'h00;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        while (!halted && cycles < 200000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        #1;
        if (!halted) begin errors = errors + 1; $display("did not halt"); end
        if (retired != 51) begin errors = errors + 1; $display("retired %0d, expected 51", retired); end
        if (leds !== 8'h5B) begin errors = errors + 1; $display("LEDs %02h, expected 5B", leds); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
