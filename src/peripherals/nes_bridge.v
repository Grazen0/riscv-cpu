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
    input wire [7:0] wdata,  // data to write in case of CMD_WRITE
    input wire wack,
    input wire start,

    output reg ready,
    output reg [7:0] rdata,
    output reg rdata_valid,

    output tri1 scl,
    output tri1 sda
);
  localparam S_IDLE = 4'd0;
  localparam S_START = 4'd1;
  localparam S_WRITE_SETUP = 4'd2;
  localparam S_WRITE_CLK = 4'd3;
  localparam S_READ_ACK_SETUP_1 = 4'd4;
  localparam S_READ_ACK_SETUP_2 = 4'd5;
  localparam S_READ_ACK = 4'd6;
  localparam S_READ_SETUP = 4'd7;
  localparam S_READ_CLK = 4'd8;
  localparam S_WRITE_ACK_SETUP = 4'd9;
  localparam S_WRITE_ACK = 4'd10;
  localparam S_STOP_SETUP = 4'd11;
  localparam S_STOP = 4'd12;
  localparam S_DELAY = 4'd13;

  localparam DELAY_TIME = 2 * SCL_HALF_PERIOD;
  localparam SCL_HALF_PERIOD = SCL_PERIOD / 2;

  reg scl_reg, scl_reg_next;
  reg sda_reg, sda_reg_next;

  reg [3:0] state, state_next;
  reg [$clog2(DELAY_TIME)-1:0] delay, delay_next;

  reg ready_next;
  reg [7:0] rdata_next;
  reg rdata_valid_next;

  reg [2:0] bit_counter, bit_counter_next;

  reg [7:0] wdata_buf, wdata_buf_next;
  reg wack_buf, wack_buf_next;

  reg ack, ack_next;

  reg [$clog2(SCL_HALF_PERIOD)-1:0] scl_ctr, scl_ctr_next;

  always @(*) begin
    ready_next       = ready;
    rdata_valid_next = rdata_valid;
    delay_next       = delay;
    scl_reg_next     = scl_reg;
    sda_reg_next     = sda_reg;
    bit_counter_next = bit_counter;
    wdata_buf_next   = wdata_buf;
    ack_next         = ack;
    rdata_next       = rdata;
    wack_buf_next    = wack_buf;

    state_next       = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          ready_next       = 0;
          rdata_valid_next = 0;
          wdata_buf_next   = wdata;
          wack_buf_next    = wack;
          scl_ctr_next     = SCL_HALF_PERIOD;

          case (cmd)
            `CMD_START: state_next = S_START;
            `CMD_WRITE: state_next = S_WRITE_SETUP;
            `CMD_READ:  state_next = S_READ_SETUP;
            `CMD_STOP: begin
              scl_ctr_next = SCL_HALF_PERIOD;
              state_next   = S_STOP_SETUP;
            end
            default: begin
              scl_ctr_next = 0;
              state_next   = S_IDLE;
            end
          endcase
        end
      end

      S_START: begin
        if (sda_reg) begin
          sda_reg_next = 0;
        end else begin
          scl_ctr_next = scl_ctr - 1;

          if (scl_ctr_next == 0) begin
            scl_reg_next = 0;

            state_next   = S_DELAY;
            delay_next   = DELAY_TIME;
          end
        end
      end

      S_STOP_SETUP: begin
        sda_reg_next = 0;
        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          state_next = S_STOP;
        end
      end
      S_STOP: begin
        if (!scl_reg) begin
          scl_reg_next = 1;
          scl_ctr_next = SCL_HALF_PERIOD;

        end else begin
          scl_ctr_next = scl_ctr - 1;

          if (scl_ctr_next == 0) begin
            sda_reg_next = 1;
            state_next   = S_DELAY;
            delay_next   = DELAY_TIME;
          end
        end
      end

      S_WRITE_SETUP: begin
        sda_reg_next = wdata_buf[7];
        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          wdata_buf_next = {wdata_buf[6:0], wdata_buf[7]};
          state_next = S_WRITE_CLK;
        end
      end
      S_WRITE_CLK: begin
        if (!scl_reg) begin
          // Begin bit write
          scl_reg_next = 1;
          scl_ctr_next = SCL_HALF_PERIOD;
        end else begin
          scl_ctr_next = scl_ctr - 1;

          if (scl_ctr_next == 0) begin
            // End bit write
            scl_reg_next     = 0;
            state_next       = S_WRITE_SETUP;
            bit_counter_next = bit_counter + 1;

            if (bit_counter_next == 0) begin
              scl_ctr_next = SCL_HALF_PERIOD;
              state_next   = S_READ_ACK_SETUP_1;
            end
          end
        end
      end
      S_READ_ACK_SETUP_1: begin
        sda_reg_next = 1;  // Release SDA

        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          state_next   = S_READ_ACK_SETUP_2;
          scl_ctr_next = SCL_HALF_PERIOD;
        end
      end
      S_READ_ACK_SETUP_2: begin
        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          scl_reg_next = 1;
          state_next   = S_READ_ACK;
          scl_ctr_next = SCL_HALF_PERIOD;
        end
      end
      S_READ_ACK: begin
        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          ack_next     = sda;
          scl_reg_next = 0;

          state_next   = S_DELAY;
          delay_next   = DELAY_TIME;
        end
      end

      S_READ_SETUP: begin
        sda_reg_next = 1;  // Release SDA

        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          state_next = S_READ_CLK;
        end
      end
      S_READ_CLK: begin
        if (!scl_reg) begin
          // Begin bit read
          scl_reg_next = 1;
          scl_ctr_next = SCL_HALF_PERIOD;
        end else begin
          scl_ctr_next = scl_ctr - 1;

          if (scl_ctr_next == 0) begin
            // End bit read
            rdata_next       = {rdata[6:0], sda};
            scl_reg_next     = 0;
            bit_counter_next = bit_counter + 1;
            state_next       = S_READ_SETUP;

            if (bit_counter_next == 0) begin
              state_next = S_WRITE_ACK_SETUP;
              rdata_valid_next = 1;
            end else begin
            end
          end
        end
      end
      S_WRITE_ACK_SETUP: begin
        sda_reg_next = wack_buf;
        scl_ctr_next = scl_ctr - 1;

        if (scl_ctr_next == 0) begin
          state_next = S_WRITE_ACK;
        end
      end
      S_WRITE_ACK: begin
        if (!scl_reg) begin
          scl_reg_next = 1;
          scl_ctr_next = SCL_HALF_PERIOD;
        end else begin
          scl_ctr_next = scl_ctr - 1;

          if (scl_ctr_next == 0) begin
            scl_reg_next = 0;
            state_next   = S_DELAY;
            delay_next   = DELAY_TIME;
          end
        end
      end

      S_DELAY: begin
        delay_next = delay - 1;

        if (delay_next == 0) begin
          ready_next = 1;
          state_next = S_IDLE;
        end
      end
      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      scl_reg     <= 1;
      sda_reg     <= 1;
      delay       <= 0;
      ready       <= 1;
      rdata       <= 0;
      rdata_valid <= 0;
      bit_counter <= 0;
      wdata_buf   <= 0;
      ack         <= 0;
      wack_buf    <= 0;
      scl_ctr     <= 0;
    end else begin
      state       <= state_next;
      scl_reg     <= scl_reg_next;
      sda_reg     <= sda_reg_next;
      delay       <= delay_next;
      ready       <= ready_next;
      rdata       <= rdata_next;
      rdata_valid <= rdata_valid_next;
      bit_counter <= bit_counter_next;
      wdata_buf   <= wdata_buf_next;
      ack         <= ack_next;
      wack_buf    <= wack_buf_next;
      scl_ctr     <= scl_ctr_next;
    end
  end

  assign scl = scl_reg ? 1'bz : 1'b0;
  assign sda = sda_reg ? 1'bz : 1'b0;
