`timescale 1ns/1ps

// Compact system-level waveform bench. Only presentation-relevant signals are
// placed in the VCD; large memories and the full module hierarchy are omitted.
module tb_waveform;

    parameter VCD_FILE = "dsd8_wave.vcd";
    parameter MAX_CYCLES = 200;

    reg clk;
    reg rst_n;
    reg [7:0] switches;
    reg [4:0] buttons;

    wire [8:0]  imem_addr;
    wire [15:0] imem_data;
    wire [7:0]  io_port;
    wire [7:0]  io_wdata;
    wire [7:0]  io_rdata;
    wire        io_rd;
    wire        io_wr;
    wire        io_ready;
    wire [7:0]  leds;
    wire [7:0]  seg_value;
    wire [7:0]  seg_enable;

    wire [7:0] periph_port;
    wire [7:0] periph_wdata;
    wire [7:0] periph_rdata;
    wire       periph_rd;
    wire       periph_wr;
    wire       periph_ready;

    wire        halted;
    wire        retire;
    wire [8:0]  retire_pc;
    wire [15:0] retire_ir;
    wire        retire_rf_we;
    wire [2:0]  retire_rf_addr;
    wire [7:0]  retire_rf_data;
    wire        retire_mem_we;
    wire [7:0]  retire_mem_addr;
    wire [7:0]  retire_mem_data;
    wire [3:0]  retire_flags;

    // Clean aliases for the few internal signals useful in GTKWave.
    wire [3:0]  cpu_state;
    wire [8:0]  cpu_ir_pc;
    wire [15:0] cpu_ir;
    wire        nn_unlocked;
    wire        nn_mac_start;
    wire        nn_busy;
    wire [2:0]  nn_pipe_valid;
    wire [7:0]  nn_a;
    wire [15:0] nn_product;
    wire [23:0] nn_acc;
    wire [7:0]  nn_mac_count;
    wire [7:0]  nn_skip_count;

    integer cycles;
    integer errors;

    assign cpu_state     = cpu.ctrl_inst.state;
    assign cpu_ir_pc     = cpu.ir_pc;
    assign cpu_ir        = cpu.ir;
    assign nn_unlocked   = iobus.nn.unlocked;
    assign nn_mac_start  = iobus.nn.mac_start;
    assign nn_busy       = iobus.nn.busy;
    assign nn_pipe_valid = {iobus.nn.mac.v3, iobus.nn.mac.v2,
                            iobus.nn.mac.v1};
    assign nn_a          = iobus.nn.a_reg;
    assign nn_product    = iobus.nn.mac.prod_s2;
    assign nn_acc        = iobus.nn.acc;
    assign nn_mac_count  = iobus.nn.maccnt;
    assign nn_skip_count = iobus.nn.skipcnt;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    dsd8_cpu cpu (
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

    instr_memory imem (
        .clk(clk), .addr(imem_addr), .data(imem_data)
    );

    io_bus #(.NN_ENABLE(1), .NN_POSTED(0)) iobus (
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
        rst_n = 1'b0;
        switches = 8'h00;
        buttons = 5'h00;
        cycles = 0;
        errors = 0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (rst_n)
            cycles = cycles + 1;
    end

    // Probe: one tidy scope tree (tb_waveform.probe.{cpu,io,nn}) instead of
    // dumping loose nets, which makes Icarus emit one duplicate $scope per
    // signal and gives viewers a broken hierarchy.
    wave_probe probe ();

    initial begin
        $dumpfile(VCD_FILE);
        $dumpvars(0, probe);
    end

    initial begin
        @(posedge rst_n);
        while (!halted && cycles < MAX_CYCLES)
            @(posedge clk);
        repeat (2) @(posedge clk);

        if (!halted) begin
            errors = errors + 1;
            $display("WAVEFORM: processor did not halt");
        end
        if (leds !== 8'h0C) begin
            errors = errors + 1;
            $display("WAVEFORM: LEDs=%02h, expected 0c", leds);
        end
        if (nn_acc !== 24'h00000C) begin
            errors = errors + 1;
            $display("WAVEFORM: accumulator=%06h, expected 00000c", nn_acc);
        end
        if (nn_mac_count !== 8'h01 || nn_skip_count !== 8'h00) begin
            errors = errors + 1;
            $display("WAVEFORM: MAC count=%0d skip count=%0d, expected 1/0",
                     nn_mac_count, nn_skip_count);
        end

        if (errors == 0)
            $display("WAVEFORM: PASS -- LEDs=0x%02h, accumulator=0x%06h", leds, nn_acc);
        else
            $display("WAVEFORM: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule

// ---------------------------------------------------------------------------
// Waveform probe (presentation only; no logic). Each signal appears exactly
// once, grouped as tb_waveform.probe.{sys,cpu,io,nn}. Values are read from the
// testbench by upward hierarchical reference.
// ---------------------------------------------------------------------------
module wave_sys;
    wire        clk    = tb_waveform.clk;
    wire        rst_n  = tb_waveform.rst_n;
    wire        halted = tb_waveform.halted;
    wire [7:0]  leds   = tb_waveform.leds;
endmodule

module wave_cpu;
    wire [8:0]  imem_addr      = tb_waveform.imem_addr;
    wire [15:0] imem_data      = tb_waveform.imem_data;
    wire [3:0]  state          = tb_waveform.cpu_state;
    wire [8:0]  ir_pc          = tb_waveform.cpu_ir_pc;
    wire [15:0] ir             = tb_waveform.cpu_ir;
    wire        retire         = tb_waveform.retire;
    wire [8:0]  retire_pc      = tb_waveform.retire_pc;
    wire [15:0] retire_ir      = tb_waveform.retire_ir;
    wire        retire_rf_we   = tb_waveform.retire_rf_we;
    wire [2:0]  retire_rf_addr = tb_waveform.retire_rf_addr;
    wire [7:0]  retire_rf_data = tb_waveform.retire_rf_data;
    wire [3:0]  retire_flags   = tb_waveform.retire_flags;
endmodule

module wave_io;
    wire        io_rd    = tb_waveform.io_rd;
    wire        io_wr    = tb_waveform.io_wr;
    wire        io_ready = tb_waveform.io_ready;
    wire [7:0]  io_port  = tb_waveform.io_port;
    wire [7:0]  io_wdata = tb_waveform.io_wdata;
    wire [7:0]  io_rdata = tb_waveform.io_rdata;
endmodule

module wave_nn;
    wire        unlocked   = tb_waveform.nn_unlocked;
    wire        mac_start  = tb_waveform.nn_mac_start;
    wire        busy       = tb_waveform.nn_busy;
    wire [2:0]  pipe_valid = tb_waveform.nn_pipe_valid;
    wire [7:0]  a          = tb_waveform.nn_a;
    wire [15:0] product    = tb_waveform.nn_product;
    wire [23:0] acc        = tb_waveform.nn_acc;
    wire [7:0]  mac_count  = tb_waveform.nn_mac_count;
    wire [7:0]  skip_count = tb_waveform.nn_skip_count;
endmodule

module wave_probe;
    wave_sys sys ();
    wave_cpu cpu ();
    wave_io  io  ();
    wave_nn  nn  ();
endmodule
