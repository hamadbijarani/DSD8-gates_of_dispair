// nn_act.v -- arithmetic requantisation, int8 saturation and LUT activation
module nn_act (
    input  wire [23:0] acc,
    input  wire [3:0]  shift,
    input  wire [1:0]  bank,
    input  wire [7:0]  lut_idx,
    output wire [7:0]  qout,
    output wire [7:0]  act,
    output wire [7:0]  lut_val
);

    reg signed [23:0] shifted;
    reg signed [7:0]  sat;

    always @(*) begin
        shifted = $signed(acc) >>> shift;
        if (shifted > 24'sd127)
            sat = 8'sd127;
        else if (shifted < -24'sd128)
            sat = -8'sd128;
        else
            sat = shifted[7:0];
    end

    assign qout = sat;

    nn_lut_rom rom_act (
        .bank(bank), .idx(sat), .val(act)
    );

    nn_lut_rom rom_idx (
        .bank(bank), .idx(lut_idx), .val(lut_val)
    );

endmodule
