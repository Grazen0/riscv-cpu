`default_nettype none

`include "cpu_imm_extend.vh"
`include "cpu_alu.vh"

`define ALU_SRC_A_PC 2'd0
`define ALU_SRC_A_OLD_PC 2'd1
`define ALU_SRC_A_RD1 2'd2

`define ALU_SRC_B_RD22 2'd0
`define ALU_SRC_B_IMM 2'd1
`define ALU_SRC_B_4 2'd2

`define RESULT_SRC_ALU_OUT 2'd0
`define RESULT_SRC_DATA 2'd1
`define RESULT_SRC_ALU_RESULT 2'd2

`define ADR_SRC_PC 1'd0
`define ADR_SRC_RESULT 1'd1

`define BRANCH_NONE 2'd0
`define BRANCH_NEXT 2'd1
`define BRANCH_COND 2'd2

module mcc_control (
    input wire clk,
    input wire rst_n,

    input wire [6:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,

    output reg [1:0] branch_type,
    output reg adr_src,
    output reg [3:0] mem_write,
    output reg ir_write,
    output reg [2:0] result_src,
    output reg [3:0] alu_control,
    output reg [1:0] alu_src_a,
    output reg [1:0] alu_src_b,
    output reg [2:0] imm_src,
    output reg reg_write,
    output reg [2:0] data_ext_control
);
  localparam S_FETCH = 3'd0;
  localparam S_DECODE = 3'd1;
  localparam S_EXECUTE = 3'd2;
  localparam S_WRITE = 3'd3;
  localparam S_MEM_READ = 3'd4;

  localparam OP_LOAD = 7'b0000011;
  localparam OP_ALU_IMM = 7'b0010011;
  localparam OP_AUIPC = 7'b0010111;
  localparam OP_STORE = 7'b0100011;
  localparam OP_ALU_RD = 7'b0110011;
  localparam OP_LUI = 7'b0110111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_JALR = 7'b1100111;
  localparam OP_JAL = 7'b1101111;

  reg [2:0] state, next_state;

  always @(*) begin
    branch_type = `BRANCH_NONE;
    adr_src = 1'bx;
    mem_write = 4'b0000;
    ir_write = 0;
    result_src = 2'bxx;
    alu_control = 4'b0000;
    alu_src_a = 2'bxx;
    alu_src_b = 2'bxx;
    imm_src = 3'bxxx;
    reg_write = 0;
    data_ext_control = 3'bxxx;

    case (state)
      S_FETCH: begin
        adr_src = `ADR_SRC_PC;

        branch_type = `BRANCH_NEXT;
        ir_write = 1;

        alu_src_a = `ALU_SRC_A_PC;
        alu_src_b = `ALU_SRC_B_4;
        alu_control = `ALU_ADD;
        result_src = `RESULT_SRC_ALU_RESULT;

        next_state = S_DECODE;
      end
      S_DECODE: begin
        if (op == OP_BRANCH) begin
          // Pre-calculate branch target PC
          imm_src = `IMM_SRC_B;
          alu_src_a = `ALU_SRC_A_OLD_PC;
          alu_src_b = `ALU_SRC_B_IMM;
          alu_control = `ALU_ADD;
        end else if (op == OP_AUIPC) begin
          // Pre-calculate resulting PC
          imm_src = `IMM_SRC_U;
          alu_src_a = `ALU_SRC_A_OLD_PC;
          alu_src_b = `ALU_SRC_B_IMM;
          alu_control = `ALU_ADD;
        end else if (op == OP_JAL) begin
          // Pre-calculate branch target PC
          imm_src = `IMM_SRC_J;
          alu_src_a = `ALU_SRC_A_OLD_PC;
          alu_src_b = `ALU_SRC_B_IMM;
          alu_control = `ALU_ADD;
        end

        next_state = S_EXECUTE;
      end
      S_EXECUTE: begin
        case (op)
          OP_LOAD: begin
            imm_src = `IMM_SRC_I;
            alu_src_a = `ALU_SRC_A_RD1;
            alu_src_b = `ALU_SRC_B_IMM;
            alu_control = `ALU_ADD;

            next_state = S_MEM_READ;
          end
          OP_ALU_IMM: begin
            imm_src = `IMM_SRC_I;
            alu_src_a = `ALU_SRC_A_RD1;
            alu_src_b = `ALU_SRC_B_IMM;
            alu_control = {(funct3 == 3'b101) ? funct7[5] : 1'b0, funct3};

            next_state = S_WRITE;
          end
          OP_AUIPC: begin
            result_src = `RESULT_SRC_ALU_OUT;
            reg_write  = 1;

            next_state = S_FETCH;
          end
          OP_STORE: begin
            imm_src = `IMM_SRC_S;
            alu_src_a = `ALU_SRC_A_RD1;
            alu_src_b = `ALU_SRC_B_IMM;
            alu_control = `ALU_ADD;

            next_state = S_WRITE;
          end
          OP_ALU_RD: begin
            alu_src_a   = `ALU_SRC_A_RD1;
            alu_src_b   = `ALU_SRC_B_RD22;
            alu_control = {funct7[5], funct3};

            next_state  = S_WRITE;
          end
          OP_LUI: begin
            imm_src = `IMM_SRC_U;
            alu_src_b = `ALU_SRC_B_IMM;
            alu_control = `ALU_PASS_B;

            next_state = S_WRITE;
          end
          OP_BRANCH: begin
            alu_src_a   = `ALU_SRC_A_RD1;
            alu_src_b   = `ALU_SRC_B_RD22;
            alu_control = `ALU_SUB;

            branch_type = `BRANCH_COND;
            result_src  = `RESULT_SRC_ALU_OUT;

            next_state  = S_FETCH;
          end
          OP_JALR: begin
            imm_src = `IMM_SRC_J;
            alu_src_a = `ALU_SRC_A_RD1;
            alu_src_b = `ALU_SRC_B_IMM;
            alu_control = `ALU_ADD;

            branch_type = `BRANCH_NEXT;
            result_src = `RESULT_SRC_ALU_RESULT;

            next_state = S_WRITE;
          end
          OP_JAL: begin
            branch_type = `BRANCH_NEXT;
            result_src  = `RESULT_SRC_ALU_OUT;

            next_state  = S_WRITE;
          end
          default: next_state = S_FETCH;
        endcase
      end
      S_MEM_READ: begin
        result_src = `RESULT_SRC_ALU_OUT;
        adr_src = `ADR_SRC_RESULT;

        next_state = S_WRITE;
      end
      S_WRITE: begin
        case (op)
          OP_LOAD: begin
            result_src = `RESULT_SRC_DATA;
            data_ext_control = funct3;
            reg_write = 1;
          end
          OP_ALU_IMM, OP_ALU_RD: begin
            result_src = `RESULT_SRC_ALU_OUT;
            reg_write  = 1;
          end
          OP_STORE: begin
            result_src = `RESULT_SRC_ALU_OUT;
            adr_src = `ADR_SRC_RESULT;

            case (funct3)
              3'b000:  mem_write = 4'b0001;
              3'b001:  mem_write = 4'b0011;
              3'b010:  mem_write = 4'b1111;
              default: mem_write = 4'b0000;
            endcase
          end
          OP_LUI: begin
            result_src = `RESULT_SRC_ALU_OUT;
            reg_write  = 1;
          end
          OP_JALR, OP_JAL: begin
            alu_src_a   = `ALU_SRC_A_OLD_PC;
            alu_src_b   = `ALU_SRC_B_4;
            alu_control = `ALU_ADD;

            result_src  = `RESULT_SRC_ALU_RESULT;
            reg_write   = 1;
          end
          default: begin
          end
        endcase

        next_state = S_FETCH;
      end
      default: next_state = S_FETCH;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_FETCH;
    end else begin
      state <= next_state;
    end
  end
endmodule

module mcc_branch_logic (
    input wire [1:0] branch_type,
    input wire [2:0] funct3,
    input wire alu_zero,
    input wire alu_lt,
    input wire alu_borrow,

    output reg pc_write
);
  always @(*) begin
    case (branch_type)
      `BRANCH_NONE: pc_write = 0;
      `BRANCH_NEXT: pc_write = 1;
      `BRANCH_COND: begin
        case (funct3)
          3'b000:  pc_write = alu_zero;  // beq
          3'b001:  pc_write = !alu_zero;  // bne
          3'b100:  pc_write = alu_lt;  // blt
          3'b101:  pc_write = !alu_lt;  // bge
          3'b110:  pc_write = alu_borrow;  // bltu
          3'b111:  pc_write = !alu_borrow;  // bgeu
          default: pc_write = 0;
        endcase
      end
      default: pc_write = 0;
    endcase
  end
