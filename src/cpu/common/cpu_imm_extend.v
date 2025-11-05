`default_nettype none

`include "cpu_imm_extend.vh"

module cpu_imm_extend (
    input  wire [24:0] data,
    input  wire [ 2:0] imm_src,
    output reg  [31:0] imm_ext
);
  wire [11:0] imm_i = data[24:13];
  wire [11:0] imm_s = {data[24:18], data[4:0]};
  wire [12:0] imm_b = {data[24], data[0], data[23:18], data[4:1], 1'b0};
  wire [31:0] imm_u = {data[24:5], 12'b0};
  wire [20:0] imm_j = {data[24], data[12:5], data[13], data[23:14], 1'b0};

  always @(*) begin
    case (imm_src)
      `IMM_SRC_I: imm_ext = {{20{imm_i[11]}}, imm_i};
      `IMM_SRC_S: imm_ext = {{20{imm_s[11]}}, imm_s};
      `IMM_SRC_B: imm_ext = {{19{imm_b[12]}}, imm_b};
      `IMM_SRC_U: imm_ext = imm_u;
      `IMM_SRC_J: imm_ext = {{11{imm_j[20]}}, imm_j};
      default:    imm_ext = {32{1'bx}};
    endcase
  end
endmodule

