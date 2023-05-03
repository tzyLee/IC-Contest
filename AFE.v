
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

reg [1:0] state_r, state_w;
reg counter_r, counter_w;
reg [31:0] x_r, x_w;
reg [9:0] addr_r, addr_w;
reg overflow_r, overflow_w;

wire overflow;
wire [9:0] addr_plus_1;
wire sign;
wire [7:0] exponent, exp_minus_3;
wire [22:0] mantissa;

wire [31:0] PReLU_output;
reg [31:0] output_data;
wire CEN, WEN;

sram1024x32 u_mem(.Q(), .CLK(clk), .CEN(CEN), .WEN(WEN), .A(addr_r), .D(output_data));

assign {overflow, addr_plus_1} = addr_r+1;

assign busy = counter_r;
assign {sign, exponent, mantissa} = x_r;
assign exp_minus_3 = exponent-3;

assign PReLU_output = sign ? {sign, exp_minus_3, mantissa} : x_r;

assign CEN = counter_r;
assign WEN = counter_r;
assign done = state_r == DONE;

always @(*) begin
    case(fn_sel)
    3'b0: output_data = PReLU_output;
    default: output_data = 0;
    endcase
end

always @(*) begin
    case(state_r)
    INIT: state_w = CALC;
    CALC: state_w = overflow_r ? DONE : CALC;
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
        counter_r <= 0;
    end
    else begin
        counter_r <= counter_w;
    end
end

always @(*) begin
    x_w = x;
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
    addr_w = addr_r;
    if (state_r == CALC) begin
        addr_w = counter_r ? addr_r : addr_plus_1;
    end

end
always @(posedge clk) begin
    if (rst) begin
        addr_r <= 0;
    end
    else begin
        addr_r <= addr_w;
    end
end

endmodule
