// `include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_flt2i.v"
// `include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_i2flt.v"
// `include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_flt2i.v"
// `include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_i2flt.v"


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

// Bit-width of initial fixed point `x`
localparam X_INT_WIDTH = 4;
localparam X_FRAC_WIDTH = 28; // without SiLU, this can be 24 (|x| >= 4 can be handled exclusively)
localparam X_FIX_WIDTH = X_FRAC_WIDTH+X_INT_WIDTH;

// Multiplier (A*B) bitwidth
localparam MULT_INT_WIDTH = X_INT_WIDTH+18;
localparam MULT_FRAC_WIDTH = X_FRAC_WIDTH+2;
localparam MULT_FIX_WIDTH = MULT_INT_WIDTH+MULT_FRAC_WIDTH;

// Truncation
localparam TERM_FRAC_WIDTH = X_FRAC_WIDTH-10;
localparam TERM_INT_WIDTH = X_FIX_WIDTH-2-TERM_FRAC_WIDTH;
localparam TERM_FIX_WIDTH = TERM_INT_WIDTH+TERM_FRAC_WIDTH;

// Result bitwidth
localparam MULT_RES_INT_WIDTH = MULT_INT_WIDTH+MULT_INT_WIDTH;
localparam MULT_RES_FRAC_WIDTH = MULT_FRAC_WIDTH+MULT_FRAC_WIDTH;
localparam MULT_RES_FIX_WIDTH = MULT_RES_INT_WIDTH+MULT_RES_FRAC_WIDTH;

localparam SUM_RES_INT_WIDTH = TERM_INT_WIDTH+4;
localparam SUM_RES_FRAC_WIDTH = TERM_FRAC_WIDTH;
localparam SUM_RES_FIX_WIDTH = SUM_RES_INT_WIDTH+SUM_RES_FRAC_WIDTH;

localparam MULT9_RES_INT_WIDTH = TERM_INT_WIDTH+X_INT_WIDTH;
localparam MULT9_RES_FRAC_WIDTH = TERM_FRAC_WIDTH+X_FRAC_WIDTH;
localparam MULT9_RES_FIX_WIDTH = MULT9_RES_INT_WIDTH+MULT9_RES_FRAC_WIDTH;

// Controls
reg [31:0] x_r, x_w;
reg [1:0] state_r, state_w;
reg [1:0] counter_r, counter_w;
wire overflow;
reg overflow_r, overflow_w;
reg overflowed_r, overflowed_w;

// SRAM
reg [9:0] addr_r, addr_w;
wire [9:0] addr_plus_1;
wire CEN, WEN;
reg [31:0] output_data;

// Stores x, x^2, x^3, x^4
//     or x^5, x^6, x^7, x^8
reg signed [MULT_FIX_WIDTH-1:0] fixed1_r, fixed1_w;
reg signed [MULT_FIX_WIDTH-1:0] fixed2_r, fixed2_w;
reg signed [MULT_FIX_WIDTH-1:0] fixed3_r, fixed3_w;
reg signed [MULT_FIX_WIDTH-1:0] fixed4_r, fixed4_w;
wire signed [MULT_FIX_WIDTH-1:0] fixed_padded;

// Stores \sum_{i} c{i}x^{i}
reg signed [TERM_FIX_WIDTH-1:0] prev_sum_r, prev_sum_w;
wire signed [SUM_RES_FIX_WIDTH-1:0] adder_sum;
wire signed [TERM_FIX_WIDTH-1:0] adder_sumt;

// fp <-> fixed
reg signed [TERM_FIX_WIDTH-1:0] to_convert;
reg signed [X_FIX_WIDTH-1:0] fixed_r, fixed_w;
wire [X_FIX_WIDTH-1:0] fixed;
reg [31:0] shifted_fp32;
wire [31:0] recover_fp32;

wire [7:0] exp_adjust;
wire sign, rsign, unbuf_sign;
wire [7:0] exponent, rexponent, exp_minus_3, shifted_exp, unbuf_exponent;
wire [22:0] mantissa, rmantissa, unbuf_mantissa;

// Multiplier outputs
wire signed [MULT_RES_FIX_WIDTH-1:0] m1, m2, m3, m4;
wire signed [MULT_RES_FIX_WIDTH-1:0] m5, m6, m7, m8;
wire signed [MULT9_RES_FIX_WIDTH-1:0] m9; // m9 for SiLU = x * sigmoid(x)

// Multiplier inputs
wire signed [MULT_FIX_WIDTH-1:0] m1a, m2a, m3a, m8a;
wire signed [MULT_FIX_WIDTH-1:0] m1b, m2b, m3b;

