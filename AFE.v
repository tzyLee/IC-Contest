// `include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_flt2i.v"
// `include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_i2flt.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_ifp_fp_conv.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_ifp_conv.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_ifp_addsub.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_sum4.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_mult.v"


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
// reg [31:0] x_r, x_w;
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

reg ori_sign_r, ori_sign_w;
reg [31:0] pow_x_r[1:8], pow_x_w[1:8];
reg [31:0] flipped_x;
wire [31:0] mult_a[0:5], mult_b[0:5], mult_z[0:5];
reg [31:0] c[0:8];
wire [31:0] add4a, add4b, add4c, add4d, add4z, final_result;

// Stores \sum_{i} c{i}x^{i}
// reg signed [TERM_FIX_WIDTH-1:0] prev_sum_r, prev_sum_w;
reg [31:0] prev_sum_r, prev_sum_w;
wire signed [SUM_RES_FIX_WIDTH-1:0] adder_sum;
wire signed [TERM_FIX_WIDTH-1:0] adder_sumt;

// fp <-> fixed
reg signed [TERM_FIX_WIDTH-1:0] to_convert;
reg signed [X_FIX_WIDTH-1:0] fixed_r, fixed_w;
wire [X_FIX_WIDTH-1:0] fixed;
reg [31:0] shifted_fp32;
wire [31:0] recover_fp32;

wire [7:0] exp_adjust;
wire sign, rsign, unbuf_sign, s_sign;
wire [7:0] exponent, rexponent, exp_minus_3, shifted_exp, unbuf_exponent, s_exponent;
wire [22:0] mantissa, rmantissa, unbuf_mantissa, s_mantissa;

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

integer i;

sram1024x32 u_mem(.Q(), .CLK(clk), .CEN(CEN), .WEN(WEN), .A(addr_r), .D(output_data));

