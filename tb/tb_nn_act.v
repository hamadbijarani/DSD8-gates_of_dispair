`timescale 1ns/1ps

module tb_nn_act;

    reg  [23:0] acc;
    reg  [3:0]  shift;
    reg  [1:0]  bank;
    reg  [7:0]  lut_idx;
    wire [7:0]  qout, act, lut_val;
    integer errors;
    integer b, i, s;
    reg [7:0] lut0 [0:255];
    reg [7:0] lut1 [0:255];
    reg [7:0] lut2 [0:255];
    reg [7:0] lut3 [0:255];
    reg [7:0] exp_lut;
    reg signed [23:0] shifted;
    reg signed [7:0] exp_q;

    nn_act dut (
        .acc(acc), .shift(shift), .bank(bank), .lut_idx(lut_idx),
        .qout(qout), .act(act), .lut_val(lut_val)
    );

    initial begin
        $readmemh("nn/data/lut_relu.hex", lut0);
        $readmemh("nn/data/lut_sigmoid.hex", lut1);
        $readmemh("nn/data/lut_offset_binary.hex", lut2);
        $readmemh("nn/data/lut_tanh.hex", lut3);
    end

    task check_sat;
        input [23:0] ta;
        input [3:0] ts;
        begin
            acc = ta; shift = ts;
            #1;
            shifted = $signed(ta) >>> ts;
            if (shifted > 24'sd127) exp_q = 8'sd127;
            else if (shifted < -24'sd128) exp_q = -8'sd128;
            else exp_q = shifted[7:0];
            if (qout !== exp_q) begin
                errors = errors + 1;
                if (errors <= 20) $display("sat mismatch acc=%06h shift=%0d got=%02h exp=%02h", ta, ts, qout, exp_q);
            end
        end
    endtask

    initial begin
        errors = 0;
        bank = 0; lut_idx = 0; acc = 0; shift = 0;

        for (s = 0; s < 16; s = s + 1) begin
            check_sat(24'sh000000, s[3:0]);
            check_sat(24'sh000001, s[3:0]);
            check_sat(24'shFFFFFF, s[3:0]);
            check_sat(24'sh00007F, s[3:0]);
            check_sat(24'sh000080, s[3:0]);
            check_sat(24'shFFFF80, s[3:0]);
            check_sat(24'shFFFF81, s[3:0]);
            check_sat(24'sh7FFFFF, s[3:0]);
            check_sat(24'sh800000, s[3:0]);
            check_sat(24'sh000100, s[3:0]);
            check_sat(24'sh0001FF, s[3:0]);
        end

        for (b = 0; b < 4; b = b + 1) begin
            bank = b[1:0];
            for (i = 0; i < 256; i = i + 1) begin
                lut_idx = i[7:0];
                acc = {{16{i[7]}}, i[7:0]};
                shift = 4'h0;
                case (b)
                    0: exp_lut = lut0[i];
                    1: exp_lut = lut1[i];
                    2: exp_lut = lut2[i];
                    default: exp_lut = lut3[i];
                endcase
                #1;
                if (lut_val !== exp_lut) begin
                    errors = errors + 1;
                    if (errors <= 20) $display("lut_val mismatch bank=%0d idx=%02h got=%02h exp=%02h", b, i, lut_val, exp_lut);
                end
                if (act !== exp_lut) begin
                    errors = errors + 1;
                    if (errors <= 20) $display("act mismatch bank=%0d idx=%02h got=%02h exp=%02h", b, i, act, exp_lut);
                end
            end
        end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
