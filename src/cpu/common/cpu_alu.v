`default_nettype none

`include "cpu_alu.vh"

module cpu_alu (
    input wire [31:0] src_a,
    input wire [31:0] src_b,
    input wire [ 3:0] control,

    output reg  [31:0] result,
    output reg         carry,
    output reg         borrow,
    output wire        zero,
    output reg         overflow,
    output reg         lt
);
  wire signed [31:0] src_a_signed = src_a;
  wire signed [31:0] src_b_signed = src_b;

  wire [4:0] shamt = src_b[4:0];

  always @(*) begin
    carry    = 0;
    borrow   = 0;
    overflow = 0;
    lt       = 0;

    casez (control)
      `ALU_ADD: begin
        {carry, result} = {1'b0, src_a} + {1'b0, src_b};
        overflow = (src_a[31] != src_b[31]) && (result[31] != src_a[31]);
      end
      `ALU_SUB: begin
        {carry, result} = {1'b1, src_a} - {1'b0, src_b};
        borrow = ~carry;
        overflow = (src_a[31] != src_b[31]) && (result[31] != src_a[31]);
        lt = result[31] ^ overflow;
      end
      `ALU_SLL:     result = src_a << shamt;
      `ALU_SLT:     result = {31'b0, src_a_signed < src_b_signed};
      `ALU_SLTU:    result = {31'b0, src_a < src_b};
      `ALU_XOR:     result = src_a ^ src_b;
      `ALU_SRL:     result = src_a >> shamt;
      `ALU_SRA:     result = src_a_signed >>> shamt;
      `ALU_OR:      result = src_a | src_b;
      `ALU_AND:     result = src_a & src_b;
      `ALU_PASS_A:  result = src_a;
      `ALU_PASS_B:  result = src_b;
      `ALU_AND_NOT: result = src_a & ~src_b;
      default:      result = {32{1'bx}};
    endcase
  end

  assign zero = result == 0;
endmodule
