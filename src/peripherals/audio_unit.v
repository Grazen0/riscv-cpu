`default_nettype none

module audio_unit (
    input wire clk,
    input wire rst_n,

    input wire [31:0] wdata,
    input wire wenable,
    output wire [31:0] rdata,

    output reg out
);
  reg [31:0] half_period, half_period_next;
  reg [31:0] counter, counter_next;

  reg out_next;

  always @(*) begin
    half_period_next = half_period;

    if (half_period == 0) begin
      counter_next = 0;
      out_next     = 0;
    end else begin
      counter_next = counter + 1;
      out_next     = out;

      if (counter_next == half_period) begin
        counter_next = 0;
        out_next     = ~out;
      end
    end

    if (wenable) begin
      half_period_next = wdata;
      out_next         = 0;
      counter_next     = 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter     <= 0;
      half_period <= 0;
      out         <= 0;
    end else begin
      counter     <= counter_next;
      half_period <= half_period_next;
      out         <= out_next;
    end
  end

  assign rdata = half_period;
endmodule
