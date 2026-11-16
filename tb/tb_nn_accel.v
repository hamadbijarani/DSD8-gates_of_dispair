`timescale 1ns/1ps

module tb_nn_accel;

    reg clk, rst_n;
    reg [7:0] io_port, io_wdata;
    reg io_rd, io_wr;
    wire [7:0] rd0, rd1;
    wire ready0, ready1;
    integer errors;
    integer stalls;

    nn_accel #(.POSTED(0)) dut0 (
        .clk(clk), .rst_n(rst_n), .io_port(io_port), .io_wdata(io_wdata),
        .io_rdata(rd0), .io_rd(io_rd), .io_wr(io_wr), .io_ready(ready0)
    );

    nn_accel #(.POSTED(1)) dut1 (
        .clk(clk), .rst_n(rst_n), .io_port(io_port), .io_wdata(io_wdata),
        .io_rdata(rd1), .io_rd(io_rd), .io_wr(io_wr), .io_ready(ready1)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task wr;
        input [7:0] port, val;
        input       which;
        begin
            io_port = port; io_wdata = val; io_wr = 1; io_rd = 0;
            stalls = 0;
            #1;
            while (!(which ? ready1 : ready0)) begin
                @(posedge clk); #1;
                stalls = stalls + 1;
                if (stalls > 4) begin
                    errors = errors + 1;
                    $display("write stall > 4 on port %02h", port);
                end
            end
            @(posedge clk); #1;
            io_wr = 0;
        end
    endtask

    task rd;
        input [7:0] port;
        input       which;
        output [7:0] val;
        begin
            io_port = port; io_wr = 0; io_rd = 1;
            stalls = 0;
            #1;
            while (!(which ? ready1 : ready0)) begin
                @(posedge clk); #1;
                stalls = stalls + 1;
                if (stalls > 4) begin
                    errors = errors + 1;
                    $display("read stall > 4 on port %02h", port);
                end
            end
            val = which ? rd1 : rd0;
            @(posedge clk); #1;
            io_rd = 0;
        end
    endtask

    task expect_rd;
        input [7:0] port, exp;
        input       which;
        reg [7:0] got;
        begin
            rd(port, which, got);
            if (got !== exp) begin
                errors = errors + 1;
                $display("read port %02h got %02h exp %02h", port, got, exp);
            end
        end
    endtask

    task reset_all;
        begin
            rst_n = 0; io_port = 0; io_wdata = 0; io_rd = 0; io_wr = 0;
            repeat (3) @(posedge clk);
            #1;
            rst_n = 1;
        end
    endtask

    initial begin
        errors = 0;
        reset_all;

        if (ready0 !== 1'b0 || ready1 !== 1'b0) begin
            errors = errors + 1;
            $display("ready high without request");
        end

        // locked: every port reads 0, writes discarded
        expect_rd(8'h50, 8'h00, 0);
        expect_rd(8'h53, 8'h00, 0);
        expect_rd(8'h59, 8'h00, 0);
        expect_rd(8'h5C, 8'h00, 0);
        expect_rd(8'h5F, 8'h00, 0);
        wr(8'h50, 8'h7F, 0);
        wr(8'h51, 8'h7F, 0);
        expect_rd(8'h53, 8'h00, 0);

        // wrong keys never unlock
        wr(8'h5F, 8'h00, 0);
        expect_rd(8'h5F, 8'h00, 0);
        wr(8'h5F, 8'hA4, 0);
        expect_rd(8'h5F, 8'h00, 0);

        // correct key unlocks
        wr(8'h5F, 8'hA5, 0);
        expect_rd(8'h5F, 8'h01, 0);

        // relock
        wr(8'h5F, 8'h00, 0);
        expect_rd(8'h5F, 8'h00, 0);
        wr(8'h5F, 8'hA5, 0);

        // clear acc and counters, shift 0
        wr(8'h52, 8'h03, 0);
        wr(8'h56, 8'h00, 0);

        // basic MAC 3*5
        wr(8'h50, 8'h03, 0);
        wr(8'h51, 8'h05, 0);
        expect_rd(8'h53, 8'h0F, 0);
        expect_rd(8'h54, 8'h00, 0);
        expect_rd(8'h55, 8'h00, 0);

        // zero-skip: A=0 and W=0
        wr(8'h50, 8'h00, 0);
        wr(8'h51, 8'h09, 0);
        wr(8'h50, 8'h02, 0);
        wr(8'h51, 8'h00, 0);
        expect_rd(8'h5C, 8'h02, 0);
        expect_rd(8'h5D, 8'h01, 0);
        expect_rd(8'h53, 8'h0F, 0);

        // signed product -2 * 3
        wr(8'h50, 8'hFE, 0);
        wr(8'h51, 8'h03, 0);
        expect_rd(8'h53, 8'h09, 0);

        // forced stall: second W issued while the first is in flight
        wr(8'h50, 8'h01, 0);
        io_port = 8'h51; io_wdata = 8'h01; io_wr = 1; io_rd = 0;
        @(posedge clk); #1;
        io_wr = 0;
        io_port = 8'h51; io_wdata = 8'h01; io_wr = 1;
        stalls = 0;
        #1;
        while (!ready0) begin
            @(posedge clk); #1;
            stalls = stalls + 1;
            if (stalls > 4) begin errors = errors + 1; $display("stall > 4"); end
        end
        if (stalls == 0) begin errors = errors + 1; $display("no stall observed"); end
        @(posedge clk); #1;
        io_wr = 0;
        expect_rd(8'h53, 8'h0B, 0);
        expect_rd(8'h5D, 8'h04, 0);

        // hazard read right after W
        wr(8'h50, 8'h01, 0);
        io_port = 8'h51; io_wdata = 8'h01; io_wr = 1; io_rd = 0;
        @(posedge clk); #1;
        io_wr = 0;
        expect_rd(8'h53, 8'h0C, 0);

        // requant shift and LUT
        wr(8'h52, 8'h01, 0);
        wr(8'h56, 8'h01, 0);
        wr(8'h50, 8'h64, 0);
        wr(8'h51, 8'h01, 0);
        expect_rd(8'h57, 8'h32, 0);
        wr(8'h58, 8'h00, 0);
        expect_rd(8'h59, 8'h32, 0);
        wr(8'h58, 8'h02, 0);
        wr(8'h5A, 8'h05, 0);
        expect_rd(8'h5B, 8'h85, 0);

        // posted: three back-to-back MACs, then drain on read
        wr(8'h5F, 8'hA5, 1);
        wr(8'h52, 8'h03, 1);
        wr(8'h50, 8'h02, 1);
        wr(8'h51, 8'h03, 1);
        wr(8'h51, 8'h03, 1);
        wr(8'h51, 8'h03, 1);
        expect_rd(8'h53, 8'h12, 1);
        expect_rd(8'h5D, 8'h03, 1);

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
