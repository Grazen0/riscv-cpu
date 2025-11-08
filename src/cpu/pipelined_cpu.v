`default_nettype none


`include "single_cycle_cpu.vh"
`include "cpu_csr_file.vh"
`include "cpu_imm_extend.vh"
`include "cpu_alu.vh"

`define FORWARD_NONE 2'd0
`define FORWARD_WRITEBACK 2'd1
`define FORWARD_MEMORY 2'd2

module pl_hazard_unit (
    input wire [4:0] rs1_e,
    input wire [4:0] rs2_e,
    input wire [4:0] rd_m,
    input wire [4:0] rd_w,
    input wire reg_write_m,
    input wire reg_write_w,
    output reg [1:0] forward_a_e,
    output reg [1:0] forward_b_e,

    input wire [11:0] csr_addr_e,
    input wire [11:0] csr_addr_m,
    input wire [11:0] csr_addr_w,
    input wire csr_write_m,
    input wire csr_write_w,
    output reg [1:0] forward_csr_data_e,

    input wire [4:0] rs1_d,
    input wire [4:0] rs2_d,
    input wire [4:0] rd_e,
    input wire [1:0] result_src_e,
    output wire stall_f,
    output wire stall_d,
    output wire flush_e,

    input wire [1:0] pc_src_e,
    output wire flush_d
);
  wire lw_stall = result_src_e == `RESULT_SRC_DATA && (rs1_d == rd_e || rs2_d == rd_e);

  always @(*) begin
    forward_a_e = `FORWARD_NONE;
    forward_b_e = `FORWARD_NONE;
    forward_csr_data_e = `FORWARD_NONE;

    if (rs1_e == rd_m && reg_write_m && rs1_e != 0) begin
      forward_a_e = `FORWARD_MEMORY;
    end else if (rs1_e == rd_w && reg_write_w && rs1_e != 0) begin
      forward_a_e = `FORWARD_WRITEBACK;
    end

    if (rs2_e == rd_m && reg_write_m && rs2_e != 0) begin
      forward_b_e = `FORWARD_MEMORY;
    end else if (rs2_e == rd_w && reg_write_w && rs2_e != 0) begin
      forward_b_e = `FORWARD_WRITEBACK;
    end

    if (csr_addr_e == csr_addr_m && csr_write_m) begin
      forward_csr_data_e = `FORWARD_MEMORY;
    end else if (csr_addr_e == csr_addr_w && csr_write_w) begin
      forward_csr_data_e = `FORWARD_WRITEBACK;
    end
  end

  assign stall_f = lw_stall;
  assign stall_d = lw_stall;
  assign flush_d = pc_src_e != `PC_SRC_STEP;
  assign flush_e = lw_stall || pc_src_e != `PC_SRC_STEP;
endmodule

module pl_interrupt_control (
    input wire clk,
    input wire rst_n,

    input wire irq,

    output reg trap_pc,
    output reg trap_stages,

    output reg flush_m,
    output reg flush_e,
    output reg flush_d,

    output reg stall_e,
    output reg stall_d,
    output reg stall_f
);
  localparam S_IDLE = 2'd0;
  localparam S_WAIT1 = 2'd1;
  localparam S_WAIT2 = 2'd2;

  reg [1:0] state, next_state;

  wire irq_pending;
  reg  ack;

  irq_gate irq_g (
      .clk  (clk),
      .rst_n(rst_n),

      .irq        (irq),
      .ack        (ack),
      .irq_pending(irq_pending)
  );

  always @(*) begin
    flush_m     = 0;
    flush_e     = 0;
    flush_d     = 0;
    stall_e     = 0;
    stall_d     = 0;
    stall_f     = 0;

    ack         = 0;
    trap_pc     = 0;
    trap_stages = 0;

    case (state)
      S_IDLE: begin
        next_state = state;

        if (irq_pending) begin
          trap_stages = 1;
          flush_m     = 1;
          stall_e     = 1;
          stall_d     = 1;
          stall_f     = 1;

          ack         = 1;
          next_state  = S_WAIT1;
        end
      end
      S_WAIT1: begin
        trap_stages = 1;
        flush_m     = 1;
        stall_e     = 1;
        stall_d     = 1;
        stall_f     = 1;

        next_state  = S_WAIT2;
      end
      S_WAIT2: begin
        trap_stages = 1;
        flush_m     = 1;
        flush_e     = 1;
        flush_d     = 1;

        trap_pc     = 1;
        next_state  = S_IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end
