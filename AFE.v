`include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_flt2i.v"
`include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_i2flt.v"

module AFE(clk, rst, fn_sel, x, busy, done);
input          clk;  
input          rst;
input  [2:0]   fn_sel;
input  [31:0]  x;
output         busy;
output         done;

localparam INIT = 2'b00;
localparam CALC = 2'b01;
localparam DONE = 2'b10;

localparam PReLU = 3'b000;
localparam ELU = 3'b001;
localparam Sigmoid = 3'b010;
localparam SiLU = 3'b011;
localparam Tanh = 3'b100;

localparam FRAC_WIDTH = 22; // 1bit sign, 3 bit integer => FRAC_WIDTH+4
localparam FIX_WIDTH = FRAC_WIDTH+4;
localparam LN2 = 10'd709; // 10bit fraction;

reg [1:0] state_r, state_w;
reg [1:0] counter_r, counter_w;
reg [31:0] x_r, x_w;
reg [9:0] addr_r, addr_w;
reg overflow_r, overflow_w;
reg overflowed_r, overflowed_w;
reg signed [FIX_WIDTH-1:0] fixed_r, fixed_w;
reg signed [FIX_WIDTH-1:0] fixed2_r, fixed2_w;
reg signed [FIX_WIDTH-1:0] fixed3_r, fixed3_w;
reg signed [FIX_WIDTH-1:0] fixed4_r, fixed4_w;
reg signed [FIX_WIDTH-1:0] fixed5_r, fixed5_w;
reg signed [FIX_WIDTH-1:0] fixed6_r, fixed6_w;
reg signed [FIX_WIDTH-1:0] fixed7_r, fixed7_w;
reg signed [FIX_WIDTH-1:0] fixed8_r, fixed8_w;
wire signed [FIX_WIDTH-1:0] const;

wire signed [FIX_WIDTH-1:0] m1;
wire signed [FIX_WIDTH-1:0] m2;
wire signed [FIX_WIDTH-1:0] m3;
wire signed [FIX_WIDTH-1:0] m4;
wire signed [FIX_WIDTH-1:0] m5;
wire signed [FIX_WIDTH-1:0] m6;
wire signed [FIX_WIDTH-1:0] m7;
wire signed [FIX_WIDTH-1:0] m8;
reg signed [FIX_WIDTH-1:0] m5c;
reg signed [FIX_WIDTH-1:0] m6c;
reg signed [FIX_WIDTH-1:0] m7c;
reg signed [FIX_WIDTH-1:0] m8c;

wire [FIX_WIDTH-1:0] fixed_ln2;
wire [FIX_WIDTH-1:0] fixed;
wire overflow;
wire [9:0] addr_plus_1;
wire sign;
wire [7:0] exponent, exp_minus_3;
wire [22:0] mantissa;

wire [31:0] PReLU_output;
wire [31:0] shifted_fp32;
wire [31:0] recover_fp32;
reg [31:0] output_data;
wire CEN, WEN;

sram1024x32 u_mem(.Q(), .CLK(clk), .CEN(CEN), .WEN(WEN), .A(addr_r), .D(output_data));


DW_fp_flt2i #(.isize(FIX_WIDTH)) u_flt2i(.a(shifted_fp32), .rnd(3'b000), .z(fixed), .status());
DW_fp_i2flt #(.isize(FIX_WIDTH)) u_i2flt(.a(fixed), .rnd(3'b000), .z(recover_fp32), .status());

// TODO
assign m1 = $signed(fixed3_r) * $signed(fixed_r); // $signed(fixed3_r) * $signed(fixed4_r)
assign m2 = $signed(fixed2_r) * $signed(fixed_r); // $signed(fixed2_r) * $signed(fixed4_r)
assign m3 = $signed(fixed_r) * $signed(fixed_r); // $signed(fixed_r) * $signed(fixed4_r)
assign m4 = $signed(fixed4_r) * $signed(fixed4_r);
assign m5 = $signed(m1) * $signed(m5c); // $signed(m1) * $signed()
assign m6 = $signed(m2) * $signed(m6c); // $signed(m2) * $signed()
assign m7 = $signed(m3) * $signed(m7c); // $signed(m3) * $signed()
assign m8 = $signed(fixed_r) * $signed(m8c); // $signed(m4) * $signed()

always @(*) begin
    case(fn_sel)
    PReLU: begin
        m5c = 0;
        m6c = 0;
        m7c = 0;
        m8c = 0;
    end
    ELU: begin
        m5c = 0;
        m6c = 0;
        m7c = 0;
        m8c = 0;
    end
    endcase
end


assign fixed_ln2 = LN2 * $signed(fixed_r);

assign {overflow, addr_plus_1} = addr_r+1;

assign busy = counter_r != 2'b11;
assign {sign, exponent, mantissa} = x_r;
assign exp_minus_3 = exponent-3;
assign shifted_fp32 = {sign, exponent+FRAC_WIDTH, mantissa};

assign PReLU_output = sign ? {sign, exp_minus_3, mantissa} : x_r;

assign CEN = counter_r == 2'b00 ? 1'b0 : 1'b1;
assign WEN = 1'b0;
assign done = state_r == DONE;

always @(*) begin
    case(fn_sel)
    PReLU: output_data = PReLU_output;
    default: output_data = 0;
    endcase
end

always @(*) begin
    case(state_r)
    INIT: state_w = CALC;
    CALC: state_w = overflow_r && overflowed_r && counter_r == 2'b00 ? DONE : CALC;
    default: state_w = state_r;
    endcase
end
always @(posedge clk) begin
    if (rst) begin
        state_r <= INIT;
    end
    else begin
        state_r <= state_w;
    end
end

always @(*) begin
    counter_w = counter_r+1;
end
always @(posedge clk) begin
    if (rst) begin
        counter_r <= 2'b11;
    end
    else begin
        counter_r <= counter_w;
    end
end

always @(*) begin
    x_w = x_r;
    if (counter_r == 2'b00) begin
        x_w = x;
    end
end
always @(posedge clk) begin
    x_r <= x_w;
end

always @(*) begin
    fixed_w = fixed;
end
always @(posedge clk) begin
    fixed_r <= fixed_w;
end

always @(*) begin
    overflow_w = overflow;
end
always @(posedge clk) begin
    overflow_r <= overflow_w;
end

always @(*) begin
    overflowed_w = overflowed_r || (overflow && counter_r == 2'b00);
end
always @(posedge clk) begin
    if (rst) begin
        overflowed_r <= 0;
    end
    else begin
        overflowed_r <= overflowed_w;
    end

end

always @(*) begin
    addr_w = addr_r;
    if (state_r == CALC) begin
        addr_w = counter_r == 2'b00 ? addr_plus_1 : addr_r;
    end

end
always @(posedge clk) begin
    if (rst) begin
        addr_r <= 10'd1023;
    end
    else begin
        addr_r <= addr_w;
    end
end

endmodule
