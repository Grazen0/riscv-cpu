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
  reg [31:0] mtvec, mtvec_next;
  reg [31:0] mepc, mepc_next;
  reg [63:0] mcycle, mcycle_next;

  always @(*) begin
    mtvec_next  = mtvec;
    mepc_next   = mepc;
    mcycle_next = mcycle + 1;

    if (wenable) begin
      case (waddr)
        `CSR_MTVEC:  mtvec_next = wdata;
        `CSR_MEPC:   mepc_next = wdata;
        `CSR_MCYCLE: mcycle_next[31:0] = wdata + 1;
        default: begin
        end
      endcase
    end

    case (raddr)
      `CSR_MTVEC:  rdata = mtvec;
      `CSR_MEPC:   rdata = mepc;
      `CSR_MCYCLE: rdata = mcycle[31:0];
      default:     rdata = {32{1'bx}};
    endcase
  end

  always @(posedge clk) begin
    mtvec  <= mtvec_next;
    mepc   <= mepc_next;
    mcycle <= mcycle_next;
  end
endmodule

