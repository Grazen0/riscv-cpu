`default_nettype none

module irq_gate (
    input wire clk,
    input wire rst_n,

    input  wire irq,
    input  wire ack,
    output reg  irq_pending
);
  wire irq_synced;
  reg  irq_prev;

  wire irq_edge = irq_synced & ~irq_prev;

  synchronizer sync (
      .clk(clk),
      .in (irq),
      .out(irq_synced)
  );


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_prev    <= 0;
      irq_pending <= 0;
    end else begin
      irq_prev <= irq_synced;

      if (irq_edge) begin
        irq_pending <= 1;
      end else if (ack) begin
        irq_pending <= 0;
      end
    end
  end
endmodule
