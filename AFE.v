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

localparam INT_WIDTH = 23;
localparam FRAC_WIDTH = 22; // 1bit sign, 21 bit integer => FRAC_WIDTH+4
localparam FIX_WIDTH = FRAC_WIDTH+INT_WIDTH;
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
reg signed [FIX_WIDTH-1:0] prev_sum_r, prev_sum_w;

wire signed [FIX_WIDTH-1:0] const;
wire signed [FIX_WIDTH+2:0] adder_sum;
wire signed [FIX_WIDTH-1:0] adder_sumt;
wire signed [2*FIX_WIDTH-1:0] m1;
wire signed [2*FIX_WIDTH-1:0] m2;
wire signed [2*FIX_WIDTH-1:0] m3;
wire signed [2*FIX_WIDTH-1:0] m4;
wire signed [2*FIX_WIDTH-1:0] m5;
wire signed [2*FIX_WIDTH-1:0] m6;
wire signed [2*FIX_WIDTH-1:0] m7;
wire signed [2*FIX_WIDTH-1:0] m8;
wire signed [FIX_WIDTH-1:0] m1t, m1a, m1b;
wire signed [FIX_WIDTH-1:0] m2t, m2a, m2b;
wire signed [FIX_WIDTH-1:0] m3t, m3a, m3b;
wire signed [FIX_WIDTH-1:0] m4t;//, m4a, m4b;
wire signed [FIX_WIDTH-1:0] m5t;//, m5a, m5b;
wire signed [FIX_WIDTH-1:0] m6t;//, m6a, m6b;
wire signed [FIX_WIDTH-1:0] m7t;//, m7a, m7b;
wire signed [FIX_WIDTH-1:0] m8t, m8a, m8b;
reg signed [FIX_WIDTH-1:0] m5c;
reg signed [FIX_WIDTH-1:0] m6c;
reg signed [FIX_WIDTH-1:0] m7c;
reg signed [FIX_WIDTH-1:0] m8c;
reg signed [FIX_WIDTH-1:0] c0;

wire [FIX_WIDTH-1:0] fixed_ln2;
wire [FIX_WIDTH-1:0] fixed;
wire overflow;
wire [9:0] addr_plus_1;
wire sign, rsign;
wire [7:0] exponent, rexponent, exp_minus_3, shifted_exp;
wire [22:0] mantissa, rmantissa;

wire [31:0] PReLU_output, ELU_output;
wire [31:0] shifted_fp32;
wire [31:0] recover_fp32;
reg [31:0] output_data;
wire CEN, WEN;

sram1024x32 u_mem(.Q(), .CLK(clk), .CEN(CEN), .WEN(WEN), .A(addr_r), .D(output_data));


DW_fp_flt2i #(.isize(FIX_WIDTH)) u_flt2i(.a(shifted_fp32), .rnd(3'b000), .z(fixed), .status());
DW_fp_i2flt #(.isize(FIX_WIDTH)) u_i2flt(.a(prev_sum_r), .rnd(3'b000), .z(recover_fp32), .status());

assign m1a = (counter_r[0] ? $signed(m2t) : $signed(fixed3_r));
assign m1b = (counter_r[0] ? $signed(fixed) : $signed(fixed4_r));

assign m2a = (counter_r[0] ? $signed(m3t) : $signed(fixed2_r));
assign m2b = (counter_r[0] ? $signed(fixed) : $signed(fixed4_r));
assign m3a = (counter_r[0] ? $signed(fixed) : $signed(fixed_r));
assign m3b = (counter_r[0] ? $signed(fixed) : $signed(fixed4_r));
assign m4 = $signed(fixed4_r) * $signed(fixed4_r);
assign m5 = $signed(fixed4_r) * $signed(m5c);
assign m6 = $signed(fixed3_r) * $signed(m6c);
assign m7 = $signed(fixed2_r) * $signed(m7c);
assign m8a = (counter_r[1] ? $signed(fixed) : $signed(m4t));
assign m8b = $signed(m8c);

