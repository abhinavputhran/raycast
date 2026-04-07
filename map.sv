// map.sv
// 16x16 hardcoded wall map
// cell (x, y) is a wall if map_out == 1
// x = column (0=left), y = row (0=top)
// combinational ROM zero registers, zero clock needed

module map (input logic [3:0] cell_x,   // 0..15
            input logic [3:0] cell_y,   // 0..15
            output logic    is_wall);

  logic [15:0] row;

  always_comb begin
    case (cell_y)
      4'd0: row = 16'hFFFF;
      4'd1: row = 16'h8001;
      4'd2: row = 16'h9831; 
      4'd3: row = 16'h9831;
      4'd4: row = 16'h8001;
      4'd5: row = 16'hE3C7;
      4'd6: row = 16'h8001;
      4'd7: row = 16'hAA55;
      4'd8: row = 16'h8001;
      4'd9: row = 16'hBF7D;
      4'd10: row = 16'h8105;
      4'd11: row = 16'hA505;
      4'd12: row = 16'hA425;
      4'd13: row = 16'hA665;
      4'd14: row = 16'h8001;
      4'd15: row = 16'hFFFF;
      default: row = 16'hFFFF;
    endcase
    is_wall = row[15 - cell_x];
  end

endmodule: map
