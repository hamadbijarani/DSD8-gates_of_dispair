// cnn_periph.v -- CNN stream peripheral (sim-only, ports 0x44-0x46).
//
// Streams the per-sample byte stream the CNN programs consume:
//   0x44 (W): skip the pointer to the next sample boundary (+252 bytes)
//   0x45 (R): next stream byte (image phase)
//   0x46 (R): next stream byte (weight phase)
// 0x45/0x46 are two windows on ONE sequential pointer into a 16128-byte
// stream (64 samples x 252 bytes: 64 img + 4x10 convW + 4x37 fcW each).
// Every accepted read returns stream[ptr] and advances the pointer by
// exactly one. The stream file is chosen with +CNNSTREAM=<hex file> and
// the starting sample with +CNNSAMP=<index> (default 0), mirroring how
// instr_memory picks its image with +IMEM.
module cnn_periph #(
    parameter STREAM = "stream.hex"
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  periph_port,
    input  wire [7:0]  periph_wdata,
    output reg  [7:0]  periph_rdata,
    input  wire        periph_rd,
    input  wire        periph_wr,
    output reg         periph_ready
);

    localparam SAMPLE_BYTES = 252;
    localparam N_SAMPLES    = 64;
    localparam STREAM_END   = N_SAMPLES * SAMPLE_BYTES;   // 16128

    reg [7:0]    stream [0:STREAM_END - 1];
    reg [13:0]   ptr;
    reg [8191:0] stream_path;
    integer      i, samp;

    wire hit     = (periph_port == 8'h44) || (periph_port == 8'h45)
                 || (periph_port == 8'h46);
    wire request = (periph_rd | periph_wr) && hit;

    initial begin
        // verilator lint_off WIDTH
        stream_path = STREAM;
        // verilator lint_on WIDTH
        if (!$value$plusargs("CNNSTREAM=%s", stream_path))
            stream_path = stream_path;
        for (i = 0; i < STREAM_END; i = i + 1)
            stream[i] = 8'h00;
        $readmemh(stream_path, stream);
        ptr = 14'd0;
        if ($value$plusargs("CNNSAMP=%d", samp))
            ptr = samp[13:0] * SAMPLE_BYTES;
    end

    // port decode: ready only on request, like every reference peripheral
    always @(*) begin
        periph_rdata = 8'h00;
        periph_ready = 1'b0;
        if (request) begin
            case (periph_port)
                8'h45, 8'h46: begin
                    periph_rdata = stream[ptr];
                    periph_ready = 1'b1;
                end
                default: periph_ready = 1'b1;   // 0x44 write: accepted at once
            endcase
        end
    end

    // pointer motion: one step per accepted read; a 0x44 write skips to
    // the next sample boundary (wrapping after the last sample). The
    // pointer is a power-on parameter (set from +CNNSAMP in the initial
    // block), not reset state: re-running a bench is a fresh vvp process.
    always @(posedge clk) begin
        if (periph_rd && periph_ready) begin
            if (ptr == STREAM_END - 1) ptr <= 14'd0;
            else                       ptr <= ptr + 14'd1;
        end else if (periph_wr && periph_ready
                     && periph_port == 8'h44) begin
            ptr <= (((ptr / SAMPLE_BYTES) + 1) % N_SAMPLES) * SAMPLE_BYTES;
        end
    end

    wire unused_wdata = periph_wdata;   // any 0x44 write skips; value ignored

endmodule
