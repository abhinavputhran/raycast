`default_nettype none

module vga #(parameter H_VIEW = 640,
             parameter H_FRONT = 16,
             parameter H_SYNC = 96,
             parameter H_BACK = 48,
             parameter V_VIEW = 480,
             parameter V_FRONT = 10,
             parameter V_SYNC = 2,
             parameter V_BACK = 33) 
            (input logic clk, reset,
             output logic [9:0] hpos, vpos,
             output logic hsync, vsync,
             output logic visible,
             output logic hmax, vmax);

  localparam H_FULL = H_VIEW + H_FRONT + H_SYNC + H_BACK;
  localparam V_FULL = V_VIEW + V_FRONT + V_SYNC + V_BACK;
  localparam H_SYNC_START = H_VIEW + H_FRONT;
  localparam H_SYNC_END = H_SYNC_START + H_SYNC;
  localparam V_SYNC_START = V_VIEW + V_FRONT;
  localparam V_SYNC_END = V_SYNC_START + V_SYNC;

  assign hmax = (hpos == H_FULL - 1);
  assign vmax = (vpos == V_FULL - 1);
  // visible
  assign visible = (hpos < H_VIEW) && (vpos < V_VIEW);

  always_ff @(posedge clk) begin
    if (reset) hpos <= '0;
    else if (hmax) hpos <= '0;
    else hpos <= hpos + 10'd1;
  end

  always_ff @(posedge clk) begin
    if (reset) vpos <= '0;
    else if (hmax) vpos <= vmax ? 10'd0 : vpos + 10'd1;
  end

  // sync or not
  always_ff @(posedge clk) begin
    if (reset) hsync <= 0;
    else if (hpos == H_SYNC_START-1) hsync <= 1;
    else if (hpos == H_SYNC_END-1) hsync <= 0;
  end

  // sync or not
  always_ff @(posedge clk) begin
    if (reset) vsync <= 0;
    else if (vpos == V_SYNC_START-1 && hmax) vsync <= 1;
    else if (vpos == V_SYNC_END-1 && hmax) vsync <= 0;
  end
endmodule: vga

