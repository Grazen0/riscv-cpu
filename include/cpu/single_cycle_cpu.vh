`ifndef SINGLE_CYCLE_CPU_VH
`define SINGLE_CYCLE_CPU_VH

`define ALU_SRC_RD 1'b0
`define ALU_SRC_IMM 1'b1

`define PC_SRC_STEP 2'd0
`define PC_SRC_JUMP 2'd1
`define PC_SRC_ALU 2'd2
`define PC_SRC_CURRENT 2'd3

`define RESULT_SRC_ALU 2'd0
`define RESULT_SRC_DATA 2'd1
`define RESULT_SRC_PC_TARGET 2'd2
`define RESULT_SRC_PC_STEP 2'd3

`define BRANCH_NONE 3'd0
`define BRANCH_JALR 3'd1
`define BRANCH_JAL 3'd2
`define BRANCH_BREAK 3'd3
`define BRANCH_COND 3'd4

`endif
