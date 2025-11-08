`default_nettype none `timescale 1ns / 1ps

module nes_bridge_tb ();
  reg clk, rst_n;
  always #10 clk = ~clk;

  reg start;

  wire [7:0] rdata;
  wire scl, sda;

  nes_bridge bridge (
      .clk  (clk),
      .rst_n(rst_n),

      .start(start),

      .rdata_addr(2'b00),
      .rdata(rdata),

      .scl(scl),
      .sda(sda)
  );

  initial begin
    $dumpvars(0, nes_bridge_tb);

    clk   = 1;
    rst_n = 0;
    start = 0;

    #5 rst_n = 1;

    #20 start = 1;
    #10 start = 0;

    #100_000 $finish();
  end
endmodule
