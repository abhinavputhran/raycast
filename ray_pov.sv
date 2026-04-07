`default_nettype none

// Player point-of-view registers: position, direction, viewplane
// All values are Q10.10 fixed point (20 bits: 10 integer, 10 fractional)
//
// SPI protocol (mode 0, MSB first):
//   Assert cs_n low, clock in 120 bits on sclk rising edge:
//   [119:100] pos_x
//   [99:80] pos_y
//   [79:60] dir_x
//   [59:40] dir_y
//   [39:20] plane_x
//   [19:0] plane_y
//   Deassert cs_n: staging regs are marked valid
//   At vblank, staging regs swap into live regs
//
// inc_px / inc_py: demo mode: continuously nudge position each frame
//   When either is asserted, SPI writes are ignored (safe override)
//
// Default reset state faces player down a corridor so something
// renders immediately without needing SPI.

module ray_pov (
  input logic clk, reset,

  input logic spi_cs_n,
  input logic spi_clk,
  input logic spi_mosi,

  input logic inc_px,
  input logic inc_py,

  input logic vblank,

  output logic [19:0] pos_x, pos_y,
  output logic [19:0] dir_x, dir_y,
  output logic [19:0] plane_x, plane_y);

  // Q10.10 fixed-point constants
  // Format: value * 2^10 = value * 1024
  // Player starts at map position (3.5, 7.5) 
  localparam [19:0] INIT_POS_X = 20'(int'(3.5 * 1024)); // 3584
  localparam [19:0] INIT_POS_Y = 20'(int'(7.5 * 1024)); // 7680
  
  localparam [19:0] INIT_DIR_X = 20'(int'(1.0 * 1024)); // 1024
  localparam [19:0] INIT_DIR_Y = 20'(int'(0.0 * 1024)); // 0
  // Viewplane perpendicular to dir, length ~0.66 gives ~66 deg FOV
  // plane = (0.0, 0.66)
  localparam [19:0] INIT_PLANE_X = 20'(int'(0.0 * 1024)); // 0
  localparam [19:0] INIT_PLANE_Y = 20'(int'(0.66 * 1024)); // 675

  // Small nudge per frame in demo mode: 0.02 units
  localparam [19:0] NUDGE = 20'(int'(0.02 * 1024)); // 20

  // SPI shift register: 120 bits (6 regs * 20 bits each)
  logic [119:0] shift_reg;
  logic spi_clk_prev;
  logic spi_cs_prev;
  logic [6:0] bit_count;   // counts 0..119
  logic staging_valid;

  // Staging registers (written by SPI)
  logic [19:0] stg_pos_x, stg_pos_y;
  logic [19:0] stg_dir_x, stg_dir_y;
  logic [19:0] stg_plane_x, stg_plane_y;

  // Live registers
  logic [19:0] live_pos_x, live_pos_y;
  logic [19:0] live_dir_x, live_dir_y;
  logic [19:0] live_plane_x, live_plane_y;

  assign pos_x = live_pos_x;
  assign pos_y = live_pos_y;
  assign dir_x = live_dir_x;
  assign dir_y = live_dir_y;
  assign plane_x = live_plane_x;
  assign plane_y = live_plane_y;

  always_ff @(posedge clk) begin
    spi_clk_prev <= spi_clk;
    spi_cs_prev <= spi_cs_n;

    if (reset) begin
      shift_reg <= '0;
      bit_count <= '0;
      staging_valid <= 1'b0;
      stg_pos_x <= INIT_POS_X;
      stg_pos_y <= INIT_POS_Y;
      stg_dir_x <= INIT_DIR_X;
      stg_dir_y <= INIT_DIR_Y;
      stg_plane_x <= INIT_PLANE_X;
      stg_plane_y <= INIT_PLANE_Y;
    end else if (inc_px || inc_py) begin
      // Demo mode overrides SPI entirely
      staging_valid <= 1'b0;
    end else begin
      if (!spi_cs_n && !spi_clk_prev && spi_clk) begin
        shift_reg <= {shift_reg[118:0], spi_mosi};
        bit_count <= bit_count + 7'd1;
      end

      if (spi_cs_n && !spi_cs_prev) begin
        if (bit_count == 7'd120) begin
          stg_pos_x <= shift_reg[119:100];
          stg_pos_y <= shift_reg[99:80];
          stg_dir_x <= shift_reg[79:60];
          stg_dir_y <= shift_reg[59:40];
          stg_plane_x <= shift_reg[39:20];
          stg_plane_y <= shift_reg[19:0];
          staging_valid <= 1'b1;
        end
        bit_count <= '0;
      end

      if (spi_cs_n && spi_cs_prev) begin
          // already handled above
      end
    end
  end

  // Live register update: swap at VBLANK or apply demo nudge
  always_ff @(posedge clk) begin
      if (reset) begin
          live_pos_x <= INIT_POS_X;
          live_pos_y <= INIT_POS_Y;
          live_dir_x <= INIT_DIR_X;
          live_dir_y <= INIT_DIR_Y;
          live_plane_x <= INIT_PLANE_X;
          live_plane_y <= INIT_PLANE_Y;
      end else if (vblank) begin
          if (inc_px || inc_py) begin
              // Demo mode
              if (inc_px) live_pos_x <= live_pos_x + NUDGE;
              if (inc_py) live_pos_y <= live_pos_y + NUDGE;
          end else if (staging_valid) begin
              // SPI wrote a complete frame 
              live_pos_x <= stg_pos_x;
              live_pos_y <= stg_pos_y;
              live_dir_x <= stg_dir_x;
              live_dir_y <= stg_dir_y;
              live_plane_x <= stg_plane_x;
              live_plane_y <= stg_plane_y;
          end
          // if neither, static scene
      end
  end

endmodule: ray_pov
