`timescale 1ns/1ps

module tb_instr_decoder;

    reg  [15:0] instr;
    wire [3:0]  opcode;
    wire [2:0]  rd, rs1, rs2, cond;
    wire [7:0] imm8, port;
    wire [8:0]  addr9;
    wire        io_dir;
    integer errors;

    instr_decoder dut (
        .instr(instr), .opcode(opcode),
        .rd(rd), .rs1(rs1), .rs2(rs2),
        .imm8(imm8), .addr9(addr9),
        .cond(cond), .port(port), .io_dir(io_dir)
    );

    task expect;
        input [15:0] word;
        input [3:0] eop;
        input [2:0] erd, ers1, ers2;
        input [7:0] eimm;
        input [8:0] eaddr;
        input [2:0] econd;
        input [7:0] eport;
        input edir;
        begin
            instr = word;
            #1;
            if (opcode !== eop || rd !== erd || rs1 !== ers1 || rs2 !== ers2 ||
                imm8 !== eimm || addr9 !== eaddr || cond !== econd ||
                port !== eport || io_dir !== edir) begin
                errors = errors + 1;
                $display("decode mismatch for %04h", word);
            end
        end
    endtask

    initial begin
        errors = 0;
        expect(16'h46C8, 4'h4, 3'h3, 3'h3, 3'h1, 8'hC8, 9'h0C8, 3'h3, 8'hC8, 1'b0);
        expect(16'h120D, 4'h1, 3'h1, 3'h0, 3'h1, 8'h0D, 9'h00D, 3'h1, 8'h0D, 1'b0);
        expect(16'h54A0, 4'h5, 3'h2, 3'h2, 3'h4, 8'hA0, 9'h0A0, 3'h2, 8'hA0, 1'b0);
        expect(16'hD00A, 4'hD, 3'h0, 3'h0, 3'h1, 8'h0A, 9'h00A, 3'h0, 8'h0A, 1'b0);
        expect(16'hE702, 4'hE, 3'h3, 3'h4, 3'h0, 8'h02, 9'h102, 3'h3, 8'h02, 1'b1);
        expect(16'hEB55, 4'hE, 3'h5, 3'h5, 3'h2, 8'h55, 9'h155, 3'h5, 8'h55, 1'b1);
        expect(16'hF000, 4'hF, 3'h0, 3'h0, 3'h0, 8'h00, 9'h000, 3'h0, 8'h00, 1'b0);
        expect(16'hFFFF, 4'hF, 3'h7, 3'h7, 3'h7, 8'hFF, 9'h1FF, 3'h7, 8'hFF, 1'b1);

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
