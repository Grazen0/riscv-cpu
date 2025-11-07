`default_nettype none

`define CMD_START 2'd0
`define CMD_WRITE 2'd1
`define CMD_READ 2'd2
`define CMD_STOP 2'd3

module i2c_controller (
    input wire clk,
    input wire rst_n,

    input wire [1:0] cmd,
    input wire [7:0] wdata,  // data to write in case of CMD_WRITE
    input wire wack,
    input wire start,

    output reg done,
    output reg [7:0] rdata,
    output reg rdata_valid,

    output tri scl,
    output tri sda
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

  localparam DELAY_TIME = 4;

  reg scl_reg, scl_reg_next;
  reg sda_reg, sda_reg_next;

  reg [3:0] state, next_state;
  reg [4:0] delay, delay_next;

  reg done_next;
  reg [7:0] rdata_next;
  reg rdata_valid_next;

  reg [2:0] bit_counter, bit_counter_next;

  reg [7:0] wdata_buf, wdata_buf_next;
  reg wack_buf, wack_buf_next;

  reg ack, ack_next;


  always @(*) begin
    done_next        = done;
    rdata_valid_next = rdata_valid;
    delay_next       = delay;
    scl_reg_next     = scl_reg;
    sda_reg_next     = sda_reg;
    bit_counter_next = bit_counter;
    wdata_buf_next   = wdata_buf;
    ack_next         = ack;
    rdata_next       = rdata;
    wack_buf_next    = wack_buf;

    next_state       = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          done_next        = 0;
          rdata_valid_next = 0;
          wdata_buf_next   = wdata;
          wack_buf_next    = wack;

          case (cmd)
            `CMD_START: next_state = S_START;
            `CMD_WRITE: next_state = S_WRITE_SETUP;
            `CMD_READ:  next_state = S_READ_SETUP;
            `CMD_STOP:  next_state = S_STOP_SETUP;
            default:    next_state = S_IDLE;
          endcase
        end
      end

      S_START: begin
        if (sda_reg) begin
          sda_reg_next = 0;
        end else begin
          scl_reg_next = 0;

          next_state   = S_DELAY;
          delay_next   = DELAY_TIME;
        end
      end

      S_STOP_SETUP: begin
        sda_reg_next = 0;
        next_state   = S_STOP;
      end
      S_STOP: begin
        if (!scl_reg) begin
          scl_reg_next = 1;
        end else begin
          sda_reg_next = 1;

          next_state   = S_DELAY;
          delay_next   = DELAY_TIME;
        end
      end

      S_WRITE_SETUP: begin
        sda_reg_next = wdata_buf[7];
        wdata_buf_next = {wdata_buf[6:0], wdata_buf[7]};
        next_state = S_WRITE_CLK;
      end
      S_WRITE_CLK: begin
        if (!scl_reg) begin
          // Begin bit write
          scl_reg_next = 1;
        end else begin
          // End bit write
          scl_reg_next     = 0;
          next_state       = S_WRITE_SETUP;
          bit_counter_next = bit_counter + 1;

          if (bit_counter_next == 0) begin
            next_state = S_READ_ACK_SETUP_1;
          end
        end
      end
      S_READ_ACK_SETUP_1: begin
        sda_reg_next = 1;  // Release SDA
        next_state   = S_READ_ACK_SETUP_2;
      end
      S_READ_ACK_SETUP_2: begin
        scl_reg_next = 1;
        next_state   = S_READ_ACK;
      end
      S_READ_ACK: begin
        ack_next     = sda;
        scl_reg_next = 0;

        next_state   = S_DELAY;
        delay_next   = DELAY_TIME;
      end

      S_READ_SETUP: begin
        sda_reg_next = 1;  // Release SDA
        next_state   = S_READ_CLK;
      end
      S_READ_CLK: begin
        if (!scl_reg) begin
          // Begin bit read
          scl_reg_next = 1;
        end else begin
          // End bit read
          rdata_next       = {rdata[6:0], sda};
          scl_reg_next     = 0;
          bit_counter_next = bit_counter + 1;
          next_state       = S_READ_SETUP;

          if (bit_counter_next == 0) begin
            next_state = S_WRITE_ACK_SETUP;
            rdata_valid_next = 1;
          end
        end
      end
      S_WRITE_ACK_SETUP: begin
        sda_reg_next = wack_buf;
        next_state   = S_WRITE_ACK;
      end
      S_WRITE_ACK: begin
        if (!scl_reg) begin
          scl_reg_next = 1;
        end else begin
          scl_reg_next = 0;
          next_state   = S_DELAY;
          delay_next   = DELAY_TIME;
        end
      end

      S_DELAY: begin
        delay_next = delay - 1;

        if (delay_next == 0) begin
          done_next  = 1;
          next_state = S_IDLE;
        end
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      scl_reg     <= 1;
      sda_reg     <= 1;
      delay       <= 0;
      done        <= 0;
      rdata       <= 0;
      rdata_valid <= 0;
      bit_counter <= 0;
      wdata_buf   <= 0;
      ack         <= 0;
      wack_buf    <= 0;
    end else begin
      state       <= next_state;
      scl_reg     <= scl_reg_next;
      sda_reg     <= sda_reg_next;
      delay       <= delay_next;
      done        <= done_next;
      rdata       <= rdata_next;
      rdata_valid <= rdata_valid_next;
      bit_counter <= bit_counter_next;
      wdata_buf   <= wdata_buf_next;
      ack         <= ack_next;
      wack_buf    <= wack_buf_next;
    end
  end

  assign scl = scl_reg ? 1'bz : 1'b0;
  assign sda = sda_reg ? 1'bz : 1'b0;
endmodule

module nes_bridge (
    input wire clk,
    input wire rst_n,

    // input wire wdata,
    // input wire wenable,

    output wire scl,
    output wire sda,

    output wire [7:0] joypad_data
);
  localparam I2C_ADDR = 7'h52;
  localparam RW_WRITE = 1'b0;
  localparam RW_READ = 1'b1;

  reg [1:0] cmd;
  reg start;
  reg [7:0] wdata;
  reg wack;

  wire done;

  i2c_controller controller (
      .clk  (clk),
      .rst_n(rst_n),

      .cmd  (cmd),
      .start(start),
      .wdata(wdata),
      .wack (wack),

      .done(done),

      .scl(scl),
      .sda(sda)
  );

  initial begin
    start = 0;
    #15;

    cmd   = `CMD_START;
    start = 1;
    #10 start = 0;

    @(posedge done);
    #5;

    cmd   = `CMD_WRITE;
    wdata = 8'h52;
    start = 1;
    #10 start = 0;

    @(posedge done);
    #5;

    cmd   = `CMD_READ;
    wack  = 1;
    start = 1;
    #10 start = 0;

    // 01100010
    @(posedge scl) force sda = 0;
    @(posedge scl) release sda;
    @(posedge scl) release sda;
    @(posedge scl) force sda = 0;
    @(posedge scl) force sda = 0;
    @(posedge scl) force sda = 0;
    @(posedge scl) release sda;
    @(posedge scl) force sda = 0;

    @(negedge scl) release sda;

    @(posedge done);
    #5;

    cmd   = `CMD_STOP;
    start = 1;
    #10 start = 0;

  end
endmodule
