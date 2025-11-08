`default_nettype none

module irq_gate (
    input wire clk,
    input wire rst_n,

    input  wire irq,
    input  wire ack,
    output reg  irq_pending
);
  reg  irq_sync_reg;
  reg  irq_synced;

  reg  irq_prev;

  wire irq_edge = irq_synced & ~irq_prev;

  always @(posedge clk) begin
    if (!rst_n) begin
      irq_sync_reg <= 0;
      irq_synced   <= 0;
      irq_prev     <= 0;
      irq_pending  <= 0;
    end else begin
      irq_sync_reg <= irq;
      irq_synced   <= irq_sync_reg;
      irq_prev     <= irq_synced;

      if (irq_edge) irq_pending <= 1;
      else if (ack) irq_pending <= 0;
    end
  end
endmodule
