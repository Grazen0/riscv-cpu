`default_nettype none

module cpu_data_extend (
    input  wire [31:0] data,
    input  wire [ 2:0] control,
    output reg  [31:0] data_ext
);
  always @(*) begin
    case (control)
      3'b000:  data_ext = {{24{data[7]}}, data[7:0]};
      3'b001:  data_ext = {{16{data[15]}}, data[15:0]};
      3'b010:  data_ext = data;
      3'b100:  data_ext = {{24{1'b0}}, data[7:0]};
      3'b101:  data_ext = {{16{1'b0}}, data[15:0]};
      default: data_ext = {32{1'bx}};
    endcase
  end
endmodule
