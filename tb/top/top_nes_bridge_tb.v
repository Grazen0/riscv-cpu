`default_nettype none `timescale 1ns / 1ps

module top_nes_bridge_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire [7:0] led;
  wire scl;
  wire sda;

  top_nes_bridge top (
      .clk  (clk),
      .rst_n(rst_n),
      .led  (led),

      .scl(scl),
      .sda(sda)
  );

  initial begin
    $dumpvars(0, top_nes_bridge_tb);

    clk   = 1;
    rst_n = 0;
    #1 rst_n = 1;

    #2_000_000 $finish();
  end
endmodule
