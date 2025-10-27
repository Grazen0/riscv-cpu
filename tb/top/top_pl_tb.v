`timescale 1ns / 1ns `default_nettype none

module top_pl_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire clk_out;
  wire [7:0] lcd_data;
  wire [1:0] lcd_ctrl;
  wire lcd_enable;

  top_pl top (
      .clk  (clk),
      .rst_n(rst_n),

      .clk_out(clk_out),
      .lcd_data(lcd_data),
      .lcd_ctrl(lcd_ctrl),
      .lcd_enable(lcd_enable)
  );

  initial begin
    $dumpvars(0, top_pl_tb);

    $display("");

    clk   = 1;
    rst_n = 0;
    #1 rst_n = 1;

    #10_000_000;
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
