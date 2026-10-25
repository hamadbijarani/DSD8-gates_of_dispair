`timescale 1ns/1ps

module tb_control_unit;

    reg clk, rst_n, io_ready, io_dir;
    reg [3:0] opcode;
    reg [2:0] cond;
    reg [3:0] flags;
    wire pc_en, pc_load, rf_we, mem_we, io_rd, io_wr, flags_we, halted, retire;
    wire [1:0] wb_sel;
    integer errors;

    control_unit dut (
        .clk(clk), .rst_n(rst_n), .opcode(opcode), .cond(cond),
        .flags(flags), .io_ready(io_ready), .io_dir(io_dir),
        .pc_en(pc_en), .pc_load(pc_load), .rf_we(rf_we), .mem_we(mem_we),
        .io_rd(io_rd), .io_wr(io_wr), .flags_we(flags_we), .wb_sel(wb_sel),
        .halted(halted), .retire(retire)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task tick;
        begin @(posedge clk); #1; end
    endtask

    task reset_dut;
        begin
            rst_n = 0; opcode = 0; cond = 0; flags = 0; io_ready = 1; io_dir = 0;
            tick; tick;
            rst_n = 1;
        end
    endtask

    task to_execute;
        input [3:0] op;
        input [2:0] cd;
        begin
            opcode = op; cond = cd;
            tick;
            tick;
        end
    endtask

    initial begin
        errors = 0;

        reset_dut;
        if (pc_en !== 1'b1) begin errors = errors + 1; $display("fetch pc_en low"); end
        if (retire !== 1'b0) begin errors = errors + 1; $display("retire high in fetch"); end

        reset_dut;
        to_execute(4'hF, 3'h0);
        if (halted !== 1'b1) begin errors = errors + 1; $display("HLT did not halt"); end

        reset_dut;
        to_execute(4'hC, 3'h0);
        if (pc_load !== 1'b1 || pc_en !== 1'b1) begin errors = errors + 1; $display("JMP did not load pc"); end

        reset_dut;
        flags = 4'b1000;
        to_execute(4'hD, 3'h0);
        if (pc_load !== 1'b1 || pc_en !== 1'b1) begin errors = errors + 1; $display("BEQ not taken with Z=1"); end

        reset_dut;
        flags = 4'b0000;
        to_execute(4'hD, 3'h0);
        if (pc_load !== 1'b0 || pc_en !== 1'b0) begin errors = errors + 1; $display("BEQ taken with Z=0"); end

        reset_dut;
        flags = 4'b0000;
        to_execute(4'hD, 3'h5);
        if (pc_load !== 1'b1) begin errors = errors + 1; $display("BPL wrong"); end

        reset_dut;
        to_execute(4'h4, 3'h0);
        if (rf_we !== 1'b0 || flags_we !== 1'b1) begin errors = errors + 1; $display("ADD controls wrong in execute"); end

        reset_dut;
        tick; tick;
        opcode = 4'h2;
        tick;
        reset_dut;
        to_execute(4'h2, 3'h0);
        tick;
        if (io_rd !== 1'b0) begin errors = errors + 1; $display("LD asserted io_rd"); end
        if (mem_we !== 1'b0) begin errors = errors + 1; $display("LD asserted mem_we before writeback"); end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
