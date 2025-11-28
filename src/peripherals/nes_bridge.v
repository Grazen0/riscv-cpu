`default_nettype none

`define CMD_START 2'd0
`define CMD_WRITE 2'd1
`define CMD_READ 2'd2
`define CMD_STOP 2'd3

module i2c_controller #(
    parameter SCL_PERIOD = 500
) (
    input wire clk,
    input wire rst_n,

    input wire [1:0] cmd,
    input wire       start,

    // In case of write:
    input wire [7:0] wdata,  // Byte to be written
    input wire       wack,   // 1 = send WACK, 0 = send ACK

    output wire       ready,
    output reg  [7:0] rdata,
    output reg        rdata_valid,

    // TODO: add ack checking

    output wire scl_out,
    input  wire sda_in,
    output wire sda_out
);
  localparam S_IDLE = 5'd0;

  localparam S_START_SDA_DOWN = 5'd1;
  localparam S_START_SCL_DOWN = 5'd2;

  localparam S_STOP_SETUP = 5'd3;
  localparam S_STOP_SCL_UP = 5'd4;
  localparam S_STOP_SDA_UP = 5'd5;

  localparam S_WRITE_SETUP = 5'd6;
  localparam S_WRITE_CLK_UP = 5'd7;
  localparam S_WRITE_CLK_DOWN = 5'd8;
  localparam S_READ_ACK_SETUP = 5'd9;
  localparam S_READ_ACK_CLK_UP = 5'd10;
  localparam S_READ_ACK_READ = 5'd11;
  localparam S_READ_ACK_CLK_DOWN = 5'd12;

  localparam S_READ_SETUP = 5'd13;
  localparam S_READ_CLK_UP = 5'd14;
  localparam S_READ_READ = 5'd15;
  localparam S_READ_CLK_DOWN = 5'd16;
  localparam S_WRITE_ACK_SETUP = 5'd17;
  localparam S_WRITE_ACK_CLK_UP = 5'd18;
  localparam S_WRITE_ACK_CLK_DOWN = 5'd19;

  reg scl_reg, scl_reg_next;
  reg sda_reg, sda_reg_next;

  reg [4:0] state, state_next;

  reg [7:0] rdata_next;
  reg rdata_valid_next;

  reg [2:0] bit_ctr, bit_ctr_next;

  reg [7:0] wdata_buf, wdata_buf_next;
  reg wack_buf, wack_buf_next;

  reg ack, ack_next;

  reg [$clog2(SCL_PERIOD)-1:0] delay_ctr, delay_ctr_next;

  reg [$clog2(SCL_PERIOD)-1:0] delay_target;

  wire transition_incoming = delay_ctr_next == delay_target;

  always @(*) begin
    rdata_valid_next = rdata_valid;
    delay_ctr_next   = delay_ctr + 1;
    bit_ctr_next     = bit_ctr;
    wdata_buf_next   = wdata_buf;
    ack_next         = ack;
    rdata_next       = rdata;
    wack_buf_next    = wack_buf;

    delay_target     = 0;

    state_next       = state;

    case (state)
      S_IDLE: begin
        delay_target = 0;

        if (start) begin
          delay_ctr_next   = 0; // Transition instantly

          rdata_valid_next = 0;
          wdata_buf_next   = wdata;
          wack_buf_next    = wack;

          case (cmd)
            `CMD_START: state_next = S_START_SDA_DOWN;
            `CMD_WRITE: state_next = S_WRITE_SETUP;
            `CMD_READ:  state_next = S_READ_SETUP;
            `CMD_STOP:  state_next = S_STOP_SETUP;
            default:    state_next = S_IDLE;
          endcase
        end
      end

      S_START_SDA_DOWN: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_START_SCL_DOWN;
      end
      S_START_SCL_DOWN: begin
        delay_target = SCL_PERIOD;
        state_next   = S_IDLE;
      end

      S_STOP_SETUP: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_STOP_SCL_UP;
      end
      S_STOP_SCL_UP: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_STOP_SDA_UP;
      end
      S_STOP_SDA_UP: begin
        delay_target = SCL_PERIOD;
        state_next   = S_IDLE;
      end

      S_WRITE_SETUP: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_WRITE_CLK_UP;

        if (transition_incoming) begin
          wdata_buf_next = wdata_buf << 1;
          bit_ctr_next   = bit_ctr + 1;
        end
      end
      S_WRITE_CLK_UP: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_WRITE_CLK_DOWN;
      end
      S_WRITE_CLK_DOWN: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = bit_ctr == 0 ? S_READ_ACK_SETUP : S_WRITE_SETUP;
      end
      S_READ_ACK_SETUP: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_READ_ACK_CLK_UP;
      end
      S_READ_ACK_CLK_UP: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_READ_ACK_READ;

        if (transition_incoming) begin
          ack_next = sda_in;
        end
      end
      S_READ_ACK_READ: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_READ_ACK_CLK_DOWN;
      end
      S_READ_ACK_CLK_DOWN: begin
        delay_target = SCL_PERIOD;
        state_next   = S_IDLE;
      end

      S_READ_SETUP: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_READ_CLK_UP;
      end
      S_READ_CLK_UP: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_READ_READ;

        if (transition_incoming) begin
          bit_ctr_next = bit_ctr + 1;
          rdata_next = {rdata[6:0], sda_in};
          rdata_valid_next = bit_ctr_next == 0;
        end
      end
      S_READ_READ: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_READ_CLK_DOWN;
      end
      S_READ_CLK_DOWN: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = bit_ctr == 0 ? S_WRITE_ACK_SETUP : S_READ_CLK_UP;
      end
      S_WRITE_ACK_SETUP: begin
        delay_target = SCL_PERIOD / 4;
        state_next   = S_WRITE_ACK_CLK_UP;
      end
      S_WRITE_ACK_CLK_UP: begin
        delay_target = SCL_PERIOD / 2;
        state_next   = S_WRITE_ACK_CLK_DOWN;
      end
      S_WRITE_ACK_CLK_DOWN: begin
        delay_target = SCL_PERIOD;
        state_next   = S_IDLE;
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase

    scl_reg_next = scl_reg;
    sda_reg_next = sda_reg;

    case (state_next)
      S_IDLE: begin
      end

      S_START_SDA_DOWN: sda_reg_next = 0;
      S_START_SCL_DOWN: scl_reg_next = 0;

      S_STOP_SETUP:  sda_reg_next = 0;
      S_STOP_SCL_UP: scl_reg_next = 1;
      S_STOP_SDA_UP: sda_reg_next = 1;

      S_WRITE_SETUP:       sda_reg_next = state == S_IDLE ? wdata[7] : wdata_buf[7];
      S_WRITE_CLK_UP:      scl_reg_next = 1;
      S_WRITE_CLK_DOWN:    scl_reg_next = 0;
      S_READ_ACK_SETUP:    sda_reg_next = 1;
      S_READ_ACK_CLK_UP:   scl_reg_next = 1;
      S_READ_ACK_READ: begin
      end
      S_READ_ACK_CLK_DOWN: scl_reg_next = 0;

      S_READ_SETUP:         sda_reg_next = 1;
      S_READ_CLK_UP:        scl_reg_next = 1;
      S_READ_READ: begin
      end
      S_READ_CLK_DOWN:      scl_reg_next = 0;
      S_WRITE_ACK_SETUP:    sda_reg_next = wack_buf;
      S_WRITE_ACK_CLK_UP:   scl_reg_next = 1;
      S_WRITE_ACK_CLK_DOWN: scl_reg_next = 0;

      default: begin
      end
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      scl_reg     <= 1;
      sda_reg     <= 1;
      rdata       <= 0;
      rdata_valid <= 0;
      bit_ctr     <= 0;
      wdata_buf   <= 0;
      ack         <= 0;
      wack_buf    <= 0;
      delay_ctr   <= 0;

      state       <= S_IDLE;
    end else begin
      rdata       <= rdata_next;
      rdata_valid <= rdata_valid_next;
      bit_ctr     <= bit_ctr_next;
      wdata_buf   <= wdata_buf_next;
      ack         <= ack_next;
      wack_buf    <= wack_buf_next;
      delay_ctr   <= delay_ctr_next;

      if (transition_incoming) begin
        state     <= state_next;
        scl_reg   <= scl_reg_next;
        sda_reg   <= sda_reg_next;
        delay_ctr <= 0;
      end else begin
        state     <= state;
        scl_reg   <= scl_reg;
        sda_reg   <= sda_reg;
        delay_ctr <= delay_ctr_next;
      end
    end
  end

  assign ready   = state == S_IDLE;

  assign scl_out = scl_reg;
  assign sda_out = sda_reg;
endmodule

module nes_bridge #(
    parameter SLAVE_ADDR = 7'h52,
    parameter SCL_PERIOD = 500  // 10 Khz assuming base clock of 50 MHz
) (
    input wire clk,
    input wire rst_n,

    input wire start,

    output wire scl_out,
    input  wire sda_in,
    output wire sda_out,

    // 00: ready
    // 01: joypad_valid
    // 1x: joypad
    input  wire [1:0] rdata_addr,
    output reg  [7:0] rdata
);
  localparam S_IDLE = 4'd0;
  localparam S_START_1 = 4'd1;
  localparam S_ADDRW_WRITE = 4'd2;
  localparam S_INIT_WRITE = 4'd3;
  localparam S_STOP_1 = 4'd4;
  localparam S_START_2 = 4'd5;
  localparam S_ADDRR_WRITE = 4'd6;
  localparam S_DATA_READ = 4'd7;
  localparam S_STOP_2 = 4'd8;

  localparam RW_WRITE = 1'b0;
  localparam RW_READ = 1'b1;

  reg [3:0] state, state_next;
  reg [2:0] read_ctr, read_ctr_next;

  reg [1:0] i2c_cmd;
  reg       i2c_start;
  reg [7:0] i2c_wdata;
  reg       i2c_wack;
  reg [7:0] joypad, joypad_next;
  reg joypad_valid, joypad_valid_next;

  wire ready = state == S_IDLE;

  wire i2c_ready;
  wire [7:0] i2c_rdata;

  i2c_controller #(
      .SCL_PERIOD(SCL_PERIOD)
  ) i2c (
      .clk  (clk),
      .rst_n(rst_n),

      .cmd  (i2c_cmd),
      .start(i2c_start),
      .wdata(i2c_wdata),
      .wack (i2c_wack),

      .ready(i2c_ready),
      .rdata(i2c_rdata),

      .scl_out(scl_out),
      .sda_in (sda_in),
      .sda_out(sda_out)
  );

  always @(*) begin
    i2c_start         = 0;
    i2c_cmd           = 2'bxx;
    i2c_wdata         = 8'bxxxx_xxxx;
    i2c_wack          = 1'bx;
    read_ctr_next     = read_ctr;
    joypad_next       = joypad;
    joypad_valid_next = joypad_valid;

    state_next        = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          i2c_start         = 1;
          i2c_cmd           = `CMD_START;
          state_next        = S_START_1;
          joypad_valid_next = 0;
        end
      end
      S_START_1: begin
        if (i2c_ready) begin
          i2c_start  = 1;
          i2c_cmd    = `CMD_WRITE;
          i2c_wdata  = {SLAVE_ADDR, RW_WRITE};
          state_next = S_ADDRW_WRITE;
        end
      end
      S_ADDRW_WRITE: begin
        if (i2c_ready) begin
          i2c_start  = 1;
          i2c_cmd    = `CMD_WRITE;
          i2c_wdata  = 8'h00;
          state_next = S_INIT_WRITE;
        end
      end
      S_INIT_WRITE: begin
        if (i2c_ready) begin
          i2c_start  = 1;
          i2c_cmd    = `CMD_STOP;
          state_next = S_STOP_1;
        end
      end
      S_STOP_1: begin
        if (i2c_ready) begin
          i2c_start  = 1;
          i2c_cmd    = `CMD_START;
          state_next = S_START_2;
        end
      end
      S_START_2: begin
        if (i2c_ready) begin
          i2c_start  = 1;
          i2c_cmd    = `CMD_WRITE;
          i2c_wdata  = {SLAVE_ADDR, RW_READ};
          state_next = S_ADDRR_WRITE;
        end
      end
      S_ADDRR_WRITE: begin
        if (i2c_ready) begin
          i2c_start     = 1;
          i2c_cmd       = `CMD_READ;
          state_next    = S_DATA_READ;
          i2c_wack      = 0;
          read_ctr_next = 6;
        end
      end
      S_DATA_READ: begin
        if (i2c_ready) begin
          read_ctr_next = read_ctr - 1;

          i2c_start     = 1;
          i2c_cmd       = `CMD_READ;
          state_next    = S_DATA_READ;
          i2c_wack      = read_ctr_next == 1;

          if (read_ctr_next == 1) begin
            // Just read penultimate byte
            joypad_next[0] = i2c_rdata[7];
            joypad_next[2] = i2c_rdata[6];
            joypad_next[5] = i2c_rdata[4];
            joypad_next[4] = i2c_rdata[2];
          end else if (read_ctr_next == 0) begin
            // Just read last byte
            joypad_next[6]    = i2c_rdata[6];
            joypad_next[7]    = i2c_rdata[4];
            joypad_next[1]    = i2c_rdata[1];
            joypad_next[3]    = i2c_rdata[0];
            joypad_valid_next = 1;

            i2c_start         = 1;
            i2c_cmd           = `CMD_STOP;
            state_next        = S_STOP_2;
          end
        end
      end
      S_STOP_2: begin
        if (i2c_ready) begin
          state_next = S_IDLE;
        end
      end
      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      read_ctr     <= 0;
      joypad       <= 8'h00;
      joypad_valid <= 0;
      state        <= S_IDLE;
    end else begin
      read_ctr     <= read_ctr_next;
      joypad       <= joypad_next;
      joypad_valid <= joypad_valid_next;
      state        <= state_next;
    end
  end

  always @(*) begin
    casez (rdata_addr)
      2'b00:   rdata = {7'b0, ready};
      2'b01:   rdata = {7'b0, joypad_valid};
      2'b1z:   rdata = joypad;
      default: rdata = 8'bxxxx_xxxx;
    endcase
  end
endmodule
