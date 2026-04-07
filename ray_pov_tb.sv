`default_nettype none

// Tests:
//   1. Reset state matches expected initial values
//   2. SPI write of known values lands in staging
//   3. Values don't go live until vblank
//   4. Values go live exactly at vblank
//   5. A second SPI write replaces staging before vblank
//   6. inc_px / inc_py nudges position at vblank
//   7. Partial SPI write (< 120 bits) is ignored

`timescale 1ns/1ps

module ray_pov_tb;

  localparam CLK_PERIOD = 40;
  localparam SPI_PERIOD = 200;

  logic clk = 0, reset = 1;
  logic spi_cs_n = 1, spi_clk = 0, spi_mosi = 0;
  logic inc_px = 0, inc_py = 0;
  logic vblank = 0;

  logic [19:0] pos_x, pos_y, dir_x, dir_y, plane_x, plane_y;

  int pass_count = 0;
  int fail_count = 0;

  ray_pov dut (.*);

  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic pulse_vblank;
    @(posedge clk); #1;
    vblank = 1;
    @(posedge clk); #1;
    vblank = 0;
  endtask

  task automatic check20(
    input logic [19:0] got, expected,
    input string desc
  );
    if (got === expected) begin
      $display("PASS %s = 0x%05X (%0d)", desc, got, got);
      pass_count++;
    end else begin
      $display("FAIL %s: expected 0x%05X (%0d) got 0x%05X (%0d)",
               desc, expected, expected, got, got);
      fail_count++;
    end
  endtask

  // SPI: send 120-bit payload MSB first
  // payload layout matches module:
  // [119:100] pos_x  [99:80] pos_y
  // [79:60]   dir_x  [59:40] dir_y
  // [39:20]   plane_x [19:0] plane_y
  task automatic spi_send(
    input logic [19:0] px, py, dx, dy, plx, ply
  );
    logic [119:0] payload;
    payload = {px, py, dx, dy, plx, ply};

    spi_cs_n = 0;
    #(SPI_PERIOD/2);

    for (int i = 119; i >= 0; i--) begin
      spi_mosi = payload[i];
      #(SPI_PERIOD/2);
      spi_clk = 1;
      #(SPI_PERIOD/2);
      spi_clk = 0;
    end

    spi_cs_n = 1;
    spi_mosi = 0;
    #(SPI_PERIOD);
  endtask

  task automatic spi_send_partial(input int bits);
    spi_cs_n = 0;
    #(SPI_PERIOD/2);
    for (int i = 0; i < bits; i++) begin
      spi_mosi = 1;
      #(SPI_PERIOD/2);
      spi_clk = 1;
      #(SPI_PERIOD/2);
      spi_clk = 0;
    end
    spi_cs_n = 1;
    spi_mosi = 0;
    #(SPI_PERIOD);
  endtask

  // Q10.10 constants (mirrors module)
  localparam [19:0] INIT_POS_X = 20'(int'(3.5 * 1024));
  localparam [19:0] INIT_POS_Y = 20'(int'(7.5 * 1024));
  localparam [19:0] INIT_DIR_X = 20'(int'(1.0 * 1024));
  localparam [19:0] INIT_DIR_Y = 20'(int'(0.0 * 1024));
  localparam [19:0] INIT_PLANE_X = 20'(int'(0.0 * 1024));
  localparam [19:0] INIT_PLANE_Y = 20'(int'(0.66 * 1024));
  localparam [19:0] NUDGE = 20'(int'(0.02 * 1024));

  // Test values for SPI writes
  localparam [19:0] T_PX = 20'(int'(5.0 * 1024));
  localparam [19:0] T_PY = 20'(int'(5.0 * 1024));
  localparam [19:0] T_DX = 20'(int'(0.0 * 1024));
  localparam [19:0] T_DY = 20'(int'(1.0 * 1024));
  localparam [19:0] T_PLX = 20'(int'(0.66 * 1024));
  localparam [19:0] T_PLY = 20'(int'(0.0 * 1024));

  // Second 
  localparam [19:0] T2_PX = 20'(int'(2.0 * 1024));
  localparam [19:0] T2_PY = 20'(int'(9.0 * 1024));
  localparam [19:0] T2_DX = 20'(int'(0.707 * 1024));
  localparam [19:0] T2_DY = 20'(int'(0.707 * 1024));
  localparam [19:0] T2_PLX = 20'(int'(0.5 * 1024));
  localparam [19:0] T2_PLY = 20'(int'(0.5 * 1024));

  initial begin
    $display("tb start");

    reset = 1;
    repeat(4) @(posedge clk); #1;
    reset = 0;
    @(posedge clk); #1;

    // Test 1: Reset state
    $display("\nTest 1: Reset state");
    check20(pos_x, INIT_POS_X, "pos_x reset");
    check20(pos_y, INIT_POS_Y, "pos_y reset");
    check20(dir_x, INIT_DIR_X, "dir_x reset");
    check20(dir_y, INIT_DIR_Y, "dir_y reset");
    check20(plane_x, INIT_PLANE_X, "plane_x reset");
    check20(plane_y, INIT_PLANE_Y, "plane_y reset");

    // Test 2: SPI write does not change live regs immediately
    $display("\nTest 2: SPI write held in staging until vblank");
    spi_send(T_PX, T_PY, T_DX, T_DY, T_PLX, T_PLY);
    @(posedge clk); #1;

    // Live regs should still be init values
    check20(pos_x, INIT_POS_X, "pos_x unchanged before vblank");
    check20(pos_y, INIT_POS_Y, "pos_y unchanged before vblank");
    check20(dir_x, INIT_DIR_X, "dir_x unchanged before vblank");

    // Test 3: vblank swaps staging to live
    $display("\nTest 3: Values go live at vblank");
    pulse_vblank();
    @(posedge clk); #1;

    check20(pos_x, T_PX, "pos_x after vblank");
    check20(pos_y, T_PY, "pos_y after vblank");
    check20(dir_x, T_DX, "dir_x after vblank");
    check20(dir_y, T_DY, "dir_y after vblank");
    check20(plane_x, T_PLX, "plane_x after vblank");
    check20(plane_y, T_PLY, "plane_y after vblank");

    // Test 4: Second SPI write replaces staging; only LATEST
    //         value appears at next vblank
    $display("\nTest 4: Second SPI write wins at next vblank");
    spi_send(T_PX, T_PY, T_DX, T_DY, T_PLX, T_PLY); // first write
    spi_send(T2_PX, T2_PY, T2_DX, T2_DY, T2_PLX, T2_PLY); // overwrite
    pulse_vblank();
    @(posedge clk); #1;

    check20(pos_x, T2_PX, "pos_x second write wins");
    check20(pos_y, T2_PY, "pos_y second write wins");
    check20(dir_x, T2_DX, "dir_x second write wins");
    check20(plane_x, T2_PLX, "plane_x second write wins");

    // Test 5: Partial SPI write (< 120 bits) is ignored
    $display("\nTest 5: Partial SPI write ignored");
    spi_send_partial(60);
    pulse_vblank();
    @(posedge clk); #1;

    // Live regs should still be T2 values
    check20(pos_x, T2_PX, "pos_x partial write ignored");
    check20(pos_y, T2_PY, "pos_y partial write ignored");

    // Test 6: inc_px nudges pos_x by NUDGE each vblank
    $display("\nTest 6: inc_px demo nudge");
    inc_px = 1;
    begin
      logic [19:0] before_x;
      before_x = pos_x;
      pulse_vblank();
      @(posedge clk); #1;
      check20(pos_x, before_x + NUDGE, "pos_x nudged +NUDGE");
      // A second vblank nudges again
      before_x = pos_x;
      pulse_vblank();
      @(posedge clk); #1;
      check20(pos_x, before_x + NUDGE, "pos_x nudged again");
    end
    inc_px = 0;

    // Test 7: inc_py nudges pos_y, pos_x unchanged
    $display("\nTest 7: inc_py demo nudge");
    inc_py = 1;
    begin
      logic [19:0] before_x, before_y;
      before_x = pos_x;
      before_y = pos_y;
      pulse_vblank();
      @(posedge clk); #1;
      check20(pos_y, before_y + NUDGE, "pos_y nudged");
      check20(pos_x, before_x, "pos_x unchanged when only inc_py");
    end
    inc_py = 0;

    // Summary
    $display("\nResults: %0d passed, %0d failed",
             pass_count, fail_count);
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("FAILURES DETECTED");

    $finish;
  end

endmodule: ray_pov_tb
