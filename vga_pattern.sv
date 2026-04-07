`default_nettype none

module pattern_gen (input logic [9:0] hpos,
                    input logic [9:0] vpos,
                    input logic visible,
                    output logic [5:0] rgb);

    localparam HMID = 320;
    localparam VMID = 240;

    logic border = (hpos == 0) || (hpos == 639) ||
                   (vpos == 0) || (vpos == 479);

    logic [2:0] bar_col = hpos[7:5]; 
    logic [5:0] vbar_rgb =(bar_col == 0) ? 6'b00_00_11 :  // red
                          (bar_col == 1) ? 6'b00_11_00 :  // green
                          (bar_col == 2) ? 6'b11_00_00 :  // blue
                          (bar_col == 3) ? 6'b00_11_11 :  // yellow
                          (bar_col == 4) ? 6'b11_00_11 :  // cyan
                          (bar_col == 5) ? 6'b11_11_00 :  // magenta
                          (bar_col == 6) ? 6'b11_11_11 :  // white
                                           6'b01_01_01 ;  // grey

    logic [2:0] hbar_row = vpos[7:5];
    logic [5:0] hbar_rgb = (hbar_row == 0) ? 6'b00_00_11 :
                          (hbar_row == 1) ? 6'b00_11_00 :
                          (hbar_row == 2) ? 6'b11_00_00 :
                          (hbar_row == 3) ? 6'b00_11_11 :
                          (hbar_row == 4) ? 6'b11_00_11 :
                          (hbar_row == 5) ? 6'b11_11_00 :
                          (hbar_row == 6) ? 6'b11_11_11 :
                                            6'b01_01_01 ;

    logic check = hpos[4] ^ vpos[4]; // bit 4 = every 16px
    logic [5:0] check_rgb = check ? 6'b11_11_11 : 6'b00_00_00;

    // R = top 2 bits of (hpos - 320), scaled to 2 bits
    // G = top 2 bits of (vpos - 240), scaled to 2 bits
    logic [9:0] qx = hpos - 10'd320;
    logic [9:0] qy = vpos - 10'd240;
    logic [5:0] grad_rgb2 = {qx[8:7], qy[7:6], qx[8:7]};

    logic top_half = (vpos < VMID);
    logic left_half = (hpos < HMID);

    logic [5:0] quad_rgb = (top_half && left_half) ? vbar_rgb :   // TL: vertical bars
                           (top_half && !left_half) ? hbar_rgb :   // TR: horizontal bars
                           (!top_half && left_half) ? check_rgb :   // BL: check
                                                       grad_rgb2 ;   // BR: gradient

    logic divider = (hpos == HMID) || (vpos == VMID);

    assign rgb = !visible ? 6'd0 :
                  border ? 6'b11_11_11 :   // white border
                  divider ? 6'b01_01_01 :   // grey cross
                             quad_rgb;

endmodule
