module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;
reg valid;
reg is_inside;

localparam INPUT = 2'b00;
localparam SORT = 2'b01;
localparam AREA = 2'b10;
localparam N_POINTS = 6;

reg [1:0] state_r, state_w;
reg [2:0] count_r, count_w;
reg [2:0] count2_r, count2_w;

reg [9:0] X_r[0:N_POINTS-1], X_w[0:N_POINTS-1];
reg [9:0] Y_r[0:N_POINTS-1], Y_w[0:N_POINTS-1];
reg [10:0] R_r[0:N_POINTS-1], R_w[0:N_POINTS-1];

reg signed [10:0] dX_r[0:N_POINTS-1], dX_w[0:N_POINTS-1];
reg signed [10:0] dY_r[0:N_POINTS-1], dY_w[0:N_POINTS-1];

reg [25:0] total_area_r, total_area_w;
reg [25:0] in_area_r, in_area_w;
reg [9:0] c_r, c_w; // 3rd side
wire [25:0] area_half;
wire signed [10:0] a; // 1st side
wire signed [10:0] b; // 2nd side
wire signed [11:0] s_abc;
wire signed [10:0] s; // (a+b+c)/2
wire signed [10:0] sma; // s-a
wire signed [10:0] smb; // s-b
wire signed [10:0] smc; // s-c

wire signed [22:0] part_area;
wire signed [21:0] mult1, mult2;
wire signed [19:0] ssma, smbsmc;
wire [9:0] sq_ssma, sq_smbsmc;
wire [19:0] trig_area;

wire counter_clock;

wire signed [11:0] dXside;
wire signed [11:0] dYside;
wire signed [19:0] dXsideSquare, dYsideSquare, sideSquareSum;

wire finished;

integer i;

assign finished = state_r == AREA && count2_r == N_POINTS+1;

assign area_half = total_area_r[25:1];
assign mult1 = $signed(dX_r[count2_r])*$signed(dY_r[count2_r+1]);
assign mult2 = $signed(dX_r[count2_r+1])*$signed(dY_r[count2_r]);
assign part_area = mult1 - mult2;
assign counter_clock = mult1 < mult2;

assign dXside = (X_r[count2_r] - (count2_r < N_POINTS-1 ? X_r[count2_r+1] : X_r[0]));
assign dYside = (Y_r[count2_r] - (count2_r < N_POINTS-1 ? Y_r[count2_r+1] : Y_r[0]));
assign dXsideSquare = $signed(dXside) * $signed(dXside);
assign dYsideSquare = $signed(dYside) * $signed(dYside);
assign sideSquareSum = dXsideSquare + dYsideSquare;

assign a = R_r[count2_r-1];
assign b = count2_r < N_POINTS ? R_r[count2_r] : R_r[0];
assign s_abc = (a+b+c_r);
assign s = s_abc[11:1];
assign sma = s-a;
assign smb = s-b;
assign smc = s-c_r;
assign ssma = s*sma;
assign smbsmc = smb*smc;
assign trig_area = sq_ssma * sq_smbsmc;

DW_sqrt #(.width(20)) sqrt1(.a(sideSquareSum), .root(c_w));
DW_sqrt #(.width(20)) sqrt2(.a(ssma), .root(sq_ssma));
DW_sqrt #(.width(20)) sqrt3(.a(smbsmc), .root(sq_smbsmc));


always @(*) begin
    valid = finished;
    is_inside = in_area_r <= area_half;
end



always @(posedge clk) begin
    c_r <= c_w;
end

always @(*) begin
    if (state_r == INPUT) begin
        count_w = reset ? 0 :
                  count_r == N_POINTS ? 0 : count_r+1;
    end
    else if (state_r == SORT) begin
        count_w = count_r+count2_r == N_POINTS-2 ? count_r+1 : count_r;
    end
    else if (state_r == AREA) begin
        count_w = 0;
    end
    else begin
        count_w = count_r + 1;
    end
end
always @(posedge clk) begin
    count_r <= count_w;
end

always @(*) begin
    if (state_r == INPUT) begin
        count2_w = 0;
    end
    else if (state_r == SORT) begin
        count2_w = count_r+count2_r == N_POINTS-2 ? 0 : count2_r+1;
    end
    else if (state_r == AREA) begin
        count2_w = count2_r + 1;
    end
    else begin
        count2_w = count2_r + 1;
    end
end
always @(posedge clk) begin
    count2_r <= count2_w;
end

always @(*) begin
    if (state_r == INPUT) begin
        in_area_w = 0;
    end
    else if (state_r == AREA && count2_r > 0) begin
        in_area_w = in_area_r + trig_area;
    end
    else begin
        in_area_w = in_area_r;
    end
end
always @(posedge clk) begin
    in_area_r <= in_area_w;
end
always @(*) begin
    if (state_r == INPUT) begin
        total_area_w = 0;
    end
    else if (state_r == AREA && count2_r < N_POINTS-1) begin
        total_area_w = total_area_r + part_area;
    end
    else begin
        total_area_w = total_area_r;
    end
end
always @(posedge clk) begin
    total_area_r <= total_area_w;
end

always @(*) begin
    for (i = 0; i < N_POINTS; i=i+1) begin
        X_w[i] = X_r[i];
        Y_w[i] = Y_r[i];
        R_w[i] = R_r[i];
    end
    if (state_r == INPUT) begin
        X_w[count_r] = X;
        Y_w[count_r] = Y;
        R_w[count_r] = R;
    end
    else if (state_r == SORT) begin
        if (counter_clock) begin
            X_w[count2_r+1] = X_r[count2_r];
            Y_w[count2_r+1] = Y_r[count2_r];
            R_w[count2_r+1] = R_r[count2_r];
            X_w[count2_r] = X_r[count2_r+1];
            Y_w[count2_r] = Y_r[count2_r+1];
            R_w[count2_r] = R_r[count2_r+1];
        end
    end
end
always @(posedge clk) begin
    for (i = 0; i < N_POINTS; i=i+1) begin
        X_r[i] <= X_w[i];
        Y_r[i] <= Y_w[i];
        R_r[i] <= R_w[i];
    end
end

always @(*) begin
    for (i = 0; i < N_POINTS; i=i+1) begin
        dX_w[i] = dX_r[i];
        dY_w[i] = dY_r[i];
    end
    if (state_r == INPUT && count_r < N_POINTS) begin
        dX_w[count_r] = count_r == 0 ? 0 : X - X_r[0];
        dY_w[count_r] = count_r == 0 ? 0 : Y - Y_r[0];
    end
    else if (state_r == SORT) begin
        if (counter_clock) begin
            dX_w[count2_r+1] = dX_r[count2_r];
            dY_w[count2_r+1] = dY_r[count2_r];
            dX_w[count2_r] = dX_r[count2_r+1];
            dY_w[count2_r] = dY_r[count2_r+1];
        end
    end
end
always @(posedge clk) begin
    for (i = 0; i < N_POINTS; i=i+1) begin
        dX_r[i] <= dX_w[i];
        dY_r[i] <= dY_w[i];
    end
end


always @(*) begin
    case (state_r)
    INPUT:
        state_w = count_r == 6 ? SORT : INPUT;
    SORT:
        state_w = count_r == 4 ? AREA : SORT;
    AREA:
        state_w = finished ? INPUT : AREA;
    default:
        state_w = state_r;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state_r <= INPUT;
    end
    else begin
        state_r <= state_w;
    end
end

endmodule

