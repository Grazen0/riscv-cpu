`ifndef SINGLE_CYCLE_CPU_VH
`define SINGLE_CYCLE_CPU_VH

`define ALU_SRC_A_RD 1'd0
`define ALU_SRC_A_CSR 1'd1

`define ALU_SRC_B_RD2 2'd0
`define ALU_SRC_B_IMM 2'd1
`define ALU_SRC_B_RD1 2'd2
`define ALU_SRC_B_A1 2'd3

`define PC_SRC_STEP 2'd0
`define PC_SRC_TARGET 2'd1
`define PC_SRC_ALU 2'd2
`define PC_SRC_CURRENT 2'd3

`define RESULT_SRC_ALU 3'd0
`define RESULT_SRC_DATA 3'd1
`define RESULT_SRC_PC_TARGET 3'd2
`define RESULT_SRC_PC_STEP 3'd3
`define RESULT_SRC_FP_ALU 3'd4

`define REGW_SRC_RESULT 1'd0
`define REGW_SRC_CSR 1'd1

`define BRANCH_NONE 3'd0
`define BRANCH_JALR 3'd1
`define BRANCH_JAL 3'd2
`define BRANCH_BREAK 3'd3
`define BRANCH_COND 3'd4

`define WD_SEL_INT 1'd0
`define WD_SEL_FLOAT 1'd1

`define FP_ALU_ADD 4'b0000

`endif
