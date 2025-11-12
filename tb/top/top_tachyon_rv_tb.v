`timescale 1ns / 1ps `default_nettype none

module top_tachyon_rv_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire [3:0] vga_red;
  wire [3:0] vga_green;
  wire [3:0] vga_blue;
  wire       h_sync;
  wire       v_sync;

  wire [7:0] lcd_data;
  wire [1:0] lcd_ctrl;
  wire       lcd_enable;

  wire       audio_out;

  tri1       joypad_scl_pin;
  tri1       joypad_sda_pin;

  top_tachyon_rv top (
      .clk  (clk),
      .rst_n(rst_n),

      .joypad_scl_pin(joypad_scl_pin),
      .joypad_sda_pin(joypad_sda_pin),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable),

      .vga_red  (vga_red),
      .vga_green(vga_green),
      .vga_blue (vga_blue),
      .h_sync   (h_sync),
      .v_sync   (v_sync),

      .audio_out(audio_out)
  );

  initial begin
    $dumpvars(0, top_tachyon_rv_tb);

    $display("");

    clk   = 1;
    rst_n = 0;
    #5 rst_n = 1;

    #1_000_000;
    $display("");
    $display("");

    $finish();
  end

  always @(negedge lcd_enable) begin
    if (lcd_ctrl == 2'b10) begin
      $write("%c", lcd_data);
    end
  end
endmodule
