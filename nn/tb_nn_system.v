`timescale 1ns/1ps

module tb_nn_system;

    parameter TRACE_FILE = "dut.trace";
    parameter METRICS_FILE = "metrics.txt";
    parameter MAX_CYCLES = 2000000;
    parameter POSTED = 0;

    reg clk, rst_n;
    wire [8:0]  imem_addr;
    wire [15:0] imem_data;
    wire [7:0]  io_port, io_wdata, io_rdata;
    wire        io_rd, io_wr, io_ready;
    reg  [7:0]  switches;
    reg  [4:0]  buttons;
    wire [7:0]  leds, seg_value, seg_enable;
    wire [7:0]  periph_port, periph_wdata, periph_rdata;
    wire        periph_rd, periph_wr, periph_ready;
    wire        halted, retire;
    wire [8:0]  retire_pc;
    wire [15:0] retire_ir;
    wire        retire_rf_we, retire_mem_we;
    wire [2:0]  retire_rf_addr;
    wire [7:0]  retire_rf_data, retire_mem_addr, retire_mem_data;
    wire [3:0]  retire_flags;

    integer f, fm;
    integer seq, cycles, retired, errors;
    integer start_cycle, end_cycle;
    integer stall_run;
    reg     seen_start, seen_end;

    initial clk = 0;
    always #5 clk = ~clk;

    dsd8_cpu uut (
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

    instr_memory imem (.clk(clk), .addr(imem_addr), .data(imem_data));

    io_bus #(.NN_ENABLE(1), .NN_POSTED(POSTED)) iobus (
        .clk(clk), .rst_n(rst_n),
        .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata),
        .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready),
        .switches(switches), .buttons(buttons),
        .leds(leds), .seg_value(seg_value), .seg_enable(seg_enable),
        .periph_port(periph_port), .periph_wdata(periph_wdata),
        .periph_rdata(periph_rdata), .periph_rd(periph_rd),
        .periph_wr(periph_wr), .periph_ready(periph_ready)
    );

    dsd8_ref_peripherals periphs (
        .clk(clk), .rst_n(rst_n),
        .periph_port(periph_port), .periph_wdata(periph_wdata),
        .periph_rdata(periph_rdata), .periph_rd(periph_rd),
        .periph_wr(periph_wr), .periph_ready(periph_ready)
    );

    initial begin
        rst_n = 0;
        switches = 8'h00;
        buttons = 5'h00;
        repeat (4) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        f = $fopen(TRACE_FILE, "w");
        fm = $fopen(METRICS_FILE, "w");
        seq = 1;
        cycles = 0;
        retired = 0;
        errors = 0;
        start_cycle = -1;
        end_cycle = -1;
        stall_run = 0;
        seen_start = 0;
        seen_end = 0;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycles = cycles + 1;
            if (retire) begin
                $fdisplay(f, "%04d %03x %04x %01d %01d %02x %01d %02x %02x %01d%01d%01d%01d",
                          seq, retire_pc, retire_ir,
                          retire_rf_we, retire_rf_addr, retire_rf_data,
                          retire_mem_we, retire_mem_addr, retire_mem_data,
                          retire_flags[3], retire_flags[2], retire_flags[1], retire_flags[0]);
                seq <= seq + 1;
                retired = retired + 1;
            end

            if (io_ready && !(io_rd || io_wr)) begin
                errors = errors + 1;
                $display("ready without request at cycle %0d", cycles);
            end

            if ((io_rd || io_wr) && !io_ready) begin
                stall_run = stall_run + 1;
                if (stall_run >= 4) begin
                    errors = errors + 1;
                    $display("stall > 4 at cycle %0d port %02h", cycles, io_port);
                end
            end else begin
                stall_run = 0;
            end

            if (io_wr && io_port == 8'h02 && io_wdata == 8'h01 && !seen_start) begin
                start_cycle = cycles;
                seen_start = 1;
            end
            if (io_wr && io_port == 8'h02 && io_wdata == 8'h02 && !seen_end) begin
                end_cycle = cycles;
                seen_end = 1;
            end
        end
    end

    initial begin
        @(posedge rst_n);
        while (!halted && cycles < MAX_CYCLES) @(posedge clk);
        if (!halted) $display("WARNING: hit MAX_CYCLES");
        repeat (2) @(posedge clk);
        $fdisplay(fm, "cycles %0d", cycles);
        $fdisplay(fm, "start %0d", start_cycle);
        $fdisplay(fm, "end %0d", end_cycle);
        $fdisplay(fm, "retired %0d", retired);
        $fdisplay(fm, "errors %0d", errors);
        $fdisplay(fm, "leds %02x", leds);
        $fclose(f);
        $fclose(fm);
        $finish;
    end

endmodule
