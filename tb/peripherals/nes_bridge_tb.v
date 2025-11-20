`default_nettype none `timescale 1ns / 1ps

module nes_bridge_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  reg  start;

  wire scl_out;
  wire sda_out;

  nes_bridge bridge (
      .clk  (clk),
      .rst_n(rst_n),

      .start(start),

      .scl_out(scl_out),
      .sda_in (1'b1),
      .sda_out(sda_out)
  );

  initial begin
    $dumpvars(0, nes_bridge_tb);

    clk   = 1;
    rst_n = 0;
    start = 0;
    #1 rst_n = 1;

    #10_000 start = 1;
    #4_000 start = 0;

    #600_000 $finish();
  end
endmodule