endmodule

module pipelined_cpu (
    input wire clk,
    input wire rst_n,

    output wire [31:0] instr_addr,
    input  wire [31:0] instr_data,

    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    output wire [ 3:0] data_wenable,
    input  wire [31:0] data_rdata,

    input wire irq
);
  wire [1:0] forward_a_e;
  wire [1:0] forward_b_e;
  wire [1:0] forward_csr_data_e;
  wire stall_f;
  wire stall_d;
  wire flush_e;
  wire flush_d;

  pl_hazard_unit hazard_unit (
      .rs1_e(rs1_e),
      .rs2_e(rs2_e),
      .rd_m(rd_m),
      .rd_w(rd_w),
      .reg_write_m(reg_write_m),
      .reg_write_w(reg_write_w),
      .forward_a_e(forward_a_e),
      .forward_b_e(forward_b_e),

      .csr_addr_e(csr_addr_e),
      .csr_addr_m(csr_addr_m),
      .csr_addr_w(csr_addr_w),
      .csr_write_m(csr_write_m),
      .csr_write_w(csr_write_w),
      .forward_csr_data_e(forward_csr_data_e),

      .rs1_d(rs1_d),
      .rs2_d(rs2_d),
      .rd_e(rd_e),
      .result_src_e(result_src_e),
      .stall_f(stall_f),
      .stall_d(stall_d),
      .flush_e(flush_e),

      .pc_src_e(pc_src_e),
      .flush_d (flush_d)
  );

  wire flush_m_irq;
  wire flush_e_irq;
  wire flush_d_irq;

  wire stall_e_irq;
  wire stall_d_irq;
  wire stall_f_irq;

  wire trap_stages;
  wire trap_pc;

  pl_interrupt_control interrupt_control (
      .clk  (clk),
      .rst_n(rst_n),

      .irq(irq),

      .flush_m(flush_m_irq),
      .flush_e(flush_e_irq),
      .flush_d(flush_d_irq),

      .stall_e(stall_e_irq),
      .stall_d(stall_d_irq),
      .stall_f(stall_f_irq),

      .trap_stages(trap_stages),
      .trap_pc(trap_pc)
  );

  // 1. Fetch
  reg  [31:0] pc_f;

  wire [31:0] trap_pc_next = !bubble_e ? pc_e : !bubble_d ? pc_d : pc_f;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_f <= 0;
    end else if ((trap_stages || !stall_f) && !stall_f_irq) begin
      pc_f <= pc_next;
    end
  end

  reg [31:0] pc_next;

  always @(*) begin
    if (trap_pc || trap_mret) begin
      pc_next = csr_data_d;
    end else begin
      case (pc_src_e)
        `PC_SRC_STEP:    pc_next = pc_plus_4_f;
        `PC_SRC_TARGET:  pc_next = pc_target_e;
        `PC_SRC_ALU:     pc_next = alu_result_e & ~1;
        `PC_SRC_CURRENT: pc_next = pc_f;
        default:         pc_next = {32{1'bx}};
      endcase
    end
  end

  assign instr_addr = pc_f;
  wire [31:0] pc_plus_4_f = pc_f + 4;


  // 2. Decode
  reg  [31:0] instr_d;
  reg  [31:0] pc_d;
  reg  [31:0] pc_plus_4_d;
  reg         bubble_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || trap_mret || (!trap_stages && flush_d) || flush_d_irq) begin
      instr_d     <= 32'h00000013;  // nop
      pc_d        <= {32{1'bx}};
      pc_plus_4_d <= {32{1'bx}};
      bubble_d    <= 1;
    end else begin
      if ((trap_stages || !stall_d) && !stall_d_irq) begin
        instr_d     <= instr_data;
        pc_d        <= pc_f;
        pc_plus_4_d <= pc_plus_4_f;
        bubble_d    <= 0;
      end
    end
  end

  wire [ 2:0] funct3_d = instr_d[14:12];

  wire [ 1:0] pc_src_d;
  wire [ 2:0] branch_type_d;
  wire [ 1:0] result_src_d;
  wire [ 3:0] mem_write_d;
  wire [ 2:0] data_ext_control_d;
  wire [ 3:0] alu_control_d;
  wire        alu_src_a_d;
  wire [ 1:0] alu_src_b_d;
  wire [ 2:0] imm_src_d;
  wire        regw_src_d;
  wire        reg_write_d;
  wire        csr_write_d;

  wire [ 4:0] rs1_d = instr_d[19:15];
  wire [ 4:0] rs2_d = instr_d[24:20];
  wire [ 4:0] rd_d = instr_d[11:7];
  wire [31:0] imm_ext_d;
  wire [31:0] rd1_d;
  wire [31:0] rd2_d;
  wire [31:0] csr_data_d;
  wire        trap_mret;

  scc_control control (
      .op    (instr_d[6:0]),
      .funct3(funct3_d),
      .funct7(instr_d[31:25]),

      .branch_type     (branch_type_d),
      .result_src      (result_src_d),
      .mem_write       (mem_write_d),
      .data_ext_control(data_ext_control_d),
      .alu_control     (alu_control_d),
      .alu_src_a       (alu_src_a_d),
      .alu_src_b       (alu_src_b_d),
      .imm_src         (imm_src_d),
      .regw_src        (regw_src_d),
      .reg_write       (reg_write_d),
      .csr_write       (csr_write_d),
      .trap_mret       (trap_mret)
  );

  cpu_register_file register_file (
      .clk  (~clk),
      .rst_n(rst_n),

      .a1 (rs1_d),
      .a2 (rs2_d),
      .a3 (rd_w),
      .we3(reg_write_w),
      .wd3(reg_wd3_w),

      .rd1(rd1_d),
      .rd2(rd2_d)
  );

  wire [11:0] csr_addr_d = instr_d[31:20];

  cpu_csr_file csr_file (
      .clk  (~clk),
      .rst_n(rst_n),

      .raddr(trap_pc ? `CSR_MTVEC : trap_mret ? `CSR_MEPC : csr_addr_d),
      .rdata(csr_data_d),

      .waddr  (trap_pc ? `CSR_MEPC : csr_addr_w),
      .wdata  (trap_pc ? trap_pc_next : result_w),
      .wenable(trap_pc || csr_write_w)
  );

  cpu_imm_extend imm_extend (
      .data   (instr_d[31:7]),
      .imm_src(imm_src_d),
      .imm_ext(imm_ext_d)
  );

  // 3. Execute
  reg        regw_src_e;
  reg        reg_write_e;
  reg        csr_write_e;
  reg [ 1:0] result_src_e;
  reg [ 3:0] mem_write_e;
  reg [ 2:0] data_ext_control_e;
  reg [ 3:0] alu_control_e;
  reg        alu_src_a_e;
  reg [ 1:0] alu_src_b_e;
  reg [11:0] csr_addr_e;

  reg [31:0] rd1_e;
  reg [31:0] rd2_e;
  reg [31:0] csr_data_e;
  reg [31:0] pc_e;
  reg [ 4:0] rs1_e;
  reg [ 4:0] rs2_e;
  reg [ 4:0] rd_e;
  reg [31:0] imm_ext_e;
  reg [31:0] pc_plus_4_e;
  reg [ 2:0] branch_type_e;
  reg [ 2:0] funct3_e;

  reg        bubble_e;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || (!trap_stages && flush_e) || flush_e_irq) begin
      regw_src_e         <= 0;
      reg_write_e        <= 0;
      csr_write_e        <= 0;
      result_src_e       <= `RESULT_SRC_ALU;
      mem_write_e        <= 0;
      data_ext_control_e <= 4'b0000;
      alu_control_e      <= 4'b0000;
      alu_src_a_e        <= 0;
      alu_src_b_e        <= 0;
      csr_addr_e         <= 0;

      rd1_e              <= 32'b0;
      rd2_e              <= 32'b0;
      csr_data_e         <= 32'b0;
      pc_e               <= {32{1'bx}};
      rs1_e              <= 0;
      rs2_e              <= 0;
      rd_e               <= 0;
      imm_ext_e          <= {32{1'bx}};
      pc_plus_4_e        <= {32{1'bx}};
      branch_type_e      <= `BRANCH_NONE;
      funct3_e           <= 3'bxxx;

      bubble_e           <= 1;
    end else if (!stall_e_irq) begin
      regw_src_e         <= regw_src_d;
      reg_write_e        <= reg_write_d;
      csr_write_e        <= csr_write_d;
      result_src_e       <= result_src_d;
      mem_write_e        <= mem_write_d;
      data_ext_control_e <= data_ext_control_d;
      alu_control_e      <= alu_control_d;
      alu_src_a_e        <= alu_src_a_d;
      alu_src_b_e        <= alu_src_b_d;
      csr_addr_e         <= csr_addr_d;

      rd1_e              <= rd1_d;
      rd2_e              <= rd2_d;
      csr_data_e         <= csr_data_d;
      pc_e               <= pc_d;
      rs1_e              <= rs1_d;
      rs2_e              <= rs2_d;
      rd_e               <= rd_d;
      imm_ext_e          <= imm_ext_d;
      pc_plus_4_e        <= pc_plus_4_d;
      branch_type_e      <= branch_type_d;
      funct3_e           <= funct3_d;

      bubble_e           <= bubble_d;
    end
  end

  wire [31:0] pc_target_e = pc_e + imm_ext_e;
  wire [31:0] alu_result_e;
  wire        alu_zero_e;
  wire        alu_borrow_e;
  wire        alu_lt_e;

  reg  [31:0] rd1_e_fw;
  reg  [31:0] rd2_e_fw;
  reg  [31:0] csr_data_e_fw;

  wire [31:0] write_data_e = rd2_e_fw;

  always @(*) begin
    case (forward_a_e)
      `FORWARD_NONE:      rd1_e_fw = rd1_e;
      `FORWARD_MEMORY: begin
        case (regw_src_m)
          `REGW_SRC_RESULT: rd1_e_fw = result_pre_m;
          `REGW_SRC_CSR:    rd1_e_fw = csr_data_m;
          default:          rd1_e_fw = {32{1'bx}};
        endcase
      end
      `FORWARD_WRITEBACK: rd1_e_fw = result_w;
      default:            rd1_e_fw = {32{1'bx}};
    endcase

    case (forward_b_e)
      `FORWARD_NONE:      rd2_e_fw = rd2_e;
      `FORWARD_MEMORY: begin
        case (regw_src_m)
          `REGW_SRC_RESULT: rd2_e_fw = result_pre_m;
          `REGW_SRC_CSR:    rd2_e_fw = csr_data_m;
          default:          rd2_e_fw = {32{1'bx}};
        endcase
      end
      `FORWARD_WRITEBACK: rd2_e_fw = result_w;
      default:            rd2_e_fw = {32{1'bx}};
    endcase

    case (forward_csr_data_e)
      `FORWARD_NONE:      csr_data_e_fw = csr_data_e;
      `FORWARD_MEMORY:    csr_data_e_fw = result_pre_m;
      `FORWARD_WRITEBACK: csr_data_e_fw = result_w;
      default:            csr_data_e_fw = {32{1'bx}};
    endcase
  end

  reg [31:0] alu_src_a_val_e;
  reg [31:0] alu_src_b_val_e;

  always @(*) begin
    case (alu_src_a_e)
      `ALU_SRC_A_RD:  alu_src_a_val_e = rd1_e_fw;
      `ALU_SRC_A_CSR: alu_src_a_val_e = csr_data_e_fw;
      default:        alu_src_a_val_e = {32{1'bx}};
    endcase

    case (alu_src_b_e)
      `ALU_SRC_B_RD2: alu_src_b_val_e = rd2_e_fw;
      `ALU_SRC_B_IMM: alu_src_b_val_e = imm_ext_e;
      `ALU_SRC_B_RD1: alu_src_b_val_e = rd1_e_fw;
      `ALU_SRC_B_A1:  alu_src_b_val_e = {27'b0, rs1_e};
      default:        alu_src_b_val_e = {32{1'bx}};
    endcase
  end

  cpu_alu alu (
      .src_a  (alu_src_a_val_e),
      .src_b  (alu_src_b_val_e),
      .control(alu_control_e),

      .result(alu_result_e),
      .zero  (alu_zero_e),
      .borrow(alu_borrow_e),
      .lt    (alu_lt_e)
  );

  wire [1:0] pc_src_e;

  scc_branch_logic branch_logic (
      .branch_type(branch_type_e),
      .funct3     (funct3_e),
      .alu_zero   (alu_zero_e),
      .alu_borrow (alu_borrow_e),
      .alu_lt     (alu_lt_e),

      .pc_src(pc_src_e)
  );


  // 4. Memory
  reg        regw_src_m;
  reg        reg_write_m;
  reg        csr_write_m;
  reg [ 1:0] result_src_m;
  reg [ 3:0] mem_write_m;
  reg [ 2:0] data_ext_control_m;
  reg [11:0] csr_addr_m;

  reg [31:0] csr_data_m;
  reg [31:0] alu_result_m;
  reg [31:0] write_data_m;
  reg [ 4:0] rd_m;
  reg [31:0] pc_target_m;
  reg [31:0] pc_plus_4_m;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_m_irq) begin
      regw_src_m         <= 0;
      reg_write_m        <= 0;
      csr_write_m        <= 0;
      result_src_m       <= `RESULT_SRC_ALU;
      mem_write_m        <= 4'b0000;
      data_ext_control_m <= 4'b0000;
      csr_addr_m         <= 0;

      csr_data_m         <= 32'b0;
      alu_result_m       <= 32'b0;
      write_data_m       <= 32'b0;
      rd_m               <= 5'b0;
      pc_target_m        <= {32{1'bx}};
      pc_plus_4_m        <= {32{1'bx}};
    end else begin
      regw_src_m         <= regw_src_e;
      reg_write_m        <= reg_write_e;
      csr_write_m        <= csr_write_e;
      result_src_m       <= result_src_e;
      mem_write_m        <= mem_write_e;
      data_ext_control_m <= data_ext_control_e;
      csr_addr_m         <= csr_addr_e;

      csr_data_m         <= csr_data_e;
      alu_result_m       <= alu_result_e;
      write_data_m       <= write_data_e;
      rd_m               <= rd_e;
      pc_target_m        <= pc_target_e;
      pc_plus_4_m        <= pc_plus_4_e;
    end
  end

  wire [31:0] read_data_m;
  reg  [31:0] reg_wd3_m;

  assign data_addr    = alu_result_m;
  assign data_wdata   = write_data_m;
  assign data_wenable = mem_write_m;

  cpu_data_extend data_extend (
      .data    (data_rdata),
      .control (data_ext_control_m),
      .data_ext(read_data_m)
  );

  reg [31:0] result_pre_m;

  always @(*) begin
    case (result_src_m)
      `RESULT_SRC_ALU:       result_pre_m = alu_result_m;
      `RESULT_SRC_PC_TARGET: result_pre_m = pc_target_m;
      `RESULT_SRC_PC_STEP:   result_pre_m = pc_plus_4_m;
      default:               result_pre_m = {32{1'bx}};
    endcase
  end

  // 5. Writeback
  reg        reg_write_w;
  reg        csr_write_w;
  reg        regw_src_w;

  reg [31:0] result_pre_w;
  reg [ 1:0] result_src_w;
  reg [31:0] read_data_w;
  reg [31:0] csr_data_w;
  reg [ 4:0] rd_w;
  reg [11:0] csr_addr_w;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_pre_w <= 0;
      reg_write_w  <= 0;
      csr_write_w  <= 0;
      regw_src_w   <= 0;

      result_src_w <= 0;
      read_data_w  <= 0;
      csr_data_w   <= 32'b0;
      rd_w         <= 5'b0;
      csr_addr_w   <= 0;
    end else begin
      result_pre_w <= result_pre_m;
      reg_write_w  <= reg_write_m;
      csr_write_w  <= csr_write_m;
      regw_src_w   <= regw_src_m;

      result_src_w <= result_src_m;
      read_data_w  <= read_data_m;
      csr_data_w   <= csr_data_m;
      rd_w         <= rd_m;
      csr_addr_w   <= csr_addr_m;
    end
  end

  wire [31:0] result_w = result_src_w == `RESULT_SRC_DATA ? read_data_w : result_pre_w;
  reg  [31:0] reg_wd3_w;

  always @(*) begin
    case (regw_src_w)
      `REGW_SRC_RESULT: reg_wd3_w = result_w;
      `REGW_SRC_CSR:    reg_wd3_w = csr_data_w;
      default:          reg_wd3_w = {32{1'bx}};
    endcase
  end
endmodule
