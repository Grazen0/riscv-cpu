`default_nettype none

`include "cpu_csr_file.vh"

module cpu_csr_file (
    input wire clk,
    input wire rst_n,

    input  wire [11:0] raddr,
    output reg  [31:0] rdata,

    input wire [11:0] waddr,
    input wire [31:0] wdata,
    input wire wenable
);
  reg [31:0] mtvec, mepc;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mtvec <= 0;
      mepc  <= 0;
    end else begin
      if (wenable) begin
        case (waddr)
          `CSR_MTVEC: mtvec <= wdata;
          `CSR_MEPC:  mepc <= wdata;
          default: begin
          end
        endcase
      end
    end
  end

  always @(*) begin
    case (raddr)
      `CSR_MTVEC: rdata = mtvec;
      `CSR_MEPC: rdata = mepc;
      default: rdata = {32{1'bx}};
    endcase
  end

endmodule

