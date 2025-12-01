`default_nettype none

`include "cpu_csr_file.vh"

module cpu_csr_file (
    input wire clk,
    input wire rst_n,

    input  wire [11:0] raddr,
    output reg  [31:0] rdata,

    input wire [11:0] waddr,
    input wire [31:0] wdata,
    input wire wenable,

    input wire bubble_w
);
  reg [31:0] mtvec, mtvec_next;
  reg [31:0] mepc, mepc_next;
  reg [63:0] mcycle, mcycle_next;
  reg [63:0] minstret, minstret_next;

  always @(*) begin
    mtvec_next = mtvec;
    mepc_next = mepc;
    mcycle_next = mcycle;
    minstret_next = minstret;

    if (wenable) begin
      case (waddr)
        `CSR_MTVEC:    mtvec_next = wdata;
        `CSR_MEPC:     mepc_next = wdata;
        `CSR_MCYCLE:   mcycle_next[31:0] = wdata;
        `CSR_MINSTRET: minstret_next[31:0] = wdata;
        default: begin
        end
      endcase
    end

    mcycle_next = mcycle_next + 1;

    if (!bubble_w) begin
      minstret_next = minstret_next + 1;
    end

    case (raddr)
      `CSR_MTVEC:    rdata = mtvec;
      `CSR_MEPC:     rdata = mepc;
      `CSR_MCYCLE:   rdata = mcycle[31:0];
      `CSR_MINSTRET: rdata = minstret[31:0];
      default:       rdata = {32{1'bx}};
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      mcycle   <= 0;
      minstret <= 0;
    end else begin
      mtvec    <= mtvec_next;
      mepc     <= mepc_next;
      mcycle   <= mcycle_next;
      minstret <= minstret_next;
    end
  end
endmodule

