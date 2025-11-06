`default_nettype none

module ring_oscillator #(
    parameter SIZE  = 3,
    parameter DELAY = 1
) (
    output wire out
);
  (* keep = "true" *) wire [SIZE-1:0] wires;

  genvar i;
  generate
    for (i = 0; i < SIZE; i = i + 1) begin
      if (i == 0) begin
        not #(DELAY) (wires[i], wires[SIZE-1]);
      end else begin
        not #(DELAY) (wires[i], wires[i-1]);
      end
    end
  endgenerate

  assign out = wires[0];

  // For simulation purposes
  initial begin
    force wires[0] = 1'b0;
    #(SIZE * DELAY) release wires[0];
  end
endmodule

module trng #(
    parameter RING_SIZE  = 3,
    parameter RING_DELAY = 1,
    parameter OUT_WIDTH  = 32
) (
    input  wire                 clk,
    output wire [OUT_WIDTH-1:0] out
);
  wire ro_a;
  wire ro_b;

  ring_oscillator #(
      .SIZE (RING_SIZE),
      .DELAY(RING_DELAY)
  ) oscillator_a (
      .out(ro_a)
  );

  ring_oscillator #(
      .SIZE (RING_SIZE),
      .DELAY(RING_DELAY)
  ) oscillator_b (
      .out(ro_b)
  );


  reg [OUT_WIDTH-1:0] out_raw;

  always @(posedge ro_a) begin
    out_raw <= {out_raw[OUT_WIDTH-1:0], out_raw[0] ^ ro_b};
  end

  synchronizer #(
      .WIDTH(OUT_WIDTH)
  ) sync (
      .clk(clk),
      .in (out_raw),
      .out(out)
  );

  // For simulation purposes
  initial out_raw <= 0;
endmodule
