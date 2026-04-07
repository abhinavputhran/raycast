`default_nettype none

module vga_top (
    input logic clk,
    input logic reset,
    output logic hsync_n,
    output logic vsync_n,
    output logic [5:0] rgb,
    output logic [9:0] hpos,
    output logic [9:0] vpos);
    logic hsync, vsync, visible, hmax, vmax;

    assign hsync_n = ~hsync;
    assign vsync_n = ~vsync;

    vga u_sync (.clk(clk), .reset(reset),
                .hpos(hpos), .vpos(vpos),
                .hsync(hsync), .vsync(vsync),
                .visible(visible), .hmax(hmax), .vmax(vmax));

    pattern_gen u_pattern (.hpos(hpos), .vpos(vpos),
                            .visible(visible),
                            .rgb(rgb));
endmodule
