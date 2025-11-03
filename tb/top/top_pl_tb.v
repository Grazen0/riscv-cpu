`timescale 1ns / 1ps `default_nettype none

module top_pl_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire [3:0] vga_red;
  wire [3:0] vga_green;
  wire [3:0] vga_blue;
  wire h_sync;
  wire v_sync;

  wire [7:0] lcd_data;
  wire [1:0] lcd_ctrl;
  wire lcd_enable;

  top_pl top (
      .clk  (clk),
      .rst_n(rst_n),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable),

      .vga_red(vga_red),
      .vga_green(vga_green),
      .vga_blue(vga_blue),
      .h_sync(h_sync),
      .v_sync(v_sync)
  );

  integer i, j;

  initial begin
    $dumpvars(0, top_pl_tb);

    $display("");

    clk   = 1;
    rst_n = 0;
    #1 rst_n = 1;

    #100_000;
    $display("");
    $display("");

    // for (i = 0; i < 16; i = i + 1) begin
    //   for (j = 0; j < 4; j = j + 1) begin
    //     $write("%h ", top.ram.data[(16*i)+j]);
    //   end
    //   $display("");
    // end

    $finish();
  end

  always @(negedge lcd_enable) begin
    if (lcd_ctrl == 2'b10) begin
      $write("%c", lcd_data);
    end
  end
endmodule
