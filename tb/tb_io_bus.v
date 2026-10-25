`timescale 1ns/1ps

module tb_io_bus;

    reg clk, rst_n;
    reg [7:0] io_port, io_wdata;
    reg io_rd, io_wr;
    reg [7:0] switches;
    reg [4:0] buttons;
    wire [7:0] io_rdata;
    wire io_ready;
    wire [7:0] leds, seg_value, seg_enable;
    wire [7:0] periph_port, periph_wdata;
    reg  [7:0] periph_rdata;
    wire periph_rd, periph_wr;
    reg  periph_ready;
    integer errors;
    integer stalls;

    io_bus dut (
        .clk(clk), .rst_n(rst_n),
        .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata),
        .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready),
        .switches(switches), .buttons(buttons),
        .leds(leds), .seg_value(seg_value), .seg_enable(seg_enable),
        .periph_port(periph_port), .periph_wdata(periph_wdata),
        .periph_rdata(periph_rdata), .periph_rd(periph_rd),
        .periph_wr(periph_wr), .periph_ready(periph_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst_n = 0; io_port = 0; io_wdata = 0; io_rd = 0; io_wr = 0;
        switches = 8'h00; buttons = 5'h00; periph_rdata = 8'h00; periph_ready = 1'b0;
        @(posedge clk); #1;
        rst_n = 1;

        io_rd = 0; io_wr = 0; io_port = 8'h00;
        #1;
        if (io_ready !== 1'b0) begin errors = errors + 1; $display("ready high with no request"); end

        switches = 8'hC3; buttons = 5'h15;
        io_port = 8'h00; io_rd = 1;
        #1;
        if (io_rdata !== 8'hC3 || io_ready !== 1'b1) begin errors = errors + 1; $display("switch read bad"); end

        io_port = 8'h01;
        #1;
        if (io_rdata !== 8'h15 || io_ready !== 1'b1) begin errors = errors + 1; $display("button read bad"); end
        io_rd = 0;

        io_wr = 1;
        io_port = 8'h02; io_wdata = 8'hAA;
        @(posedge clk); #1;
        io_wr = 0;
        if (leds !== 8'hAA) begin errors = errors + 1; $display("LED write bad"); end

        io_wr = 1; io_port = 8'h10; io_wdata = 8'h11;
        @(posedge clk); #1;
        io_wr = 0;
        if (seg_value !== 8'h11) begin errors = errors + 1; $display("seg_value write bad"); end

        io_wr = 1; io_port = 8'h11; io_wdata = 8'h0F;
        @(posedge clk); #1;
        io_wr = 0;
        if (seg_enable !== 8'h0F) begin errors = errors + 1; $display("seg_enable write bad"); end

        io_port = 8'h7F; io_rd = 1; periph_ready = 1'b0;
        #1;
        if (io_ready !== 1'b0) begin errors = errors + 1; $display("peripheral ready not forwarded"); end
        if (periph_rd !== 1'b1 || periph_port !== 8'h7F) begin errors = errors + 1; $display("forwarding bad"); end
        periph_rdata = 8'h5E; periph_ready = 1'b1;
        #1;
        if (io_rdata !== 8'h5E || io_ready !== 1'b1) begin errors = errors + 1; $display("periph read bad"); end
        io_rd = 0;

        io_port = 8'h20; io_wr = 1; io_wdata = 8'h77; periph_ready = 1'b1;
        #1;
        if (periph_wr !== 1'b1 || periph_wdata !== 8'h77 || io_ready !== 1'b1) begin
            errors = errors + 1; $display("periph write bad");
        end
        io_wr = 0;

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
