`default_nettype none `timescale 1ns / 1ps

module audio_unit_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire [8:0] out;

  audio_unit audio (
      .clk  (clk),
      .rst_n(rst_n),

      .wenable(1'b0),

      .out(out)
  );

  wire out_pwm;

  pwm_generator #(
      .BIT_WIDTH(8)
  ) pwm (
      .clk  (clk),
      .rst_n(rst_n),

      .duty(out),

      .out(out_pwm)
  );

  initial begin
    $dumpvars(0, audio_unit_tb);

    clk   = 1;
    rst_n = 0;
    #5 rst_n = 1;

    audio.periods[0] = 10_000;
    audio.periods[1] = 20_000;
    audio.periods[2] = 20_000;
    audio.periods[3] = 20_000;

    #2_000_000 $finish();
  end
endmodule