// Multiplier outputs (truncated)
wire signed [MULT_FIX_WIDTH-1:0] m1t, m2t, m3t, m4t, m5t, m6t, m7t, m8t;
wire signed [TERM_FIX_WIDTH-1:0] m1tc, m2tc, m3tc, m4tc, m5tc, m6tc, m7tc, m8tc;
wire signed [TERM_FIX_WIDTH-1:0] m9t;

// Polynomial constants
reg signed [MULT_FIX_WIDTH-1:0] m5c, m6c, m7c, m8c;
reg signed [TERM_FIX_WIDTH-1:0] c0;

wire [31:0] PReLU_output, ELU_output, Sigmoid_output, SiLU_output, Tanh_output;


sram1024x32 u_mem(.Q(), .CLK(clk), .CEN(CEN), .WEN(WEN), .A(addr_r), .D(output_data));

// 4-cycle design (2-mult + fp2fi critical path)
// 01 | x^2 = x*x, x^3 = x*x^2, x^4 = x^2*x^2
// 10 | x^5 = x^4*x, x^6 = x^4*x^2, x^7 = x^4*x^3, x^8 = x^4*x^4, (c1*x + c2*x^2 + c3*x^3 + c4*x^4)
// 11 | c5*x^5 + c6*x^6 + c7*x^7 + c8*x^8
// 00 | receive new data, output to SRAM (+ x*sigmoid(x) for SiLU)