endmodule

module multi_cycle_cpu (
    input wire clk,
    input wire rst_n,

    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [ 3:0] mem_wenable,
    input  wire [31:0] mem_rdata
);
  reg [31:0] pc;

  reg [31:0] old_pc;
  reg [31:0] instr;

  reg [31:0] data;

  wire [1:0] branch_type;
  wire adr_src;
  wire ir_write;
  wire [2:0] result_src;
  wire [3:0] alu_control;
  wire [1:0] alu_src_a;
  wire [1:0] alu_src_b;
  wire [2:0] imm_src;
  wire reg_write;
  wire [2:0] data_ext_control;

  wire [2:0] funct3 = instr[14:12];

  mcc_control control (
      .clk  (clk),
      .rst_n(rst_n),

      .op(instr[6:0]),
      .funct3(funct3),
      .funct7(instr[31:25]),


      .branch_type(branch_type),
      .adr_src(adr_src),
      .mem_write(mem_wenable),
      .ir_write(ir_write),
      .result_src(result_src),
      .alu_control(alu_control),
      .alu_src_a(alu_src_a),
      .alu_src_b(alu_src_b),
      .imm_src(imm_src),
      .reg_write(reg_write),
      .data_ext_control(data_ext_control)
  );

  wire alu_zero;
  wire alu_lt;
  wire alu_borrow;
  wire pc_write;

  mcc_branch_logic branch_logic (
      .branch_type(branch_type),
      .funct3(funct3),
      .alu_zero(alu_zero),
      .alu_lt(alu_lt),
      .alu_borrow(alu_borrow),

      .pc_write(pc_write)
  );

  wire [31:0] imm_ext;

  cpu_imm_extend imm_extend (
      .data(instr[31:7]),
      .imm_src(imm_src),
      .imm_ext(imm_ext)
  );

  wire [31:0] data_ext;

  cpu_data_extend data_extend (
      .data(data),
      .control(data_ext_control),
      .data_ext(data_ext)
  );

  wire [31:0] rd1;
  wire [31:0] rd2;


  cpu_register_file register_file (
      .clk(clk),

      .a1(instr[19:15]),
      .a2(instr[24:20]),
      .a3(instr[11:7]),

      .rd1(rd1),
      .rd2(rd2),

      .we3(reg_write),
      .wd3(result)
  );

  reg  [31:0] rd1_buf;
  reg  [31:0] rd2_buf;

  reg  [31:0] src_a;
  reg  [31:0] src_b;

  wire [31:0] alu_result;

  cpu_alu alu (
      .src_a  (src_a),
      .src_b  (src_b),
      .control(alu_control),

      .result(alu_result),
      .zero(alu_zero),
      .lt(alu_lt),
      .borrow(alu_borrow)
  );

  reg [31:0] alu_out;
  reg [31:0] result;

  always @(*) begin
    case (alu_src_a)
      `ALU_SRC_A_PC:     src_a = pc;
      `ALU_SRC_A_OLD_PC: src_a = old_pc;
      `ALU_SRC_A_RD1:    src_a = rd1_buf;
      default:           src_a = {32{1'bx}};
    endcase

    case (alu_src_b)
      `ALU_SRC_B_RD22: src_b = rd2_buf;
      `ALU_SRC_B_IMM: src_b = imm_ext;
      `ALU_SRC_B_4:   src_b = 4;
      default:        src_b = {32{1'bx}};
    endcase

    case (result_src)
      `RESULT_SRC_ALU_OUT:    result = alu_out;
      `RESULT_SRC_DATA:       result = data_ext;
      `RESULT_SRC_ALU_RESULT: result = alu_result;
      default:                result = {32{1'bx}};
    endcase
  end

  wire [31:0] pc_next = result;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 0;
    end else begin
      if (pc_write) begin
        pc <= pc_next & ~1;
      end

      if (ir_write) begin
        old_pc <= pc;
        instr  <= mem_rdata;
      end

      rd1_buf <= rd1;
      rd2_buf <= rd2;

      data <= mem_rdata;
      alu_out <= alu_result;
    end
  end

  assign mem_addr  = adr_src == `ADR_SRC_PC ? pc : result;
  assign mem_wdata = rd2_buf;
endmodule
