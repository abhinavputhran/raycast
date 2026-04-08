`default_nettype none

// Computes wall_height = SCREEN_H / dist for raycaster row renderer
//
// Input: distance is perpendicular wall distance, Q10.10 unsigned (20 bits)
// Output: height is wall strip height in pixels, clamped to SCREEN_H
//
// Algorithm (trying no LUT):
//   1. LZC: find highest set bit position in dist
//   2. Normalize dist into [1.0, 2.0) by shifting
//   3. Approximate 1/norm = 2 - norm  (linear approx over [1,2))
//   4. Denormalize by undoing the shift
//   5. Multiply by SCREEN_H and shift down

module recip #(parameter int SCREEN_H = 480) 
              (input logic [19:0] distance,
               output logic [19:0] height);

  // Step 1: find position of highest set bit
  logic [4:0] lzc;

  always_comb begin
    casez (distance)
      20'b1???????????????????: lzc = 5'd0;
      20'b01??????????????????: lzc = 5'd1;
      20'b001?????????????????: lzc = 5'd2;
      20'b0001????????????????: lzc = 5'd3;
      20'b00001???????????????: lzc = 5'd4;
      20'b000001??????????????: lzc = 5'd5;
      20'b0000001?????????????: lzc = 5'd6;
      20'b00000001????????????: lzc = 5'd7;
      20'b000000001???????????: lzc = 5'd8;
      20'b0000000001??????????: lzc = 5'd9;
      20'b00000000001?????????: lzc = 5'd10;
      20'b000000000001????????: lzc = 5'd11;
      20'b0000000000001???????: lzc = 5'd12;
      20'b00000000000001??????: lzc = 5'd13;
      20'b000000000000001?????: lzc = 5'd14;
      20'b0000000000000001????: lzc = 5'd15;
      20'b00000000000000001???: lzc = 5'd16;
      20'b000000000000000001??: lzc = 5'd17;
      20'b0000000000000000001?: lzc = 5'd18;
      20'b00000000000000000001: lzc = 5'd19;
      default: lzc = 5'd19;
    endcase
  end

  // Step 2: normalize dist into [1024, 2047] so [1.0, 2.0) Q10.10
  logic [19:0] norm;
  logic [4:0] shift_amt;
  logic shift_left;

  always_comb begin
    if (lzc <= 5'd9) begin
      shift_amt  = 5'd9 - lzc;
      shift_left = 1'b0;
      norm = distance >> (5'd9 - lzc);
    end else begin
      shift_amt  = lzc - 5'd9;
      shift_left = 1'b1;
      norm = distance << (lzc - 5'd9);
    end
  end

  // Step 3: approximate 1/norm using linear approximation
  logic [19:0] recip_norm;

  always_comb begin
    recip_norm = 20'd2048 - norm;  // 2.0 - norm in Q10.10
  end

  // Step 4: undo the normalization shift
  logic [30:0] recip_q;

  always_comb begin
    if (!shift_left)
      recip_q = 31'(recip_norm) >> shift_amt;
    else
      recip_q = 31'(recip_norm) << shift_amt;
  end

  // Step 5: height = (recip_q * SCREEN_H) >> 10
  logic [39:0] h_full;
  logic [19:0] h_raw;
  assign h_full = recip_q * 32'(SCREEN_H);
  assign h_raw  = h_full[29:10];

  always_comb begin
    if (distance == '0 || h_raw > 20'(SCREEN_H))
      height = 20'(SCREEN_H);
    else
      height = h_raw;
  end

endmodule: recip