assign fixed_padded = $signed({{(MULT_INT_WIDTH-X_INT_WIDTH){fixed_r[X_FIX_WIDTH-1]}}, fixed_r, {(MULT_FRAC_WIDTH-X_FRAC_WIDTH){1'b0}}});
assign m1a = (counter_r[0] ? $signed(m2t) : $signed(fixed3_r));
assign m1b = (counter_r[0] ? $signed(fixed_padded) : $signed(fixed4_r));

assign m2a = (counter_r[0] ? $signed(m3t) : $signed(fixed2_r));
assign m2b = (counter_r[0] ? $signed(fixed_padded) : $signed(fixed4_r));
assign m3a = (counter_r[0] ? $signed(fixed_padded) : $signed(fixed1_r));
assign m3b = (counter_r[0] ? $signed(fixed_padded) : $signed(fixed4_r));
assign m8a = (counter_r[0] ? $signed(fixed1_r) : $signed(fixed_padded));

assign m1 = $signed(m1a) * $signed(m1b);
assign m2 = $signed(m2a) * $signed(m2b);
assign m3 = $signed(m3a) * $signed(m3b);
assign m4 = $signed(fixed4_r) * $signed(fixed4_r);
assign m5 = $signed(fixed4_r) * $signed(m5c);
assign m6 = $signed(fixed3_r) * $signed(m6c);
assign m7 = $signed(fixed2_r) * $signed(m7c);
assign m8 = $signed(m8a) * $signed(m8c);

assign m9 = $signed(prev_sum_r) * $signed(fixed_r);

// Before constant scaling
assign m1t = m1[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m2t = m2[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m3t = m3[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m4t = m4[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m5t = m5[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m6t = m6[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m7t = m7[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m8t = m8[2*MULT_FRAC_WIDTH+MULT_INT_WIDTH-1:MULT_FRAC_WIDTH];
assign m9t = m9[MULT9_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT9_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
// After constant scaling
assign m1tc = m1[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m2tc = m2[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m3tc = m3[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m4tc = m4[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m5tc = m5[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m6tc = m6[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m7tc = m7[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];
assign m8tc = m8[MULT_RES_FRAC_WIDTH+TERM_INT_WIDTH-1:MULT_RES_FRAC_WIDTH-TERM_FRAC_WIDTH];

assign adder_sum = (
    $signed(m5tc) + $signed(m6tc) + $signed(m7tc) + $signed(m8tc) +
    (counter_r == 2'b10 ? $signed(c0) : $signed(prev_sum_r))
);
assign adder_sumt = adder_sum[TERM_FIX_WIDTH-1:0];

// Polynomial coef.
// variable `ep` in MATLAB program (epp, eps for sigmoid)
// c0's bitwidth is different, use variable `ec`
// Tips: use 100 bit to change bitwidth faster
always @(*) begin
    case(fn_sel)
    PReLU: begin
        m5c = 0;
        m6c = 0;
        m7c = 0;
        m8c = 0;
        c0 = 0;
    end
    ELU: begin
        m5c = counter_r == 2'b10 ? 100'sd1933772 : 0;
        m6c = counter_r == 2'b10 ? 100'sd14659262 : 0;
        m7c = counter_r == 2'b10 ? 100'sd58733260 : 100'sd103968;
        m8c = counter_r == 2'b10 ? 100'sd130419856 : 0;
        c0 = -100'sd103;
    end
    Sigmoid, SiLU: begin
        m5c = counter_r == 2'b10 ? -100'sd13029075 : -100'sd3205;
        m6c = counter_r == 2'b10 ? -100'sd41075636: -100'sd129840;
        m7c = counter_r == 2'b10 ? -100'sd12987086 : -100'sd1889816;
        m8c = counter_r == 2'b10 ? 100'sd264685936 : 0;
        c0 = sign ? 100'sd131005 : -100'sd131139;
    end
    Tanh: begin
        m5c = counter_r == 2'b10 ? -100'sd414683680 : -100'sd2307650;
        m6c = counter_r == 2'b10 ? -100'sd619167488 : -100'sd24303016;
        m7c = counter_r == 2'b10 ? -100'sd62268568 : -100'sd135169440;
        m8c = counter_r == 2'b10 ? 100'sd1073428416 : -100'sd90435;
        c0 = 100'sd152;
    end
    default: begin
        m5c = 0;
        m6c = 0;
        m7c = 0;
        m8c = 0;
        c0 = 0;
    end
    endcase
end

always @(*) begin
    fixed1_w = fixed1_r;
    fixed2_w = fixed2_r;
    fixed3_w = fixed3_r;
    fixed4_w = fixed4_r;

    if (counter_r == 2'b00 && fn_sel == PReLU) begin
        fixed1_w = fixed_padded;
        fixed2_w = fixed2_r;
        fixed3_w = fixed3_r;
        fixed4_w = fixed4_r;
    end
    else if (counter_r == 2'b01) begin
        fixed1_w = fixed_padded;
        fixed2_w = m3t;
        fixed3_w = m2t;
        fixed4_w = m1t;
    end
    else if (counter_r == 2'b10) begin
        fixed1_w = m4t;
        fixed2_w = m3t;
        fixed3_w = m2t;
        fixed4_w = m1t;
    end
end
always @(posedge clk) begin
    fixed1_r <= fixed1_w;
    fixed2_r <= fixed2_w;
    fixed3_r <= fixed3_w;
    fixed4_r <= fixed4_w;
end
always @(*) begin
    if (counter_r == 2'b01) begin
        prev_sum_w = 0;
    end
    else begin
        prev_sum_w = adder_sumt;
    end
end
always @(posedge clk) begin
    prev_sum_r <= prev_sum_w;
end

// fp -> fixed
DW_fp_flt2i #(.isize(X_FIX_WIDTH)) u_flt2i(.a(shifted_fp32), .rnd(3'b000), .z(fixed), .status());
assign {sign, exponent, mantissa} = x_r;
assign {unbuf_sign, unbuf_exponent, unbuf_mantissa} = x;
assign shifted_exp = unbuf_exponent+X_FRAC_WIDTH;

always @(*) begin
    case(fn_sel)
    Sigmoid, SiLU, Tanh: shifted_fp32 = {1'b1, shifted_exp, unbuf_mantissa};
    default: shifted_fp32 = {unbuf_sign, shifted_exp, unbuf_mantissa};
    endcase
end

always @(*) begin
    fixed_w = fixed_r;
    if (counter_r == 2'b00) begin
        fixed_w = fixed;
    end
end
always @(posedge clk) begin
    fixed_r <= fixed_w;
end


// Output logic (fixed -> fp)
always @(*) begin
    to_convert = prev_sum_r;
    if (fn_sel == SiLU) begin
        to_convert = m9t;
    end
end

DW_fp_i2flt #(.isize(TERM_FIX_WIDTH)) u_i2flt(.a(to_convert), .rnd(3'b000), .z(recover_fp32), .status());

assign {rsign, rexponent, rmantissa} = recover_fp32;
assign exp_minus_3 = (fn_sel == PReLU ? exponent : rexponent)-3;

assign exp_adjust = rexponent-TERM_FRAC_WIDTH;
assign PReLU_output = sign ? {sign, exp_minus_3, mantissa} : x_r;
assign ELU_output = rsign ? {rsign, exp_adjust, rmantissa} : x_r;
// Odd functions need sign flipping
assign Sigmoid_output = sign ? {rsign, exp_adjust, rmantissa} : {~rsign, exp_adjust, rmantissa};
assign SiLU_output = {rsign, exp_adjust, rmantissa};
assign Tanh_output = sign ? {rsign, exp_adjust, rmantissa} : {~rsign, exp_adjust, rmantissa};

always @(*) begin
    case(fn_sel)
    PReLU: output_data = PReLU_output;
    ELU: output_data = ELU_output;
    Sigmoid: output_data = Sigmoid_output;
    SiLU: output_data = SiLU_output;
    Tanh: output_data = Tanh_output;
    default: output_data = 0;
    endcase
end

// Control logic
assign CEN = counter_r == 2'b00 ? 1'b0 : 1'b1;
assign WEN = 1'b0;
assign done = state_r == DONE;
assign busy = counter_r != 2'b11;
assign {overflow, addr_plus_1} = addr_r+1;

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

// DONE after 1023 -> 0 twice
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
