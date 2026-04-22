`default_nettype none

// Beam-racing pixel output for raycaster.
// Runs entirely combinationally - called every pixel clock.
//
// For each scanline, wall_tracer has already computed:
//   wall_height - how many pixels tall the wall strip is
//   wall_side   - 0 = X-axis face (light), 1 = Y-axis face (dark)
//   wall_hit    - 1 if this scanline actually hits a wall
//
// Wall strip is centered vertically:
//   wall_top = HALF_H - wall_height/2
//   wall_bot = HALF_H + wall_height/2
//
// Pixel regions:
//   vpos in [wall_top, wall_bot] and wall_hit and wall_height>0 is wall
//   vpos < HALF_H                                               is ceiling
//   vpos >= HALF_H                                              is floor
//
// Colors are RGB222 (2 bits each) to match TinyVGA PMOD.

module row_renderer #(parameter int SCREEN_H = 480,
                      parameter int HALF_H = 240) 
                      (input logic [9:0] vpos,
                      input logic visible,

                      input logic [9:0] wall_height, 
                      input logic wall_side,
                      input logic wall_hit,

                      input logic [5:0] ceil_color,
                      input logic [5:0] floor_color,
                      input logic [5:0] wall_light,
                      input logic [5:0] wall_dark,

                      output logic [1:0] red,
                      output logic [1:0] green,
                      output logic [1:0] blue);

  // Wall strip bounds centered at HALF_H
  // wall_top = HALF_H - wall_half (0)
  // wall_bot = HALF_H + wall_half (SCREEN_H-1)
  logic [9:0] wall_half;
  logic [9:0] wall_top;
  logic [9:0] wall_bot;

  assign wall_half = {1'b0, wall_height[9:1]};

  assign wall_top = (wall_half >= 10'(HALF_H))
                    ? 10'd0
                    : 10'(HALF_H) - wall_half;

  assign wall_bot = (10'(HALF_H) + wall_half >= 10'(SCREEN_H))
                    ? 10'(SCREEN_H - 1)
                    : 10'(HALF_H) + wall_half - 10'd1;

  logic in_wall;

  assign in_wall = wall_hit
                   && (wall_height > 10'd0)
                   && (vpos >= wall_top)
                   && (vpos <= wall_bot);

  logic [5:0] pixel_color;

  always_comb begin
    if (!visible) begin
      pixel_color = 6'b000000;
    end else if (in_wall) begin
      pixel_color = wall_side ? wall_dark : wall_light;
    end else if (vpos < 10'(HALF_H)) begin
      pixel_color = ceil_color;
    end else begin
      pixel_color = floor_color;
    end
  end

  assign red   = pixel_color[5:4];
  assign green = pixel_color[3:2];
  assign blue  = pixel_color[1:0];

endmodule : row_renderer
