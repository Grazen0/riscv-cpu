`default_nettype none
`include "float_alu.vh"

module x0 #(
    parameter M_WIDTH = 24
) (
    input wire [9:0] in,
    output wire [M_WIDTH-1:0] out
);
  reg [6:0] ROM[0:1023];
  wire [6:0] seven;

  initial begin
    $readmemh("/home/jdgt/Code/utec/arqui/riscv-cpu/data/x0.mem", ROM);
  end

  assign seven = ROM[in];
  assign out = (in == 0)
    ? {1'b1, seven, {(M_WIDTH - 8) {1'b0}}}
    : {2'b01, seven, {(M_WIDTH - 9) {1'b0}}};
endmodule

module fp_recip (
    input  wire [31:0] in_bits,
    output reg  [31:0] out_bits,
    output reg  [ 4:0] except_flags
);
  // Bit format
  parameter EXP = 8;
  parameter FRAC = 23;
  parameter BIAS = 127;

  // Anchos internos
  parameter K = 10;
  parameter M_WIDTH = 1 + FRAC;
  parameter Y_WIDTH = M_WIDTH + 4;

  // Extracción de campos
  wire            sign_in = in_bits[31];
  wire [ EXP-1:0] exp_in = in_bits[FRAC+EXP-1:FRAC];
  wire [FRAC-1:0] frac_in = in_bits[FRAC-1:0];

  wire            is_exp_all_zero = (exp_in == 0);
  wire            is_exp_all_one = (exp_in == {EXP{1'b1}});
  wire            is_frac_zero = (frac_in == 0);

  localparam [Y_WIDTH-1:0] ONE_FIXED = (32'd1 << FRAC);
  localparam [Y_WIDTH-1:0] TWO_FIXED = (32'd2 << FRAC);

  // Señales internas
  reg [M_WIDTH-1:0] m_int, tmp;
  reg [Y_WIDTH-1:0] y0, y1, y2, y_norm;
  reg [2*Y_WIDTH-1:0] prod_my, prod_ycorr;
  reg [Y_WIDTH-1:0] correction, prod_my_shr;
  reg [EXP-1:0] out_exp;
  reg [FRAC-1:0] out_frac;
  reg out_sign;
  reg special_out_done;
  reg adj;
  integer exp_unbiased, exp_out_i, shift_count, i;

  // LUT x0
  wire [K-1:0] x0_index;
  wire [M_WIDTH-1:0] x0_lut_out;
  assign x0_index = m_int[M_WIDTH-2:M_WIDTH-1-K];

  x0 x0_inst (
      .in (x0_index),
      .out(x0_lut_out)
  );

  // Lógica principal
  always @(*) begin
    // Valores por defecto
    out_bits = 0;
    except_flags = 0;
    special_out_done = 0;
    out_sign = sign_in;
    out_exp = 0;
    out_frac = 0;
    adj = 0;

    // --- Casos especiales: Inf / NaN / 0 ---
    if (is_exp_all_one) begin
      if (is_frac_zero) begin
        // Inf -> 0
        out_exp  = 0;
        out_frac = 0;
      end else begin
        // NaN -> NaN
        out_exp = {EXP{1'b1}};
        out_frac = {1'b1, {(FRAC - 1) {1'b0}}};
        except_flags[`F_INVALID] = 1'b1;
      end
      special_out_done = 1;
    end else if (is_exp_all_zero && is_frac_zero) begin
      // 0 -> Inf
      out_exp = {EXP{1'b1}};
      out_frac = 0;
      except_flags[`F_DIVIDE_BY_ZERO] = 1'b1;
      special_out_done = 1;
    end

    // --- Normalización y Newton-Raphson ---
    if (!special_out_done) begin
      // Preparar mantisa y exponente
      if (!is_exp_all_zero) begin
        m_int = {1'b1, frac_in};
        exp_unbiased = exp_in - BIAS;
      end else begin
        tmp = {1'b0, frac_in};
        shift_count = 0;
        begin : search
          for (i = 0; i < M_WIDTH; i = i + 1) begin
            if (tmp[M_WIDTH-1-i]) begin
              shift_count = i;
              disable search;
            end
          end
        end
        m_int = tmp << shift_count;
        exp_unbiased = 1 - BIAS - shift_count;
      end

      // Aproximación inicial
      y0 = x0_lut_out;

      // Newton-Raphson iteración 1
      prod_my = m_int * y0;
      prod_my_shr = prod_my >> FRAC;
      correction = TWO_FIXED - prod_my_shr;
      prod_ycorr = y0 * correction;
      y1 = prod_ycorr >> FRAC;

      // Newton-Raphson iteración 2
      prod_my = m_int * y1;
      prod_my_shr = prod_my >> FRAC;
      correction = TWO_FIXED - prod_my_shr;
      prod_ycorr = y1 * correction;
      y2 = prod_ycorr >> FRAC;

      y_norm = y2;
      if (y_norm < ONE_FIXED) begin
        y_norm = y_norm << 1;
        adj = 1;
      end

      // Exponente de salida
      exp_out_i = BIAS - exp_unbiased - adj;

      if (exp_out_i >= ((1 << EXP) - 1)) begin
        out_exp = {EXP{1'b1}};
        out_frac = 0;
        except_flags[`F_OVERFLOW] = 1'b1;
      end else if (exp_out_i <= 0) begin
        out_exp = 0;
        out_frac = 0;
        except_flags[`F_UNDERFLOW] = 1'b1;
      end else begin
        out_exp = exp_out_i[EXP-1:0];
        out_frac = y_norm[FRAC-1:0];
        except_flags[`F_INEXACT] = 1'b1;
      end

      out_bits = {out_sign, out_exp, out_frac};
    end
  end
endmodule

module mul_decode (
    input wire [31:0] op_a,
    input wire [31:0] op_b,

    input wire mode_fp,

    output reg sign_a,
    output reg sign_b,
    output reg [7:0] exp_a,
    output reg [7:0] exp_b,
    output reg [22:0] mant_a,
    output reg [22:0] mant_b,

    output wire is_zero_a,
    output wire is_zero_b,
    output wire is_nan_a,
    output wire is_nan_b,
    output wire is_inf_a,
    output wire is_inf_b
);
  wire [7:0] raw_exp_a = op_a[30:23];
  wire [7:0] raw_exp_b = op_b[30:23];

  wire [22:0] raw_mant_a = op_a[22:0];
  wire [22:0] raw_mant_b = op_b[22:0];

  wire is_denorm_a = (raw_exp_a == 8'b0) && (raw_mant_a != 23'b0);
  wire is_denorm_b = (raw_exp_b == 8'b0) && (raw_mant_b != 23'b0);

  always @(*) begin
    sign_a = op_a[31];
    sign_b = op_b[31];

    exp_a  = is_denorm_a ? 8'b0 : raw_exp_a;
    exp_b  = is_denorm_b ? 8'b0 : raw_exp_b;

    mant_a = is_denorm_a ? 23'b0 : raw_mant_a;
    mant_b = is_denorm_b ? 23'b0 : raw_mant_b;
  end

  assign is_zero_a = (exp_a == 8'b0) && (mant_a == 23'b0);
  assign is_zero_b = (exp_b == 8'b0) && (mant_b == 23'b0);

  assign is_nan_a  = (exp_a == 8'b11111111) && (mant_a != 23'b0);
  assign is_nan_b  = (exp_b == 8'b11111111) && (mant_b != 23'b0);

  assign is_inf_a  = (exp_a == 8'b11111111) && (mant_a == 23'b0);
  assign is_inf_b  = (exp_b == 8'b11111111) && (mant_b == 23'b0);

endmodule

module mul_exception (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire is_zero_a,
    input wire is_zero_b,
    input wire is_nan_a,
    input wire is_nan_b,
    input wire is_inf_a,
    input wire is_inf_b,

    input wire [4:0] initial_flags,

    output reg [31:0] spec_result,
    output reg [4:0] spec_flags,
    output reg spec_override,

    input  wire mode_fp_in,
    output reg  mode_fp_out,

    input  wire round_mode_in,
    output reg  round_mode_out,

    input wire sign_a_in,
    input wire sign_b_in,
    input wire [7:0] exp_a_in,
    input wire [7:0] exp_b_in,
    input wire [22:0] mant_a_in,
    input wire [22:0] mant_b_in,

    output reg sign_a_out,
    output reg sign_b_out,
    output reg [7:0] exp_a_out,
    output reg [7:0] exp_b_out,
    output reg [22:0] mant_a_out,
    output reg [22:0] mant_b_out
);

  wire final_sign = sign_a_in ^ sign_b_in;
  assign ready_out = !valid_out || ready_in;

  reg mode_fp_out_next;
  reg round_mode_out_next;
  reg sign_a_out_next, sign_b_out_next;
  reg [7:0] exp_a_out_next, exp_b_out_next;
  reg [22:0] mant_a_out_next, mant_b_out_next;
  reg [31:0] spec_result_next;
  reg [4:0] spec_flags_next;
  reg spec_override_next;

  always @(*) begin
    mode_fp_out_next    = mode_fp_out;
    round_mode_out_next = round_mode_out;
    sign_a_out_next     = sign_a_out;
    sign_b_out_next     = sign_b_out;
    exp_a_out_next      = exp_a_out;
    exp_b_out_next      = exp_b_out;
    mant_a_out_next     = mant_a_out;
    mant_b_out_next     = mant_b_out;

    spec_result_next    = spec_result;
    spec_flags_next     = spec_flags;
    spec_override_next  = spec_override;

    if (valid_in && ready_out) begin
      mode_fp_out_next    = mode_fp_in;
      round_mode_out_next = round_mode_in;
      sign_a_out_next     = sign_a_in;
      sign_b_out_next     = sign_b_in;
      exp_a_out_next      = exp_a_in;
      exp_b_out_next      = exp_b_in;
      mant_a_out_next     = mant_a_in;
      mant_b_out_next     = mant_b_in;

      spec_override_next  = 1'b0;
      spec_result_next    = 32'b0;
      spec_flags_next     = initial_flags;

      if (is_nan_a || is_nan_b) begin
        spec_override_next = 1'b1;
        spec_result_next = {1'b0, 8'hFF, 23'h400000};
        spec_flags_next[`F_INVALID] = 1'b1;
      end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
        spec_override_next = 1'b1;
        spec_result_next = {1'b1, 8'hFF, 23'h400000};
        spec_flags_next[`F_INVALID] = 1'b1;
      end else if (is_inf_a || is_inf_b) begin
        spec_override_next = 1'b1;
        spec_result_next   = {final_sign, 8'hFF, 23'h0};
      end else if (is_zero_a || is_zero_b) begin
        spec_override_next = 1'b1;
        spec_result_next   = {final_sign, 31'h0};
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out      <= 1'b0;
      spec_result    <= 32'b0;
      spec_flags     <= 5'b0;
      spec_override  <= 1'b0;
      mode_fp_out    <= 1'b0;
      round_mode_out <= 1'b0;
      sign_a_out     <= 1'b0;
      sign_b_out     <= 1'b0;
      exp_a_out      <= 8'b0;
      exp_b_out      <= 8'b0;
      mant_a_out     <= 23'b0;
      mant_b_out     <= 23'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      mode_fp_out    <= mode_fp_out_next;
      round_mode_out <= round_mode_out_next;
      sign_a_out     <= sign_a_out_next;
      sign_b_out     <= sign_b_out_next;
      exp_a_out      <= exp_a_out_next;
      exp_b_out      <= exp_b_out_next;
      mant_a_out     <= mant_a_out_next;
      mant_b_out     <= mant_b_out_next;
      spec_result    <= spec_result_next;
      spec_flags     <= spec_flags_next;
      spec_override  <= spec_override_next;
    end
  end

endmodule

module mul_prod (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire sign_a,
    input wire sign_b,
    input wire [7:0] exp_a,
    input wire [7:0] exp_b,
    input wire [22:0] mant_a,
    input wire [22:0] mant_b,

    output reg final_sign,
    output reg [8:0] exp_sum,
    output reg [47:0] mant_prod,

    input  wire mode_fp_in,
    output reg  mode_fp_out,

    input  wire round_mode_in,
    output reg  round_mode_out,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);

  assign ready_out = !valid_out || ready_in;
  wire [23:0] mant_a_full = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a};
  wire [23:0] mant_b_full = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};

  reg mode_fp_out_next;
  reg round_mode_out_next;

  reg final_sign_next;
  reg [8:0] exp_sum_next;
  reg [47:0] mant_prod_next;

  reg spec_override_out_next;
  reg [31:0] spec_result_out_next;
  reg [4:0] spec_flags_out_next;

  always @(*) begin
    final_sign_next        = final_sign;
    exp_sum_next           = exp_sum;
    mant_prod_next         = mant_prod;

    mode_fp_out_next       = mode_fp_out;
    round_mode_out_next    = round_mode_out;
    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin
      final_sign_next        = sign_a ^ sign_b;
      exp_sum_next           = {1'b0, exp_a} + {1'b0, exp_b} - 9'd127;
      mant_prod_next         = mant_a_full * mant_b_full;

      mode_fp_out_next       = mode_fp_in;
      round_mode_out_next    = round_mode_in;
      spec_override_out_next = spec_override_in;
      spec_result_out_next   = spec_result_in;
      spec_flags_out_next    = spec_flags_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      final_sign        <= 1'b0;
      exp_sum           <= 9'b0;
      mant_prod         <= 48'b0;
      mode_fp_out       <= 1'b0;
      round_mode_out    <= 1'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      final_sign        <= final_sign_next;
      exp_sum           <= exp_sum_next;
      mant_prod         <= mant_prod_next;
      mode_fp_out       <= mode_fp_out_next;
      round_mode_out    <= round_mode_out_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module mul_norm (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire [ 8:0] exp_sum,
    input wire [47:0] mant_prod,

    output reg [ 8:0] exp_norm,
    output reg [47:0] mant_norm,

    input  wire mode_fp_in,
    output reg  mode_fp_out,

    input  wire round_mode_in,
    output reg  round_mode_out,

    input  wire final_sign_in,
    output reg  final_sign_out,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);

  assign ready_out = !valid_out || ready_in;

  reg        final_sign_out_next;
  reg [ 8:0] exp_norm_next;
  reg [47:0] mant_norm_next;

  reg        mode_fp_out_next;
  reg        round_mode_out_next;

  reg        spec_override_out_next;
  reg [31:0] spec_result_out_next;
  reg [ 4:0] spec_flags_out_next;

  always @(*) begin
    exp_norm_next          = exp_norm;
    mant_norm_next         = mant_norm;

    mode_fp_out_next       = mode_fp_out;
    round_mode_out_next    = round_mode_out;
    final_sign_out_next    = final_sign_out;
    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin

      exp_norm_next          = mant_prod[47] ? exp_sum + 9'd1 : exp_sum;
      mant_norm_next         = mant_prod[47] ? (mant_prod >> 1) : mant_prod;

      mode_fp_out_next       = mode_fp_in;
      round_mode_out_next    = round_mode_in;
      final_sign_out_next    = final_sign_in;
      spec_override_out_next = spec_override_in;
      spec_result_out_next   = spec_result_in;
      spec_flags_out_next    = spec_flags_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      exp_norm          <= 8'b0;
      mant_norm         <= 48'b0;
      mode_fp_out       <= 1'b0;
      round_mode_out    <= 1'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      exp_norm          <= exp_norm_next;
      mant_norm         <= mant_norm_next;

      mode_fp_out       <= mode_fp_out_next;
      round_mode_out    <= round_mode_out_next;
      final_sign_out    <= final_sign_out_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module mul_round (
    input wire clk,
    input wire rst_n,

    input  wire valid_in,
    input  wire ready_in,
    output reg  valid_out,
    output wire ready_out,

    input wire [ 8:0] exp_norm,
    input wire [47:0] mant_norm,
    input wire        round_mode,

    output reg [ 7:0] final_exp,
    output reg [22:0] final_mant,

    input  wire mode_fp_in,
    output reg  mode_fp_out,

    input  wire final_sign_in,
    output reg  final_sign_out,

    input wire spec_override_in,
    input wire [31:0] spec_result_in,
    input wire [4:0] spec_flags_in,

    output reg spec_override_out,
    output reg [31:0] spec_result_out,
    output reg [4:0] spec_flags_out
);
  assign ready_out = !valid_out || ready_in;

  reg  [ 7:0] final_exp_next;
  reg  [22:0] final_mant_next;
  reg         mode_fp_out_next;
  reg         final_sign_out_next;
  reg         spec_override_out_next;
  reg  [31:0] spec_result_out_next;
  reg  [ 4:0] spec_flags_out_next;

  wire        mant_lsb = mant_norm[23];
  wire        G = mant_norm[22];
  wire        R = mant_norm[21];
  wire        S = |mant_norm[20:0];

  wire        round_up = (round_mode) ? 1'b0 : G && (R | S | mant_lsb);

  wire [24:0] mant_rounded = mant_norm[46:23] + {23'b0, round_up};

  wire [ 8:0] exp_post = mant_rounded[24] ? exp_norm + 9'd1 : exp_norm;
  wire [22:0] mant_post = mant_rounded[24] ? mant_rounded[23:1] : mant_rounded[22:0];

  wire        overflow = (exp_post[8] || exp_post[7:0] == 8'hFF);
  wire        underflow = (exp_post[7:0] == 8'h00) && (mant_post != 0);
  wire        inexact = (G | R | S);

  always @(*) begin
    final_exp_next         = final_exp;
    final_mant_next        = final_mant;
    mode_fp_out_next       = mode_fp_out;
    final_sign_out_next    = final_sign_out;
    spec_override_out_next = spec_override_out;
    spec_result_out_next   = spec_result_out;
    spec_flags_out_next    = spec_flags_out;

    if (valid_in && ready_out) begin
      final_exp_next         = overflow ? 8'hFF : exp_post[7:0];
      final_mant_next        = overflow ? 23'h0 : mant_post;
      mode_fp_out_next       = mode_fp_in;
      final_sign_out_next    = final_sign_in;
      spec_override_out_next = spec_override_in;
      spec_result_out_next   = spec_result_in;
      spec_flags_out_next    = spec_flags_in;

      if (overflow) spec_flags_out_next[`F_OVERFLOW] = 1'b1;
      if (underflow) spec_flags_out_next[`F_UNDERFLOW] = 1'b1;
      if (inexact) spec_flags_out_next[`F_INEXACT] = 1'b1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out         <= 1'b0;
      final_exp         <= 8'b0;
      final_mant        <= 23'b0;
      mode_fp_out       <= 1'b0;
      final_sign_out    <= 1'b0;
      spec_override_out <= 1'b0;
      spec_result_out   <= 32'b0;
      spec_flags_out    <= 5'b0;
    end else begin
      if (valid_out && ready_in) begin
        valid_out <= 1'b0;
      end else if (valid_in && ready_out) begin
        valid_out <= 1'b1;
      end
      final_exp         <= final_exp_next;
      final_mant        <= final_mant_next;
      mode_fp_out       <= mode_fp_out_next;
      final_sign_out    <= final_sign_out_next;
      spec_override_out <= spec_override_out_next;
      spec_result_out   <= spec_result_out_next;
      spec_flags_out    <= spec_flags_out_next;
    end
  end

endmodule

module fp_multiplier (
    input wire clk,
    input wire rst_n,

    input wire [31:0] op_a,
    input wire [31:0] op_b,
    input wire mode_fp,
    input wire round_mode,

    input  wire start,
    input  wire ready_in,
    output wire valid_out,
    output wire ready_out,

    input wire [4:0] initial_flags,

    output wire sign_out,
    output wire [7:0] exp_out,
    output wire [26:0] mant_out,
    output wire [4:0] flags,
    output wire mode_fp_out
);

  //s0
  wire sign_a, sign_b;
  wire [7:0] exp_a, exp_b;
  wire [22:0] mant_a, mant_b;
  wire is_zero_a, is_zero_b, is_nan_a, is_nan_b, is_inf_a, is_inf_b;

  mul_decode s0 (
      .op_a   (op_a),
      .op_b   (op_b),
      .mode_fp(mode_fp),

      .sign_a(sign_a),
      .sign_b(sign_b),
      .exp_a (exp_a),
      .exp_b (exp_b),
      .mant_a(mant_a),
      .mant_b(mant_b),

      .is_zero_a(is_zero_a),
      .is_zero_b(is_zero_b),
      .is_nan_a (is_nan_a),
      .is_nan_b (is_nan_b),
      .is_inf_a (is_inf_a),
      .is_inf_b (is_inf_b)
  );

  //s1
  wire s1_valid, s1_ready;
  wire [31:0] spec_result;
  wire [4:0] spec_flags;
  wire spec_override;

  wire mode_fp_s1;
  wire round_mode_s1;

  wire sign_a_s1;
  wire sign_b_s1;
  wire [7:0] exp_a_s1, exp_b_s1;
  wire [22:0] mant_a_s1, mant_b_s1;

  mul_exception s1 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (start),
      .ready_in (s2_ready),
      .valid_out(s1_valid),
      .ready_out(s1_ready),

      .is_zero_a(is_zero_a),
      .is_zero_b(is_zero_b),
      .is_nan_a (is_nan_a),
      .is_nan_b (is_nan_b),
      .is_inf_a (is_inf_a),
      .is_inf_b (is_inf_b),

      .initial_flags(initial_flags),

      .spec_result  (spec_result),
      .spec_flags   (spec_flags),
      .spec_override(spec_override),

      .mode_fp_in (mode_fp),
      .mode_fp_out(mode_fp_s1),

      .round_mode_in (round_mode),
      .round_mode_out(round_mode_s1),

      .sign_a_in(sign_a),
      .sign_b_in(sign_b),
      .exp_a_in (exp_a),
      .exp_b_in (exp_b),
      .mant_a_in(mant_a),
      .mant_b_in(mant_b),

      .sign_a_out(sign_a_s1),
      .sign_b_out(sign_b_s1),
      .exp_a_out (exp_a_s1),
      .exp_b_out (exp_b_s1),
      .mant_a_out(mant_a_s1),
      .mant_b_out(mant_b_s1)
  );

  //s2
  wire s2_valid, s2_ready;
  wire final_sign;
  wire [8:0] exp_sum;
  wire [47:0] mant_prod;

  wire mode_fp_s2;
  wire round_mode_s2;

  wire spec_override_s2;
  wire [31:0] spec_result_s2;
  wire [4:0] spec_flags_s2;

  mul_prod s2 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s1_valid),
      .ready_in (s3_ready),
      .valid_out(s2_valid),
      .ready_out(s2_ready),

      .sign_a(sign_a_s1),
      .sign_b(sign_b_s1),
      .exp_a (exp_a_s1),
      .exp_b (exp_b_s1),
      .mant_a(mant_a_s1),
      .mant_b(mant_b_s1),

      .final_sign(final_sign),
      .exp_sum   (exp_sum),
      .mant_prod (mant_prod),

      .mode_fp_in (mode_fp_s1),
      .mode_fp_out(mode_fp_s2),

      .round_mode_in (round_mode_s1),
      .round_mode_out(round_mode_s2),

      .spec_override_in(spec_override),
      .spec_result_in  (spec_result),
      .spec_flags_in   (spec_flags),

      .spec_override_out(spec_override_s2),
      .spec_result_out  (spec_result_s2),
      .spec_flags_out   (spec_flags_s2)
  );

  //s3
  wire s3_valid, s3_ready;
  wire [8:0] exp_norm;
  wire [47:0] mant_norm;

  wire mode_fp_s3;
  wire round_mode_s3;

  wire final_sign_s3;
  wire spec_override_s3;
  wire [31:0] spec_result_s3;
  wire [4:0] spec_flags_s3;

  mul_norm s3 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s2_valid),
      .ready_in (s4_ready),
      .valid_out(s3_valid),
      .ready_out(s3_ready),

      .exp_sum  (exp_sum),
      .mant_prod(mant_prod),
      .exp_norm (exp_norm),
      .mant_norm(mant_norm),

      .mode_fp_in (mode_fp_s2),
      .mode_fp_out(mode_fp_s3),

      .round_mode_in (round_mode_s2),
      .round_mode_out(round_mode_s3),

      .final_sign_in (final_sign),
      .final_sign_out(final_sign_s3),

      .spec_override_in(spec_override_s2),
      .spec_result_in  (spec_result_s2),
      .spec_flags_in   (spec_flags_s2),

      .spec_override_out(spec_override_s3),
      .spec_result_out  (spec_result_s3),
      .spec_flags_out   (spec_flags_s3)
  );

  //s4
  wire s4_valid, s4_ready;
  wire [7:0] final_exp;
  wire [22:0] final_mant;

  wire mode_fp_s4;

  wire final_sign_s4;
  wire spec_override_s4;
  wire [31:0] spec_result_s4;
  wire [4:0] spec_flags_s4;

  mul_round s4 (
      .clk      (clk),
      .rst_n    (rst_n),
      .valid_in (s3_valid),
      .ready_in (ready_in),
      .valid_out(s4_valid),
      .ready_out(s4_ready),

      .exp_norm  (exp_norm),
      .mant_norm (mant_norm),
      .round_mode(round_mode_s3),

      .final_exp (final_exp),
      .final_mant(final_mant),

      .mode_fp_in (mode_fp_s3),
      .mode_fp_out(mode_fp_s4),

      .final_sign_in (final_sign_s3),
      .final_sign_out(final_sign_s4),

      .spec_override_in(spec_override_s3),
      .spec_result_in  (spec_result_s3),
      .spec_flags_in   (spec_flags_s3),

      .spec_override_out(spec_override_s4),
      .spec_result_out  (spec_result_s4),
      .spec_flags_out   (spec_flags_s4)
  );

  assign valid_out = s4_valid;
  assign sign_out = spec_override_s4 ? spec_result_s4[31] : final_sign_s4;
  assign exp_out = spec_override_s4 ? spec_result_s4[30:23] : final_exp;
  assign mant_out = {1'b1, spec_override_s4 ? spec_result_s4[22:0] : final_mant, 3'b000};
  assign flags = spec_flags_s4;
  assign mode_fp_out = mode_fp_s4;

  assign ready_out = s1_ready;
endmodule

module fp_align #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P-1:0] mant_a,
    input wire [E-1:0] exp_a,
    input wire [P-1:0] mant_b,
    input wire [E-1:0] exp_b,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_a_aligned,
    output reg [P+3:0] mant_b_aligned,
    output reg [E-1:0] bigger_exp,
    output reg is_a_nan,
    output reg is_b_nan,
    output reg is_a_inf,
    output reg is_b_inf,

    input  wire sign_a_in,
    output reg  sign_a_out,
    input  wire sign_b_in,
    output reg  sign_b_out,
    input  wire round_mode_in,
    output reg  round_mode_out,
    input  wire mode_fp_in,
    output reg  mode_fp_out
);
  assign ready_out = ready_in;

  reg [P+3:0] mant_a_aligned_next, mant_b_aligned_next;
  reg [E-1:0] bigger_exp_next;

  reg sign_a_aligned_next, sign_b_aligned_next, round_mode_out_next, mode_fp_out_next;
  reg is_a_nan_next, is_b_nan_next, is_a_inf_next, is_b_inf_next;

  wire signed [8:0] exp_diff = exp_a - exp_b;
  wire [P:0] mant_a_full = exp_a == 0 ? {1'b0, mant_a} : {1'b1, mant_a};
  wire [P:0] mant_b_full = exp_b == 0 ? {1'b0, mant_b} : {1'b1, mant_b};

  reg [$clog2(P+4):0] shamt;

  always @(*) begin
    if (valid_in && ready_out) begin
      shamt = 0;

      sign_a_aligned_next = sign_a_in;
      sign_b_aligned_next = sign_b_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next = mode_fp_in;

      is_a_nan_next = (exp_a == 8'hFF) && (mant_a != 0);
      is_b_nan_next = (exp_b == 8'hFF) && (mant_b != 0);
      is_a_inf_next = (exp_a == 8'hFF) && (mant_a == 0);
      is_b_inf_next = (exp_b == 8'hFF) && (mant_b == 0);

      if (exp_diff >= 0) begin
        // a >= b
        shamt = exp_diff[$clog2(P+4):0];

        bigger_exp_next = exp_a;
        mant_a_aligned_next = {mant_a_full, 3'b000};
        mant_b_aligned_next = {mant_b_full, 3'b000} >> shamt;
      end else begin
        // a < b
        shamt = -exp_diff[$clog2(P+4):0];

        bigger_exp_next = exp_b;
        mant_a_aligned_next = {mant_a_full, 3'b000} >> shamt;
        mant_b_aligned_next = {mant_b_full, 3'b000};
      end
    end else begin
      // Keep current outputs
      bigger_exp_next = bigger_exp;
      mant_a_aligned_next = mant_a_aligned;
      mant_b_aligned_next = mant_b_aligned;

      sign_a_aligned_next = sign_a_out;
      sign_b_aligned_next = sign_b_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next = mode_fp_out;
    end
  end


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_a_aligned <= {(P + 4) {1'b0}};
      mant_b_aligned <= {(P + 4) {1'b0}};
      bigger_exp     <= 8'b0;
      is_a_nan       <= 1'b0;
      is_b_nan       <= 1'b0;
      is_a_inf       <= 1'b0;
      is_b_inf       <= 1'b0;

      valid_out      <= 1'b0;

      sign_a_out     <= 1'b0;
      sign_b_out     <= 1'b0;
      round_mode_out <= 1'b0;
      mode_fp_out    <= 1'b0;

    end else begin
      mant_a_aligned <= mant_a_aligned_next;
      mant_b_aligned <= mant_b_aligned_next;
      bigger_exp <= bigger_exp_next;
      is_a_nan  <= is_a_nan_next;
      is_b_nan  <= is_b_nan_next;
      is_a_inf  <= is_a_inf_next;
      is_b_inf  <= is_b_inf_next;

      valid_out <= !ready_in ? valid_out : valid_in;

      sign_a_out <= sign_a_aligned_next;
      sign_b_out <= sign_b_aligned_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out    <= mode_fp_out_next;
    end
  end
endmodule

module fp_addsub #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_a_aligned,
    input wire [P+3:0] mant_b_aligned,
    input wire sign_a,
    input wire sign_b,
    input wire is_a_nan,
    input wire is_b_nan,
    input wire is_a_inf,
    input wire is_b_inf,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] sum,
    output reg carry_out,
    output reg sign_out,
    output reg [4:0] flags_out,

    input wire [E-1:0] exp_in,
    output reg [E-1:0] exp_out,
    input wire round_mode_in,
    output reg round_mode_out,
    input wire mode_fp_in,
    output reg mode_fp_out
);
  assign ready_out = ready_in;

  reg [P+3:0] sum_next;
  reg carry_out_next, sign_out_next;
  reg [4:0] flags_out_next;

  reg [P+3:0] mant_big, mant_small;
  reg sign_big;

  reg [E-1:0] exp_out_next;
  reg round_mode_out_next, mode_fp_out_next;

  always @(*) begin
    if (valid_in && ready_out) begin
      exp_out_next        = exp_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next    = mode_fp_in;
      flags_out_next      = 5'b0;

      if (is_a_nan || is_b_nan) begin
        // Result must be NaN
        exp_out_next               = 8'hFF;
        sum_next                   = {2'b11, {(P + 2) {1'b0}}};
        carry_out_next             = 1'b0;
        sign_out_next              = 1'b0;
        flags_out_next[`F_INVALID] = 1'b1;
      end else if (is_a_inf && is_b_inf && sign_a != sign_b) begin
        // Result must be NaN (again)
        exp_out_next               = 8'hFF;
        sum_next                   = {2'b11, {(P + 2) {1'b0}}};
        carry_out_next             = 1'b0;
        sign_out_next              = 1'b0;
        flags_out_next[`F_INVALID] = 1'b1;
      end else if (is_a_inf) begin
        // Result must be Inf (towards A)
        exp_out_next   = 8'hFF;
        sum_next       = {1'b1, {P{1'b0}}, 3'b000};
        carry_out_next = 1'b0;
        sign_out_next  = sign_a;
      end else if (is_b_inf) begin
        // Result must be Inf (towards B)
        exp_out_next   = 8'hFF;
        sum_next       = {1'b1, {P{1'b0}}, 3'b000};
        carry_out_next = 1'b0;
        sign_out_next  = sign_b;
      end else begin
        // Regular operations
        if (mant_a_aligned >= mant_b_aligned) begin
          mant_big   = mant_a_aligned;
          mant_small = mant_b_aligned;
          sign_big   = sign_a;
        end else begin
          mant_big   = mant_b_aligned;
          mant_small = mant_a_aligned;
          sign_big   = sign_b;
        end

        if (sign_a == sign_b) begin
          {carry_out_next, sum_next} = mant_a_aligned + mant_b_aligned;
          sign_out_next              = sign_a;
        end else begin
          sum_next       = mant_big - mant_small;
          carry_out_next = 1'b0;
          sign_out_next  = sign_big;
        end
      end

    end else begin
      // Keep current outputs
      sum_next            = sum;
      carry_out_next      = carry_out;
      sign_out_next       = sign_out;
      flags_out_next      = flags_out;

      exp_out_next        = exp_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next    = mode_fp_out;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum            <= {(P + 3) {1'b0}};
      carry_out      <= 1'b0;
      sign_out       <= 1'b0;
      flags_out      <= 5'b0;

      valid_out      <= 1'b0;

      exp_out        <= 8'b0;
      round_mode_out <= 1'b0;
      mode_fp_out    <= 1'b0;
    end else begin
      sum            <= sum_next;
      carry_out      <= carry_out_next;
      sign_out       <= sign_out_next;
      flags_out      <= flags_out_next;

      valid_out      <= !ready_in ? valid_out : valid_in;

      exp_out        <= exp_out_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out    <= mode_fp_out_next;
    end
  end
endmodule

module fp_normalize #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_in,
    input wire [E-1:0] exp_in,
    input wire carry,
    input wire [4:0] flags_in,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_out,
    output reg [E-1:0] exp_out,
    output reg [4:0] flags_out,

    input  wire sign_in,
    output reg  sign_out,
    input  wire round_mode_in,
    output reg  round_mode_out,
    input  wire mode_fp_in,
    output reg  mode_fp_out
);
  reg busy;

  reg [P+3:0] mant_next;
  reg [E-1:0] exp_next;
  reg [4:0] flags_next;

  reg valid_out_next, busy_next;

  reg sign_out_next, round_mode_out_next, mode_fp_out_next;

  assign ready_out = !busy && ready_in;

  always @(*) begin
    if (valid_in && ready_out) begin
      // Use stage inputs
      flags_next          = flags_in;

      sign_out_next       = sign_in;
      round_mode_out_next = round_mode_in;
      mode_fp_out_next    = mode_fp_in;

      if (carry) begin
        if (exp_in != 8'hFF) begin
          // Shift mantissa right
          mant_next = {1'b1, mant_in[P+3:1]};
          exp_next  = exp_in + 1;

          if (mant_in[0]) begin
            // Shifted out a 1
            flags_next[`F_INEXACT] = 1'b1;
          end
        end

        if (exp_next == 8'hFF) begin
          // Got infinity
          mant_next               = {(P + 4) {1'b0}};
          flags_next[`F_OVERFLOW] = 1'b1;
        end
      end else begin
        mant_next = mant_in;
        exp_next  = exp_in;
      end
    end else begin
      // Work with current data
      flags_next = flags_out;

      sign_out_next = sign_out;
      round_mode_out_next = round_mode_out;
      mode_fp_out_next = mode_fp_out;

      if (valid_out) begin
        mant_next = mant_out;
        exp_next  = exp_out;
      end else begin
        mant_next = mant_out << 1;
        exp_next  = exp_out - 1;
      end

      if (exp_next == 8'h00) begin
        flags_next[`F_UNDERFLOW] = 1'b1;
        flags_next[`F_INEXACT]   = 1'b1;
      end
    end

    if (exp_next == 0 && flags_next[`F_INEXACT]) begin
      flags_next[`F_UNDERFLOW] = 1'b1;
    end

    valid_out_next =
      (busy || (valid_in && ready_out)) &&
      (mant_next == 0 || mant_next[P+3] || exp_next == 0 || exp_next == 8'hFF);
    busy_next = (busy || (valid_in && ready_out)) && !valid_out_next;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_out       <= {(P + 4) {1'b0}};
      exp_out        <= 8'b0;
      flags_out      <= 5'b0;

      valid_out      <= 1'b0;
      busy           <= 1'b0;

      sign_out       <= 1'b0;
      round_mode_out <= 1'b0;
      mode_fp_out    <= 1'b0;
    end else begin
      mant_out       <= mant_next;
      exp_out        <= exp_next;
      flags_out      <= flags_next;

      valid_out      <= valid_out_next;
      busy           <= busy_next;

      sign_out       <= sign_out_next;
      round_mode_out <= round_mode_out_next;
      mode_fp_out    <= mode_fp_out_next;
    end
  end
endmodule

module fp_round #(
    parameter P = 23,
    parameter E = 8
) (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire ready_in,
    input wire [P+3:0] mant_in,
    input wire round_mode,

    output reg valid_out,
    output wire ready_out,
    output reg [P+3:0] mant_rounded,
    output reg carry_out,
    input wire [4:0] flags_in,
    output reg [4:0] flags_out,

    input wire [E-1:0] exp_in,
    output reg [E-1:0] exp_out,
    input wire sign_in,
    output reg sign_out,
    input wire mode_fp_in,
    output reg mode_fp_out
);
  localparam ROUND_NEAREST_EVEN = 1'b0;
  localparam ROUND_ZERO = 1'b1;

  reg [P+3:0] mant_rounded_next;
  reg carry_out_next;

  reg [E-1:0] exp_out_next;
  reg sign_out_next;
  reg [4:0] flags_out_next;
  reg mode_fp_out_next;

  wire rr = mant_in[3];
  wire m0 = mant_in[2];
  wire ss = |mant_in[1:0];

  reg round;

  assign ready_out = ready_in;

  always @(*) begin
    if (valid_in && ready_out) begin
      // Use stage inputs
      flags_out_next   = flags_in;

      exp_out_next     = exp_in;
      sign_out_next    = sign_in;
      mode_fp_out_next = mode_fp_in;

      case (round_mode)
        ROUND_NEAREST_EVEN: round = rr & (m0 | ss);
        ROUND_ZERO:         round = 1'b0;
      endcase

      if (rr | ss) begin
        flags_out_next[`F_INEXACT] = 1'b1;
      end

      if (round) begin
        flags_out_next[`F_INEXACT]          = 1'b1;
        {carry_out_next, mant_rounded_next} = mant_in + 'b1000;
      end else begin
        mant_rounded_next = mant_in;
        carry_out_next    = 1'b0;
      end
    end else begin
      // Use existing data
      mant_rounded_next = mant_rounded;
      carry_out_next    = carry_out;
      flags_out_next    = flags_out;

      exp_out_next      = exp_out;
      sign_out_next     = sign_out;
      mode_fp_out_next  = mode_fp_out;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mant_rounded <= {(P + 4) {1'b0}};
      carry_out    <= 1'b0;
      flags_out    <= 5'b0;

      valid_out    <= 1'b0;

      exp_out      <= 8'b0;
      sign_out     <= 1'b0;
      mode_fp_out  <= 1'b0;
    end else begin
      mant_rounded <= mant_rounded_next;
      carry_out    <= carry_out_next;
      flags_out    <= flags_out_next;

      valid_out    <= !ready_in ? valid_out : valid_in;

      exp_out      <= exp_out_next;
      sign_out     <= sign_out_next;
      mode_fp_out  <= mode_fp_out_next;
    end
  end
endmodule

module fp_adder #(
    parameter P = 23,
    parameter E = 8,
    parameter N = P + E + 1
) (
    input wire clk,
    input wire rst_n,
    input wire [N-1:0] op_a,
    input wire [N-1:0] op_b,
    input wire sub,
    input wire mode_fp,
    input wire round_mode,
    input wire start,
    input wire ready_in,

    output wire valid_out,
    output wire ready_out,
    output wire sign_out,
    output wire [E-1:0] exp_out,
    output wire [P+3:0] mant_out,
    output wire [4:0] flags,
    output wire mode_fp_out
);
  wire sign_a = op_a[N-1];
  wire sign_b = op_b[N-1];

  wire [E-1:0] exp_a = op_a[N-2:P];
  wire [E-1:0] exp_b = op_b[N-2:P];

  wire [P-1:0] mant_a = op_a[P-1:0];
  wire [P-1:0] mant_b = op_b[P-1:0];

  wire sign_b_corrected = sign_b ^ sub;

  wire align_valid, addsub_ready;

  wire [P+3:0] mant_a_aligned, mant_b_aligned;
  wire [E-1:0] exp_aligned;
  wire sign_a_aligned, sign_b_aligned;
  wire round_mode_aligned, mode_fp_aligned;
  wire is_a_nan, is_b_nan, is_a_inf, is_b_inf;

  fp_align align (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(start),
      .ready_in(addsub_ready),
      .mant_a(mant_a),
      .exp_a(exp_a),
      .mant_b(mant_b),
      .exp_b(exp_b),

      .valid_out(align_valid),
      .ready_out(ready_out),
      .mant_a_aligned(mant_a_aligned),
      .mant_b_aligned(mant_b_aligned),
      .bigger_exp(exp_aligned),
      .is_a_nan(is_a_nan),
      .is_b_nan(is_b_nan),
      .is_a_inf(is_a_inf),
      .is_b_inf(is_b_inf),

      .sign_a_in(sign_a),
      .sign_a_out(sign_a_aligned),
      .sign_b_in(sign_b_corrected),
      .sign_b_out(sign_b_aligned),
      .round_mode_in(round_mode),
      .round_mode_out(round_mode_aligned),
      .mode_fp_in(mode_fp),
      .mode_fp_out(mode_fp_aligned)
  );

  wire addsub_valid, normalize_ready;
  wire [P+3:0] sum;
  wire sum_carry, sum_sign;
  wire [  4:0] sum_flags;

  wire [E-1:0] exp_addsub;
  wire round_mode_addsub, mode_fp_addsub;

  fp_addsub addsub (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(align_valid),
      .ready_in(normalize_ready),
      .mant_a_aligned(mant_a_aligned),
      .mant_b_aligned(mant_b_aligned),
      .sign_a(sign_a_aligned),
      .sign_b(sign_b_aligned),
      .is_a_nan(is_a_nan),
      .is_b_nan(is_b_nan),
      .is_a_inf(is_a_inf),
      .is_b_inf(is_b_inf),

      .valid_out(addsub_valid),
      .ready_out(addsub_ready),
      .sum(sum),
      .carry_out(sum_carry),
      .sign_out(sum_sign),
      .flags_out(sum_flags),

      .exp_in(exp_aligned),
      .exp_out(exp_addsub),
      .round_mode_in(round_mode_aligned),
      .round_mode_out(round_mode_addsub),
      .mode_fp_in(mode_fp_aligned),
      .mode_fp_out(mode_fp_addsub)
  );

  wire normalize_valid, round_ready;

  wire [P+3:0] mant_normalized;
  wire [E-1:0] exp_normalized;
  wire [  4:0] flags_normalized;
  wire sign_normalized, round_mode_normalized, mode_fp_normalized;

  fp_normalize normalize (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(addsub_valid),
      .ready_in(round_ready),
      .mant_in(sum),
      .exp_in(exp_addsub),
      .carry(sum_carry),
      .flags_in(sum_flags),

      .ready_out(normalize_ready),
      .valid_out(normalize_valid),
      .mant_out (mant_normalized),
      .exp_out  (exp_normalized),
      .flags_out(flags_normalized),

      .sign_in(sum_sign),
      .sign_out(sign_normalized),
      .round_mode_in(round_mode_addsub),
      .round_mode_out(round_mode_normalized),
      .mode_fp_in(mode_fp_addsub),
      .mode_fp_out(mode_fp_normalized)
  );

  wire round_valid, renormalize_ready;

  wire [P+3:0] mant_rounded;
  wire round_carry;
  wire [4:0] flags_rounded;

  wire [E-1:0] exp_rounded;
  wire sign_rounded, mode_fp_rounded;

  fp_round round (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(normalize_valid),
      .ready_in(renormalize_ready),
      .mant_in(mant_normalized),
      .round_mode(round_mode_normalized),
      .flags_in(flags_normalized),

      .ready_out(round_ready),
      .valid_out(round_valid),
      .mant_rounded(mant_rounded),
      .carry_out(round_carry),
      .flags_out(flags_rounded),

      .exp_in(exp_normalized),
      .exp_out(exp_rounded),
      .sign_in(sign_normalized),
      .sign_out(sign_rounded),
      .mode_fp_in(mode_fp_normalized),
      .mode_fp_out(mode_fp_rounded)
  );

  wire renormalize_valid;

  wire [P+3:0] mant_renormalized;
  wire [E-1:0] exp_renormalized;
  wire [4:0] flags_renormalized;
  wire sign_renormalized, mode_fp_renormalized;

  fp_normalize renormalize (
      .clk  (clk),
      .rst_n(rst_n),

      .valid_in(round_valid),
      .ready_in(ready_in),
      .mant_in(mant_rounded),
      .exp_in(exp_rounded),
      .carry(round_carry),
      .flags_in(flags_rounded),

      .ready_out(renormalize_ready),
      .valid_out(renormalize_valid),
      .mant_out (mant_renormalized),
      .exp_out  (exp_renormalized),
      .flags_out(flags_renormalized),

      .sign_in(sign_rounded),
      .sign_out(sign_renormalized),
      .mode_fp_in(mode_fp_rounded),
      .mode_fp_out(mode_fp_renormalized)
  );

  assign valid_out = renormalize_valid;

  assign sign_out = sign_renormalized;
  assign exp_out = exp_renormalized;
  assign mant_out = mant_renormalized;
  assign flags = flags_renormalized;
  assign mode_fp_out = mode_fp_renormalized;
endmodule

module fp_decoder (
    input wire [2:0] op_code,
    input wire start,
    input wire ready_in,
    output wire adder_start,
    output wire adder_ready_in,
    output wire multiplier_start,
    output wire multiplier_ready_in
);
  assign adder_start = start && (op_code == `OP_ADD || op_code == `OP_SUB);
  assign adder_ready_in = ready_in || (op_code != `OP_ADD && op_code != `OP_SUB);

  assign multiplier_start = start && (op_code == `OP_MUL || op_code == `OP_DIV);
  assign multiplier_ready_in = ready_in || (op_code != `OP_MUL && op_code != `OP_DIV);

endmodule

module fp_unpacker #(
    parameter P_SINGLE = 23,
    parameter E_SINGLE = 8,
    parameter N_SINGLE = P_SINGLE + E_SINGLE + 1,
    parameter P_HALF   = 10,
    parameter E_HALF   = 5,
    parameter N_HALF   = P_HALF + E_HALF + 1
) (
    input wire [N_SINGLE-1:0] op_a,
    input wire [N_SINGLE-1:0] op_b,
    input wire mode_fp,

    output wire sign_a,
    output wire sign_b,
    output wire [E_SINGLE-1:0] exp_a,
    output wire [E_SINGLE-1:0] exp_b,
    output wire [P_SINGLE-1:0] mant_a,
    output wire [P_SINGLE-1:0] mant_b
);
  localparam BIAS_HALF = 2 ** (E_HALF - 1) - 1;
  localparam BIAS_SINGLE = 2 ** (E_SINGLE - 1) - 1;

  wire fp_single = (mode_fp == `FP_SINGLE);

  wire sign_a_half = op_a[N_HALF-1];
  wire sign_b_half = op_b[N_HALF-1];
  wire sign_a_single = op_a[N_SINGLE-1];
  wire sign_b_single = op_b[N_SINGLE-1];

  wire [E_HALF-1:0] exp_a_half = op_a[N_HALF-2:P_HALF];
  wire [E_HALF-1:0] exp_b_half = op_b[N_HALF-2:P_HALF];
  wire [E_SINGLE-1:0] exp_a_single = op_a[N_SINGLE-2:P_SINGLE];
  wire [E_SINGLE-1:0] exp_b_single = op_b[N_SINGLE-2:P_SINGLE];

  wire [P_HALF-1:0] mant_a_half = op_a[P_HALF-1:0];
  wire [P_HALF-1:0] mant_b_half = op_b[P_HALF-1:0];
  wire [P_SINGLE-1:0] mant_a_single = op_a[P_SINGLE-1:0];
  wire [P_SINGLE-1:0] mant_b_single = op_b[P_SINGLE-1:0];

  assign sign_a = fp_single ? sign_a_single : sign_a_half;
  assign sign_b = fp_single ? sign_b_single : sign_b_half;

  assign exp_a  = fp_single
    ? exp_a_single
    : (exp_a_half == 0 ? 0 : (exp_a_half - BIAS_HALF + BIAS_SINGLE));
  assign exp_b  = fp_single
    ? exp_b_single
    : (exp_b_half == 0 ? 0 : (exp_b_half - BIAS_HALF + BIAS_SINGLE));

  assign mant_a = fp_single ? mant_a_single : (mant_a_half << 13);
  assign mant_b = fp_single ? mant_b_single : (mant_b_half << 13);
endmodule

module fp_packer #(
    parameter P_SINGLE = 23,
    parameter E_SINGLE = 8,
    parameter N_SINGLE = P_SINGLE + E_SINGLE + 1,
    parameter P_HALF   = 10,
    parameter E_HALF   = 5,
    parameter N_HALF   = P_HALF + E_HALF + 1
) (
    input wire sign,
    input wire [E_SINGLE-1:0] exp,
    input wire [P_SINGLE+3:0] mant,
    input wire [4:0] flags_in,
    input wire mode_fp,

    output reg [N_SINGLE-1:0] result,
    output reg [4:0] flags_out
);
  localparam BIAS_HALF = 2 ** (E_HALF - 1) - 1;
  localparam BIAS_SINGLE = 2 ** (E_SINGLE - 1) - 1;

  wire [E_HALF-1:0] exp_half = exp - BIAS_SINGLE + BIAS_HALF;
  // round to nearest
  wire [P_HALF-1:0] mant_half = mant[P_SINGLE+2-:P_HALF] + mant[P_SINGLE-P_HALF+2];

  always @(*) begin
    flags_out = flags_in;

    if (mode_fp == `FP_SINGLE) begin
      result = {sign, exp, mant[P_SINGLE+2:3]};
    end else begin
      result = {{(N_SINGLE - N_HALF) {1'b0}}, sign, exp_half, mant_half};

      if (|mant[P_SINGLE-P_HALF-1:0]) begin
        flags_out[`F_INEXACT] = 1'b1;
      end
    end
  end
endmodule


module float_alu #(
    parameter P = 23,
    parameter E = 8,
    parameter N = P + E + 1
) (
    input wire clk,
    input wire rst_n,
    input wire [N-1:0] op_a,
    input wire [N-1:0] op_b,
    input wire [2:0] op_code,
    input wire mode_fp,
    input wire round_mode,
    input wire start,
    input wire ready_in,

    output reg valid_out,
    output reg ready_out,
    output wire [N-1:0] result,
    output wire [4:0] flags
);
  wire [N-1:0] op_a_unpacked, op_b_unpacked;

  fp_unpacker unpacker (
      .op_a(op_a),
      .op_b(op_b),
      .mode_fp(mode_fp),

      .sign_a(op_a_unpacked[N-1]),
      .sign_b(op_b_unpacked[N-1]),
      .exp_a (op_a_unpacked[N-2:P]),
      .exp_b (op_b_unpacked[N-2:P]),
      .mant_a(op_a_unpacked[P-1:0]),
      .mant_b(op_b_unpacked[P-1:0])
  );

  wire adder_start, adder_ready_in;
  wire multiplier_start, multiplier_ready_in;

  fp_decoder decoder (
      .op_code(op_code),
      .start(start),
      .ready_in(ready_in),
      .adder_start(adder_start),
      .adder_ready_in(adder_ready_in),
      .multiplier_start(multiplier_start),
      .multiplier_ready_in(multiplier_ready_in)
  );

  wire adder_valid, adder_ready;
  wire adder_result;
  wire adder_sign;
  wire [E-1:0] adder_exp;
  wire [P+3:0] adder_mant;
  wire [4:0] adder_flags;
  wire adder_mode_fp;

  fp_adder adder (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a_unpacked),
      .op_b(op_b_unpacked),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .sub(op_code[0]),
      .start(adder_start),
      .ready_in(adder_ready_in),

      .valid_out(adder_valid),
      .ready_out(adder_ready),
      .sign_out(adder_sign),
      .exp_out(adder_exp),
      .mant_out(adder_mant),
      .flags(adder_flags),
      .mode_fp_out(adder_mode_fp)
  );

  wire multiplier_valid, multiplier_ready;
  wire multiplier_result;
  wire multiplier_sign;
  wire [E-1:0] multiplier_exp;
  wire [P+3:0] multiplier_mant;
  wire [4:0] multiplier_flags;
  wire multiplier_mode_fp;

  wire [N-1:0] op_b_inv;
  wire [4:0] recip_flags;

  fp_recip recip (
      .in_bits(op_b_unpacked),
      .out_bits(op_b_inv),
      .except_flags(recip_flags)
  );

  fp_multiplier multiplier (
      .clk(clk),
      .rst_n(rst_n),
      .op_a(op_a_unpacked),
      .op_b(op_code == `OP_MUL ? op_b_unpacked : op_b_inv),
      .mode_fp(mode_fp),
      .round_mode(round_mode),
      .initial_flags(op_code == `OP_MUL ? 5'b0 : recip_flags),
      .start(multiplier_start),
      .ready_in(multiplier_ready_in),

      .valid_out(multiplier_valid),
      .ready_out(multiplier_ready),
      .sign_out(multiplier_sign),
      .exp_out(multiplier_exp),
      .mant_out(multiplier_mant),
      .flags(multiplier_flags),
      .mode_fp_out(multiplier_mode_fp)
  );

  reg result_sign;
  reg [E-1:0] result_exp;
  reg [P+3:0] result_mant;
  reg [4:0] result_flags;
  reg result_mode_fp;

  always @(*) begin
    case (op_code)
      `OP_ADD, `OP_SUB: begin
        valid_out = adder_valid;
        ready_out = adder_ready;

        result_sign = adder_sign;
        result_exp = adder_exp;
        result_mant = adder_mant;

        result_flags = adder_flags;
        result_mode_fp = adder_mode_fp;
      end
      `OP_MUL, `OP_DIV: begin
        valid_out = multiplier_valid;
        ready_out = multiplier_ready;

        result_sign = multiplier_sign;
        result_exp = multiplier_exp;
        result_mant = multiplier_mant;

        result_flags = multiplier_flags;
        result_mode_fp = multiplier_mode_fp;
      end
      default: begin
        valid_out = 1'b0;
        ready_out = 1'b0;

        result_sign = 1'b0;
        result_exp = 8'b0;
        result_mant = 27'b0;

        result_flags = 5'b0;
        result_mode_fp = 1'b0;
      end
    endcase
  end

  fp_packer packer (
      .sign(result_sign),
      .exp(result_exp),
      .mant(result_mant),
      .flags_in(result_flags),
      .mode_fp(result_mode_fp),

      .result(result),
      .flags_out(flags)
  );
endmodule