endmodule

module nes_bridge #(
    parameter SLAVE_ADDR = 7'h52,
    parameter SCL_PERIOD = 500  // 10 Khz assuming base clock of 50 MHz
) (
    input wire clk,
    input wire rst_n,

    input wire start,

    output wire scl,
    output wire sda,

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
  reg i2c_start;
  reg [7:0] i2c_wdata;
  reg i2c_wack;
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

      .scl(scl),
      .sda(sda)
  );

  always @(*) begin
    i2c_start         = 0;
    state_next        = state;
    i2c_cmd           = 0;
    i2c_wdata         = 8'bzzzz_zzzz;
    read_ctr_next     = read_ctr;
    joypad_next       = joypad;
    joypad_valid_next = joypad_valid;

    case (state)
      S_IDLE: begin
        if (start) begin
          i2c_start = 1;
          i2c_cmd = `CMD_START;
          state_next = S_START_1;
          joypad_valid_next = 0;
        end
      end
      S_START_1: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_WRITE;
          i2c_wdata = {SLAVE_ADDR, RW_WRITE};
          state_next = S_ADDRW_WRITE;
        end
      end
      S_ADDRW_WRITE: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_WRITE;
          i2c_wdata = 8'h00;
          state_next = S_INIT_WRITE;
        end
      end
      S_INIT_WRITE: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_STOP;
          state_next = S_STOP_1;
        end
      end
      S_STOP_1: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_START;
          state_next = S_START_2;
        end
      end
      S_START_2: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_WRITE;
          i2c_wdata = {SLAVE_ADDR, RW_READ};
          state_next = S_ADDRR_WRITE;
        end
      end
      S_ADDRR_WRITE: begin
        if (i2c_ready) begin
          i2c_start = 1;
          i2c_cmd = `CMD_READ;
          state_next = S_DATA_READ;
          i2c_wack = 0;
          read_ctr_next = 6;
        end
      end
      S_DATA_READ: begin
        if (i2c_ready) begin
          read_ctr_next = read_ctr - 1;

          i2c_start = 1;
          i2c_cmd = `CMD_READ;
          state_next = S_DATA_READ;
          i2c_wack = read_ctr_next == 1;

          if (read_ctr_next == 1) begin
            // Just read penultimate byte
            joypad_next[0] = i2c_rdata[7];
            joypad_next[2] = i2c_rdata[6];
            joypad_next[5] = i2c_rdata[4];
            joypad_next[4] = i2c_rdata[2];

          end else if (read_ctr_next == 0) begin
            // Just read last byte
            joypad_next[6] = i2c_rdata[6];
            joypad_next[7] = i2c_rdata[4];
            joypad_next[1] = i2c_rdata[1];
            joypad_next[3] = i2c_rdata[0];
            joypad_valid_next = 1;

            i2c_start = 1;
            i2c_cmd = `CMD_STOP;
            state_next = S_STOP_2;
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

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      read_ctr     <= 0;
      joypad       <= 8'hFF;
      joypad_valid <= 0;
    end else begin
      state        <= state_next;
      read_ctr     <= read_ctr_next;
      joypad       <= joypad_next;
      joypad_valid <= joypad_valid_next;
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