DW_fp_mult u_m1(.a(mult_a[0]), .b(mult_b[0]), .rnd(3'b000), .z(mult_z[0]), .status());
DW_fp_mult u_m2(.a(mult_a[1]), .b(mult_b[1]), .rnd(3'b000), .z(mult_z[1]), .status());
DW_fp_mult u_m3(.a(mult_a[2]), .b(mult_b[2]), .rnd(3'b000), .z(mult_z[2]), .status());
DW_fp_mult u_m4(.a(mult_a[3]), .b(mult_b[3]), .rnd(3'b000), .z(mult_z[3]), .status());
DW_fp_mult u_m5(.a(mult_a[4]), .b(mult_b[4]), .rnd(3'b000), .z(mult_z[4]), .status());
DW_fp_mult u_m6(.a(mult_a[5]), .b(mult_b[5]), .rnd(3'b000), .z(mult_z[5]), .status());

assign mult_a[0] = counter_r == 2'b00 ? flipped_x : (counter_r == 2'b11 ? c[7] : pow_x_r[1]);
assign mult_b[0] = counter_r == 2'b00 ? flipped_x :
                   counter_r == 2'b01 ? pow_x_r[2] :
                   counter_r == 2'b10 ? pow_x_r[4] :
                                        pow_x_r[7];
assign mult_a[1] = counter_r == 2'b00 ? pow_x_r[1] : pow_x_r[2];
assign mult_b[1] = counter_r == 2'b00 ? prev_sum_r :
                   counter_r == 2'b01 ? pow_x_r[2] : pow_x_r[4];
assign mult_a[2] = counter_r == 2'b00 ? c[8] : pow_x_r[3];
assign mult_b[2] = counter_r == 2'b00 ? pow_x_r[8] : pow_x_r[4];
assign mult_a[3] = pow_x_r[4];
assign mult_b[3] = pow_x_r[4];

assign mult_a[4] = counter_r == 2'b00 ? 32'b0 :
                   counter_r == 2'b01 ? c[1] :
                   counter_r == 2'b10 ? c[3] : c[5];
assign mult_b[4] = counter_r == 2'b00 ? 32'b0 :
                   counter_r == 2'b01 ? pow_x_r[1] :
                   counter_r == 2'b10 ? pow_x_r[3] : pow_x_r[5];
assign mult_a[5] = counter_r == 2'b00 ? 32'b0 :
                   counter_r == 2'b01 ? c[2] :
                   counter_r == 2'b10 ? c[4] : c[6];
assign mult_b[5] = counter_r == 2'b00 ? 32'b0 :
                   counter_r == 2'b01 ? pow_x_r[2] :
                   counter_r == 2'b10 ? pow_x_r[4] : pow_x_r[6];

assign final_result = mult_z[1]; // @ counter_r == 2'b00

DW_fp_sum4 u_st1(.a(prev_sum_r), .b(add4b), .c(add4c), .d(add4d), .rnd(3'b000), .z(add4z), .status());

assign add4b = counter_r == 2'b00 ? mult_z[2] : mult_z[4];
assign add4c = counter_r == 2'b00 ? 32'b0 : mult_z[5];
assign add4d = counter_r == 2'b01 ? c[0] :
               (counter_r == 2'b10 || counter_r == 2'b00) ? 32'b0 :
                                    mult_z[0];

always @(*) begin
    case(fn_sel)
    Sigmoid, SiLU, Tanh: flipped_x = {1'b1, x[30:0]};
    default: flipped_x = x;
    endcase
end

always @(*) begin
    for (i=1;i<=8;i=i+1) begin
        pow_x_w[i] = pow_x_r[i];
    end
    if (counter_r == 2'b00) begin
        pow_x_w[1] = flipped_x;
        pow_x_w[2] = mult_z[0];
    end
    else if (counter_r == 2'b01) begin
        pow_x_w[3] = mult_z[0];
        pow_x_w[4] = mult_z[1];
    end
    else if (counter_r == 2'b10) begin
        pow_x_w[5] = mult_z[0];
        pow_x_w[6] = mult_z[1];
        pow_x_w[7] = mult_z[2];
        pow_x_w[8] = mult_z[3];
    end
end
always @(posedge clk) begin
    for (i=1;i<=8;i=i+1) begin
        pow_x_r[i] <= pow_x_w[i];
    end
end


always @(*) begin
    ori_sign_w = ori_sign_r;
    if (counter_r == 2'b00) begin
        ori_sign_w = x[31];
    end
end
always @(posedge clk) begin
    ori_sign_r <= ori_sign_w;
end

// assign adder_sum = (
//     $signed(m5tc) + $signed(m6tc) + $signed(m7tc) + $signed(m8tc) +
//     (counter_r == 2'b10 ? $signed(c0) : $signed(prev_sum_r))
// );
// assign adder_sumt = adder_sum[TERM_FIX_WIDTH-1:0];

always @(*) begin
    case(fn_sel)
    PReLU: begin
        c[0] = 0;
        c[1] = 0;
        c[2] = 0;
        c[3] = 0;
        c[4] = 0;
        c[5] = 0;
        c[6] = 0;
        c[7] = 0;
        c[8] = 0;
    end
    ELU: begin
        c[0] = 32'hb9cee82f;
        c[1] = 32'h3df8c192;
        c[2] = 32'h3d600cb3;
        c[3] = 32'h3c5faebe;
        c[4] = 32'h3aec0e5d;
        c[5] = 32'h38cb0fd9;
        c[6] = 0;
        c[7] = 0;
        c[8] = 0;
    end
    Sigmoid, SiLU: begin
        c[0] = ori_sign_r ? 32'h3effdea5 : 32'hbf0010ae;
        c[1] = 32'h3e7c6c97;
        c[2] = 32'hbc462ace;
        c[3] = 32'hbd1cb0ed;
        c[4] = 32'hbc46ced3;
        c[5] = 32'hbae6b0bd;
        c[6] = 32'hb8fd97f9;
        c[7] = 32'hb6485746;
        c[8] = 0;
    end
    Tanh: begin
        c[0] = 32'h3a181730;
        c[1] = 32'h3f7fecdf;
        c[2] = 32'hbd6d8926;
        c[3] = 32'hbf139efc;
        c[4] = 32'hbec5bc91;
        c[5] = 32'hbe00e85a;
        c[6] = 32'hbcb96ad4;
        c[7] = 32'hbb0cd90a;
        c[8] = 32'hb8b0a1b0;
    end
    default: begin
        c[0] = 0;
        c[1] = 0;
        c[2] = 0;
        c[3] = 0;
        c[4] = 0;
        c[5] = 0;
        c[6] = 0;
        c[7] = 0;
        c[8] = 0;
    end
    endcase
end

always @(*) begin
    if (counter_r == 2'b00) begin
        prev_sum_w = 0;
    end
    else begin
        prev_sum_w = add4z;
    end
end
always @(posedge clk) begin
    prev_sum_r <= prev_sum_w;
end

assign {s_sign, s_exponent, s_mantissa} = pow_x_r[1];
assign exp_minus_3 = s_exponent-3;
assign PReLU_output = ori_sign_r ? {s_sign, exp_minus_3, s_mantissa} : pow_x_r[1];
assign ELU_output = ori_sign_r ? prev_sum_r : pow_x_r[1];
// Odd functions need sign flipping
assign Sigmoid_output = ori_sign_r ? prev_sum_r : {~prev_sum_r[31], prev_sum_r[30:0]};
assign SiLU_output = final_result;
assign Tanh_output = ori_sign_r ? add4z : {~add4z[31], add4z[30:0]};

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
