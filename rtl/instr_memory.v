// instr_memory.v -- 512 x 16 read-only memory, loaded by $readmemh
// Owner: member A
// Spec: Section 5.4. Port list is FROZEN.

module instr_memory #(
    parameter IMAGE = "program.hex"
) (
    input  wire       clk,
    input  wire [8:0] addr,
    output wire [15:0] data
);

    reg [15:0] mem [0:511];
    reg [8191:0] image_path;

    initial begin
        // verilator lint_off WIDTH
        image_path = IMAGE;
        // verilator lint_on WIDTH
        if (!$value$plusargs("IMEM=%s", image_path))
            image_path = image_path;
        $readmemh(image_path, mem);
    end

    assign data = mem[addr];

    wire unused_clk = clk;

endmodule
