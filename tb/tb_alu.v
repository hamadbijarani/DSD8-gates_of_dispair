`timescale 1ns/1ps

module tb_alu;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       flag_z, flag_n, flag_c, flag_v;

    integer errors;
    integer i, j, k;
    integer n_random;
    integer cov_a [0:4];
    integer cov_b [0:4];
    reg [7:0] corner [0:4];
    reg [7:0] exp_result;
    reg       exp_z, exp_n, exp_c, exp_v;

    alu dut (
        .a(a), .b(b), .op(op),
        .result(result),
        .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v)
    );

    function [7:0] ref_result;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg [8:0] add9, sub9;
        begin
            add9 = {1'b0, fa} + {1'b0, fb};
            sub9 = {1'b0, fa} + {1'b0, ~fb} + 9'h001;
            case (fop)
                4'h4: ref_result = add9[7:0];
                4'h5, 4'hB: ref_result = sub9[7:0];
                4'h6: ref_result = fa & fb;
                4'h7: ref_result = fa | fb;
                4'h8: ref_result = fa ^ fb;
                4'h9: ref_result = {fa[6:0], 1'b0};
                4'hA: ref_result = {1'b0, fa[7:1]};
                default: ref_result = 8'h00;
            endcase
        end
    endfunction

    function ref_c;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg [8:0] add9, sub9;
        begin
            add9 = {1'b0, fa} + {1'b0, fb};
            sub9 = {1'b0, fa} + {1'b0, ~fb} + 9'h001;
            case (fop)
                4'h4: ref_c = add9[8];
                4'h5, 4'hB: ref_c = sub9[8];
                4'h9: ref_c = fa[7];
                4'hA: ref_c = fa[0];
                default: ref_c = 1'b0;
            endcase
        end
    endfunction

    function ref_v;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg r7, a7;
        reg [7:0] rv;
        begin
            a7 = fa[7];
            rv = ref_result(fa, fb, fop);
            r7 = rv[7];
            case (fop)
                4'h4: ref_v = (fa[7] == fb[7]) && (r7 != a7);
                4'h5, 4'hB: ref_v = (fa[7] != fb[7]) && (r7 != a7);
                default: ref_v = 1'b0;
            endcase
        end
    endfunction

    task check;
        input [7:0] ta, tb;
        input [3:0] top;
        begin
            a = ta; b = tb; op = top;
            #1;
            exp_result = ref_result(ta, tb, top);
            exp_z = (exp_result == 8'h00);
            exp_n = exp_result[7];
            exp_c = ref_c(ta, tb, top);
            exp_v = ref_v(ta, tb, top);
            if (result !== exp_result || flag_z !== exp_z || flag_n !== exp_n ||
                flag_c !== exp_c || flag_v !== exp_v) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("Mismatch a=%02h b=%02h op=%0h got=%02h%0b%0b%0b%0b exp=%02h%0b%0b%0b%0b",
                             ta, tb, top, result, flag_z, flag_n, flag_c, flag_v,
                             exp_result, exp_z, exp_n, exp_c, exp_v);
            end
        end
    endtask

    initial begin
        errors = 0;
        n_random = 0;
        for (i = 0; i < 5; i = i + 1) begin
            cov_a[i] = 0;
            cov_b[i] = 0;
        end
        corner[0] = 8'h00; corner[1] = 8'h01; corner[2] = 8'h7F;
        corner[3] = 8'h80; corner[4] = 8'hFF;

        for (i = 0; i < 5; i = i + 1)
            for (j = 0; j < 5; j = j + 1)
                for (k = 4; k <= 11; k = k + 1)
                    check(corner[i], corner[j], k[3:0]);

        for (i = 0; i < 10000; i = i + 1) begin
            a = $random;
            b = $random;
            op = 4'h4 + (i % 8);
            check(a, b, op);
            n_random = n_random + 1;
            if (a == 8'h00) cov_a[0] = cov_a[0] + 1;
            if (a == 8'h01) cov_a[1] = cov_a[1] + 1;
            if (a == 8'h7F) cov_a[2] = cov_a[2] + 1;
            if (a == 8'h80) cov_a[3] = cov_a[3] + 1;
            if (a == 8'hFF) cov_a[4] = cov_a[4] + 1;
            if (b == 8'h00) cov_b[0] = cov_b[0] + 1;
            if (b == 8'h01) cov_b[1] = cov_b[1] + 1;
            if (b == 8'h7F) cov_b[2] = cov_b[2] + 1;
            if (b == 8'h80) cov_b[3] = cov_b[3] + 1;
            if (b == 8'hFF) cov_b[4] = cov_b[4] + 1;
        end

        $display("random vectors: %0d", n_random);
        $display("corner coverage a: %0d %0d %0d %0d %0d", cov_a[0], cov_a[1], cov_a[2], cov_a[3], cov_a[4]);
        $display("corner coverage b: %0d %0d %0d %0d %0d", cov_b[0], cov_b[1], cov_b[2], cov_b[3], cov_b[4]);

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
