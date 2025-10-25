`default_nettype none

`include "single_cycle_cpu.vh"
`include "cpu_imm_extend.vh"
`include "cpu_alu.vh"

module scc_control (
    input wire [6:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire alu_zero,
    input wire alu_lt,
    input wire alu_borrow,

    output reg [2:0] branch_type,
    output reg [1:0] result_src,
    output reg [2:0] data_ext_control,
    output reg [3:0] mem_write,
    output reg [3:0] alu_control,
    output reg alu_src,
    output reg [2:0] imm_src,
    output reg reg_write
);
  always @(*) begin
    branch_type = `BRANCH_NONE;
    result_src = `RESULT_SRC_ALU;
    mem_write = 4'b0000;
    alu_control = 4'b1111;
    alu_src = `ALU_SRC_RD;
    imm_src = `IMM_SRC_I;
    reg_write = 0;

    case (op)
      7'b0000011: begin  // load
        imm_src = `IMM_SRC_I;
        alu_src = `ALU_SRC_IMM;
        alu_control = `ALU_ADD;
        result_src = `RESULT_SRC_DATA;
        reg_write = 1;
        data_ext_control = funct3;
      end
      7'b0010011: begin  // alu (immediate)
        imm_src = `IMM_SRC_I;
        alu_src = `ALU_SRC_IMM;
        alu_control = {(funct3 == 3'b101) ? funct7[5] : 1'b0, funct3};
        result_src = `RESULT_SRC_ALU;
        reg_write = 1;
      end
      7'b0010111: begin  // auipc
        imm_src = `IMM_SRC_U;
        result_src = `RESULT_SRC_PC_TARGET;
        reg_write = 1;
      end
      7'b0100011: begin  // store
        imm_src = `IMM_SRC_S;
        alu_src = `ALU_SRC_IMM;
        alu_control = `ALU_ADD;
        result_src = `RESULT_SRC_ALU;

        case (funct3)
          3'b000:  mem_write = 4'b0001;
          3'b001:  mem_write = 4'b0011;
          3'b010:  mem_write = 4'b1111;
          default: mem_write = 4'b0000;
        endcase
      end
      7'b0110011: begin  // alu (registers)
        alu_src = `ALU_SRC_RD;
        alu_control = {funct7[5], funct3};
        result_src = `RESULT_SRC_ALU;
        reg_write = 1;
      end
      7'b0110111: begin  // lui
        imm_src = `IMM_SRC_U;
        alu_src = `ALU_SRC_IMM;
        alu_control = `ALU_PASS_B;
        result_src = `RESULT_SRC_ALU;
        reg_write = 1;
      end
      7'b1100011: begin  // branch instructions
        imm_src = `IMM_SRC_B;
        alu_src = `ALU_SRC_RD;
        alu_control = `ALU_SUB;
        branch_type = `BRANCH_COND;
      end
      7'b1100111: begin  // jalr
        imm_src = `IMM_SRC_I;
        alu_src = `ALU_SRC_IMM;
        alu_control = `ALU_ADD;
        branch_type = `BRANCH_JALR;

        result_src = `RESULT_SRC_PC_STEP;
        reg_write = 1;
      end
      7'b1101111: begin  // jal
        imm_src = `IMM_SRC_J;
        branch_type = `BRANCH_JAL;

        result_src = `RESULT_SRC_PC_STEP;
        reg_write = 1;
      end
      default: begin
        // $display("Unknown op: %h", op);
        branch_type = `BRANCH_BREAK;
      end
    endcase
  end
endmodule

module scc_branch_logic (
    input wire [2:0] branch_type,
    input wire [2:0] funct3,
    input wire alu_zero,
    input wire alu_lt,
    input wire alu_borrow,

    output reg [1:0] pc_src
);
  always @(*) begin
    case (branch_type)
      `BRANCH_NONE: pc_src = `PC_SRC_STEP;
      `BRANCH_JALR: pc_src = `PC_SRC_ALU;
      `BRANCH_JAL: pc_src = `PC_SRC_JUMP;
      `BRANCH_BREAK: pc_src = `PC_SRC_CURRENT;
      `BRANCH_COND: begin
        pc_src = `PC_SRC_STEP;

        case (funct3)
          3'b000:  if (alu_zero) pc_src = `PC_SRC_JUMP;  // beq
          3'b001:  if (!alu_zero) pc_src = `PC_SRC_JUMP;  // bne
          3'b100:  if (alu_lt) pc_src = `PC_SRC_JUMP;  // blt
          3'b101:  if (!alu_lt) pc_src = `PC_SRC_JUMP;  // bge
          3'b110:  if (alu_borrow) pc_src = `PC_SRC_JUMP;  // bltu
          3'b111:  if (!alu_borrow) pc_src = `PC_SRC_JUMP;  // bgeu
          default: pc_src = {2'bxx};
        endcase
      end
      default: pc_src = {2'bxx};
    endcase
  end
endmodule

module single_cycle_cpu (
    input wire clk,
    input wire rst_n,

    output wire [31:0] instr_addr,
    input  wire [31:0] instr_data,

    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    output wire [ 3:0] data_wenable,
    input  wire [31:0] data_rdata
);
  reg [31:0] pc;

  wire [1:0] pc_src;
  wire [2:0] branch_type;
  wire [1:0] result_src;
  wire mem_write;
  wire [3:0] alu_control;
  wire alu_src;
  wire [2:0] imm_src;

  wire reg_write;
  wire alu_zero, alu_borrow, alu_lt;
  wire [2:0] data_ext_control;

  wire [6:0] op = instr_data[6:0];
  wire [2:0] funct3 = instr_data[14:12];
  wire [6:0] funct7 = instr_data[31:25];

  scc_control control (
      .op(op),
      .funct3(funct3),
      .funct7(funct7),

      .branch_type(branch_type),
      .result_src(result_src),
      .mem_write(data_wenable),
      .data_ext_control(data_ext_control),
      .alu_control(alu_control),
      .alu_src(alu_src),
      .imm_src(imm_src),
      .reg_write(reg_write)
  );

  scc_branch_logic branch_logic (
      .branch_type(branch_type),
      .funct3(funct3),
      .alu_zero(alu_zero),
      .alu_borrow(alu_borrow),
      .alu_lt(alu_lt),

      .pc_src(pc_src)
  );

  wire [31:0] imm_ext;

  cpu_imm_extend imm_extend (
      .data(instr_data[31:7]),
      .imm_src(imm_src),
      .imm_ext(imm_ext)
  );

  wire [31:0] pc_target = pc + imm_ext;
  wire [31:0] alu_result;
  wire [31:0] rd1, rd2;
  wire [31:0] pc_plus_4 = pc + 4;

  wire [31:0] data_ext;

  cpu_data_extend data_extend (
      .data(data_rdata),
      .control(data_ext_control),
      .data_ext(data_ext)
  );

  reg [31:0] result;

  always @(*) begin
    case (result_src)
      `RESULT_SRC_ALU:       result = alu_result;
      `RESULT_SRC_DATA:      result = data_ext;
      `RESULT_SRC_PC_TARGET: result = pc_target;
      `RESULT_SRC_PC_STEP:   result = pc_plus_4;
      default:               result = 32'b0;
    endcase
  end

  cpu_register_file register_file (
      .clk(clk),
      .rst_n(rst_n),
      .a1(instr_data[19:15]),
      .a2(instr_data[24:20]),
      .a3(instr_data[11:7]),
      .we3(reg_write),
      .wd3(result),

      .rd1(rd1),
      .rd2(rd2)
  );

  assign data_addr  = alu_result;
  assign data_wdata = rd2;

  cpu_alu alu (
      .src_a  (rd1),
      .src_b  (alu_src == `ALU_SRC_IMM ? imm_ext : rd2),
      .control(alu_control),

      .result(alu_result),
      .zero(alu_zero),
      .borrow(alu_borrow),
      .lt(alu_lt)
  );

  reg [31:0] pc_next;

  always @(*) begin
    case (pc_src)
      `PC_SRC_STEP:    pc_next = pc_plus_4;
      `PC_SRC_JUMP:    pc_next = pc_target;
      `PC_SRC_ALU:     pc_next = {alu_result[31:1], 1'b0};
      `PC_SRC_CURRENT: pc_next = pc;
      default:         pc_next = pc;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pc <= 0;
    else pc <= pc_next;
  end

  assign instr_addr = pc;
endmodule
