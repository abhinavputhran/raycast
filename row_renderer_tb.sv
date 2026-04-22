`default_nettype none

`timescale 1ns/1ps

module row_renderer_tb;
  logic [9:0] vpos;
  logic visible;
  logic [9:0] wall_height;
  logic wall_side;
  logic wall_hit;
  logic [5:0] ceil_color;
  logic [5:0] floor_color;
  logic [5:0] wall_light;
  logic [5:0] wall_dark;
  logic [1:0] red, green, blue;

  int pass_count = 0;
  int fail_count = 0;

  row_renderer #(.SCREEN_H(480), .HALF_H(240)) dut (.*);

  localparam logic [5:0] CEIL_COL = 6'b000001; // blue 
  localparam logic [5:0] FLOOR_COL = 6'b000100; // green
  localparam logic [5:0] WALL_LT = 6'b101010; // grey
  localparam logic [5:0] WALL_DK = 6'b010101; // dark grey

  task automatic setup_defaults;
    visible = 1;
    wall_hit = 1;
    wall_side = 0;
    ceil_color = CEIL_COL;
    floor_color = FLOOR_COL;
    wall_light = WALL_LT;
    wall_dark = WALL_DK;
  endtask

  task automatic check_rgb(input logic [1:0] er, eg, eb,
                            input string desc);
    #1;
    if (red === er && green === eg && blue === eb) begin
      $display("PASS %s  RGB=%0d%0d%0d", desc, red, green, blue);
      pass_count++;
    end else begin
      $display("FAIL %s  expected=%0d%0d%0d  got=%0d%0d%0d",
        desc, er, eg, eb, red, green, blue);
      fail_count++;
    end
  endtask

  initial begin
    $display("row_renderer.sv testbench");
    setup_defaults();

    // Test 1: wall_height=240
    //   wall_half = 120
    //   wall_top  = 240 - 120 = 120
    //   wall_bot  = 240 + 120 - 1 = 359
    //   ceiling: 0..119
    //   wall:    120..359
    //   floor:   360..479
    $display("\nTest 1: wall_height=240 (rows 120..359) ");
    wall_height = 10'd240;
    wall_side   = 0;
    vpos = 10'd0; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=0   ceiling");
    vpos = 10'd119; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=119 ceiling");
    vpos = 10'd120; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=120 wall top");
    vpos = 10'd240; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=240 wall mid");
    vpos = 10'd359; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=359 wall bot");
    vpos = 10'd360; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=360 floor");
    vpos = 10'd479; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=479 floor");

    // Test 2: dark side
    $display("\nTest 2: dark side (wall_side=1)");
    wall_height = 10'd240;
    wall_side  = 1;
    vpos = 10'd240;
    check_rgb(WALL_DK[5:4], WALL_DK[3:2], WALL_DK[1:0], "vpos=240 dark wall");

    // Test 3: wall_height=480 -> full screen wall
    //   wall_half=240, wall_top clamped to 0, wall_bot clamped to 479
    $display("\nTest 3: wall_height=480 (full screen)");
    wall_height = 10'd480;
    wall_side = 0;
    vpos = 10'd0; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=0   full wall");
    vpos = 10'd240; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=240 full wall");
    vpos = 10'd479; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=479 full wall");

    // Test 4: wall_height=0 -> no wall strip at all
    //   wall_half=0, but in_wall guard prevents any wall pixels
    //   vpos=240 must be floor
    $display("\nTest 4: wall_height=0 (no wall strip)");
    wall_height = 10'd0;
    wall_side = 0;
    vpos = 10'd0; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=0   ceiling");
    vpos = 10'd239; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=239 ceiling");
    vpos = 10'd240; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=240 floor (not wall)");
    vpos = 10'd479; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=479 floor");

    // Test 5: wall_hit=0 -> ceiling/floor only regardless of height
    $display("\nTest 5: wall_hit=0 (no hit)");
    wall_hit = 0;
    wall_height = 10'd480;
    vpos = 10'd100; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=100 ceiling");
    vpos = 10'd400; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=400 floor");
    wall_hit = 1;

    // Test 6: visible=0 -> all black
    $display("\nTest 6: visible=0 (blanking)");
    visible = 0;
    wall_height = 10'd240;
    vpos = 10'd240;
    check_rgb(2'd0, 2'd0, 2'd0, "vpos=240 blanking -> black");
    visible = 1;

    // Test 7: wall_height=60
    //   wall_half = 30
    //   wall_top  = 240 - 30 = 210
    //   wall_bot  = 240 + 30 - 1 = 269
    //   ceiling: 0..209
    //   wall:    210..269
    //   floor:   270..479
    $display("\n Test 7: wall_height=60 (rows 210..269) ");
    wall_height = 10'd60;
    wall_side = 0;
    vpos = 10'd209; check_rgb(CEIL_COL[5:4], CEIL_COL[3:2], CEIL_COL[1:0], "vpos=209 ceiling");
    vpos = 10'd210; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=210 wall top");
    vpos = 10'd240; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=240 wall mid");
    vpos = 10'd269; check_rgb(WALL_LT[5:4], WALL_LT[3:2], WALL_LT[1:0], "vpos=269 wall bot");
    vpos = 10'd270; check_rgb(FLOOR_COL[5:4], FLOOR_COL[3:2], FLOOR_COL[1:0], "vpos=270 floor");

    $display("\nResults: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else $display("FAILURES DETECTED");
    $finish;
  end

endmodule: row_renderer_tb