assign m1 = $signed(m1a) * $signed(m1b);
assign m2 = $signed(m2a) * $signed(m2b);
assign m3 = $signed(m3a) * $signed(m3b);
assign m8 = $signed(m8a) * $signed(m8b);

assign m1t = m1[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m2t = m2[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m3t = m3[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m4t = m4[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m5t = m5[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m6t = m6[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m7t = m7[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];
assign m8t = m8[2*FRAC_WIDTH+INT_WIDTH-1:FRAC_WIDTH];

assign adder_sum = ($signed(m5t) + $signed(m6t) + $signed(m7t) + $signed(m8t) + (counter_r == 2'b10 ? $signed(c0) : $signed(prev_sum_r)));
assign adder_sumt = adder_sum[FIX_WIDTH-1:0];

//wire signed [FIX_WIDTH+2:0] debug_sum, debug_sum2, debug_sum3, debug_sum4;
//assign debug_sum = $signed(fixed_r) + $signed(fixed2_r);
//assign debug_sum2 = $signed(fixed3_r) + $signed(fixed4_r);
//assign debug_sum3 = $signed(debug_sum) + $signed(debug_sum2);
//assign debug_sum4 = $signed(debug_sum3) + $signed(c0);

always @(*) begin
    case(fn_sel)
    PReLU: begin
        m5c = 0;
        m6c = 0;
        m7c = 0;
        m8c = 0;
    end
    ELU: begin
        m5c = counter_r == 2'b10 ? 45'sd7550 : 0;
        m6c = counter_r == 2'b10 ? 45'sd57462 : 0;
        m7c = counter_r == 2'b10 ? 45'sd229428 : 45'sd419;
        m8c = counter_r == 2'b10 ? 45'sd509608 : 0;
        c0 = -45'sd1678;
    end
    endcase
end

always @(*) begin
    fixed_w = fixed_r;
    fixed2_w = fixed2_r;
    fixed3_w = fixed3_r;
    fixed4_w = fixed4_r;
    
    if (counter_r == 2'b00 && fn_sel == PReLU) begin
        fixed_w = fixed;
        fixed2_w = fixed2_r;
        fixed3_w = fixed3_r;
        fixed4_w = fixed4_r;
    end
    else if (counter_r == 2'b01) begin
        fixed_w = fixed;
        fixed2_w = m3t;
        fixed3_w = m2t;
        fixed4_w = m1t;
    end
    else if (counter_r == 2'b10) begin
        fixed_w = m4t;
        fixed2_w = m3t;
        fixed3_w = m2t;
        fixed4_w = m1t;
        /*
        fixed_w = m8t;
        fixed2_w = m7t;
        fixed3_w = m6t;
        fixed4_w = m5t;
        */
    end

end
always @(posedge clk) begin
    fixed_r <= fixed_w;
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

//assign fixed_ln2 = LN2 * $signed(fixed_r);

assign {overflow, addr_plus_1} = addr_r+1;

assign busy = counter_r != 2'b11;
assign {sign, exponent, mantissa} = x_r;
assign exp_minus_3 = (fn_sel == PReLU ? exponent : rexponent)-3;
assign shifted_exp = exponent+FRAC_WIDTH;
assign shifted_fp32 = {sign, shifted_exp, mantissa};
assign {rsign, rexponent, rmantissa} = recover_fp32;

assign PReLU_output = sign ? {sign, exp_minus_3, mantissa} : x_r;
wire [7:0] exp_adjust;
assign exp_adjust = rexponent-FRAC_WIDTH;
assign ELU_output = rsign ? {rsign, exp_adjust, rmantissa} : x_r;


assign CEN = counter_r == 2'b00 ? 1'b0 : 1'b1;
assign WEN = 1'b0;
assign done = state_r == DONE;

always @(*) begin
    case(fn_sel)
    PReLU: output_data = PReLU_output;
    ELU: output_data = ELU_output;
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
