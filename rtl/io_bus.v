module io_bus (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  io_port,
    input  wire [7:0]  io_wdata,
    output wire [7:0]  io_rdata,
    input  wire        io_rd,
    input  wire        io_wr,
    output wire        io_ready,

    input  wire [7:0]  switches,
    input  wire [4:0]  buttons,
    output reg  [7:0]  leds,
    output reg  [7:0]  seg_value,
    output reg  [7:0]  seg_enable,

    output wire [7:0]  periph_port,
    output wire [7:0]  periph_wdata,
    input  wire [7:0]  periph_rdata,
    output wire        periph_rd,
    output wire        periph_wr,
    input  wire        periph_ready
);

    wire request = io_rd | io_wr;
    wire is_local  = (io_port < 8'h20);
    wire is_periph = (io_port >= 8'h20);
    wire is_sw     = (io_port == 8'h00);
    wire is_btn    = (io_port == 8'h01);
    wire is_led    = (io_port == 8'h02);
    wire is_seg_v  = (io_port == 8'h10);
    wire is_seg_e  = (io_port == 8'h11);

    reg local_ready;
    reg [7:0] local_rdata;

    always @(*) begin
        local_ready = 1'b0;
        local_rdata = 8'h00;
        if (request && is_local) begin
            local_ready = 1'b1;
            if (io_rd) begin
                case (io_port)
                    8'h00: local_rdata = switches;
                    8'h01: local_rdata = {3'b000, buttons};
                    default: local_rdata = 8'h00;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            leds       <= 8'h00;
            seg_value  <= 8'h00;
            seg_enable <= 8'h00;
        end else if (request && is_local && io_wr) begin
            case (io_port)
                8'h02: leds       <= io_wdata;
                8'h10: seg_value  <= io_wdata;
                8'h11: seg_enable <= io_wdata;
            endcase
        end
    end

    assign periph_port  = io_port;
    assign periph_wdata = io_wdata;
    assign periph_rd    = request && is_periph && io_rd;
    assign periph_wr    = request && is_periph && io_wr;

    wire periph_act = request && is_periph;
    assign io_rdata  = is_local ? local_rdata : periph_rdata;
    assign io_ready  = is_local ? local_ready : (periph_act ? periph_ready : 1'b1);

endmodule