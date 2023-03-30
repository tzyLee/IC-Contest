module LASER (
input CLK,
input RST,
input [3:0] X,
input [3:0] Y,
output reg [3:0] C1X,
output reg [3:0] C1Y,
output reg [3:0] C2X,
output reg [3:0] C2Y,
output reg DONE);


localparam N_POINTS = 40;
localparam HALF_N_POINTS = 20;

localparam INPUT = 0;
localparam CIC_A = 1;
localparam CIC_B = 2;
localparam OUTPUT = 3;

reg [2:0] state_r, state_w;
reg [3:0] x_r[0:N_POINTS-1], x_w[0:N_POINTS-1];
reg [3:0] y_r[0:N_POINTS-1], y_w[0:N_POINTS-1];
reg [3:0] cx_r, cx_w;
reg [3:0] cy_r, cy_w;

reg counter2_r, counter2_w;

reg prev_covered_r[0:HALF_N_POINTS-1], prev_covered_w[0:HALF_N_POINTS-1];
reg [4:0] prev_covered_count_r, prev_covered_count_w;
wire [5:0] nxt_covered_count;

reg [3:0] max_cx_r[0:1], max_cx_w[0:1]; // A is 0, B is 1
reg [3:0] max_cy_r[0:1], max_cy_w[0:1];
reg max_covered_by_r[0:1][0:N_POINTS-1], max_covered_by_w[0:1][0:N_POINTS-1];
reg [5:0] max_covered_count_r[0:1], max_covered_count_w[0:1];

integer i, j;

wire signed [4:0] diff_y;
reg covered[0:HALF_N_POINTS-1];
reg only_covered[0:HALF_N_POINTS-1];
wire new_best;
wire signed [4:0] cx_diff[1:4], cy_diff[1:4];
wire signed [4:0] cx_sum[1:4], cy_sum[1:4];

reg [3:0] last_cx_r, last_cx_w;
reg [3:0] last_cy_r, last_cy_w;

wire converge;

wire [5:0] count;

assign count = {cy_r[1:0], cx_r};

assign new_best = counter2_r == 1 && (nxt_covered_count >= (state_r == CIC_A ? max_covered_count_r[0] : max_covered_count_r[1]));

assign converge = (max_cx_r[(state_r == CIC_A ? 0 : 1)] == last_cx_r) && (max_cy_r[(state_r == CIC_A ? 0 : 1)] == last_cy_r);

reg [3:0] diffx[0:HALF_N_POINTS-1], diffy[0:HALF_N_POINTS-1];
always @(*) begin
    for (i=0; i<HALF_N_POINTS; i=i+1) begin
        diffx[i] = x_r[{i, counter2_r}] > cx_r ? x_r[{i, counter2_r}] - cx_r : cx_r - x_r[{i, counter2_r}];
        diffy[i] = y_r[{i, counter2_r}] > cy_r ? y_r[{i, counter2_r}] - cy_r : cy_r - y_r[{i, counter2_r}];
        // covered[i] = (diffx[i])*(diffx[i]) + (diffy[i])*(diffy[i]) < 17;
        case(diffx[i])
        0: covered[i] = (diffy[i] == 0) || (diffy[i] == 1) || (diffy[i] == 2) || (diffy[i] == 3) || (diffy[i] == 4);
        1: covered[i] = (diffy[i] == 0) || (diffy[i] == 1) || (diffy[i] == 2) || (diffy[i] == 3);
        2: covered[i] = (diffy[i] == 0) || (diffy[i] == 1) || (diffy[i] == 2) || (diffy[i] == 3);
        3: covered[i] = (diffy[i] == 0) || (diffy[i] == 1) || (diffy[i] == 2);
        4: covered[i] = (diffy[i] == 0);
        default: covered[i] = 0;
        endcase
        // covered[i] = (diffx[i]);
        // covered[i] = (diffx[i]+diffy[i]) < 5 || (((diffx[i]+diffy[i]) < 6) && (diffx[i] == 2 || diffy[i] == 2));
        // covered[i] = (x_r[{i, counter2_r}] == cx_r) && ($signed({1'b0, y_r[{i, counter2_r}]}) <= cy_sum[4]) && ($signed({1'b0, y_r[{i, counter2_r}]}) >= cy_diff[4])
        //            || ($signed({1'b0, x_r[{i, counter2_r}]}) == cx_diff[1] || $signed({1'b0, x_r[{i, counter2_r}]}) == cx_sum[1]) && ($signed({1'b0, y_r[{i, counter2_r}]}) <= cy_sum[3]) && ($signed({1'b0, y_r[{i, counter2_r}]}) >= cy_diff[3])
        //            || ($signed({1'b0, x_r[{i, counter2_r}]}) == cx_diff[2] || $signed({1'b0, x_r[{i, counter2_r}]}) == cx_sum[2]) && ($signed({1'b0, y_r[{i, counter2_r}]}) <= cy_sum[3]) && ($signed({1'b0, y_r[{i, counter2_r}]}) >= cy_diff[3])
        //            || ($signed({1'b0, x_r[{i, counter2_r}]}) == cx_diff[3] || $signed({1'b0, x_r[{i, counter2_r}]}) == cx_sum[3]) && ($signed({1'b0, y_r[{i, counter2_r}]}) <= cy_sum[2]) && ($signed({1'b0, y_r[{i, counter2_r}]}) >= cy_diff[2])
        //            || ($signed({1'b0, x_r[{i, counter2_r}]}) == cx_diff[4] || $signed({1'b0, x_r[{i, counter2_r}]}) == cx_sum[4]) && (cy_r == y_r[{i, counter2_r}]);

    end
end

always @(*) begin
    for (i=0; i<HALF_N_POINTS; i=i+1) begin
        if (state_r == CIC_A) begin
            only_covered[i] = covered[i] && !max_covered_by_r[1][{i, counter2_r}];
        end
        else begin
            only_covered[i] = covered[i] && !max_covered_by_r[0][{i, counter2_r}];
        end
    end
end


always @(*) begin
    for (i=0; i<HALF_N_POINTS; i=i+1) begin
        prev_covered_w[i] = prev_covered_r[i];
    end
    if (state_r == INPUT) begin
        for (i=0; i<HALF_N_POINTS; i=i+1) begin
            prev_covered_w[i] = 0;
        end
    end
    else if (state_r == CIC_A || state_r == CIC_B) begin
        for (i=0; i<HALF_N_POINTS; i=i+1) begin
            prev_covered_w[i] = covered[i];
        end
    end
end
always @(posedge CLK) begin
    for (i=0; i<HALF_N_POINTS; i=i+1) begin
        prev_covered_r[i] <= prev_covered_w[i];
    end
end

always @(*) begin
    DONE = state_r == OUTPUT;
end

always @(*) begin
    counter2_w = counter2_r;
    if (state_r == INPUT || state_r == OUTPUT) begin
        counter2_w = 0;
    end
    else if (state_r == CIC_A || state_r == CIC_B) begin
        counter2_w = counter2_r == 1 ? 0 : 1;
    end
end
always @(posedge CLK) begin
    counter2_r <= counter2_w;
end

always @(*) begin
    prev_covered_count_w = prev_covered_count_r;
    if (state_r == INPUT) begin
        prev_covered_count_w = 0;
    end
    else if (state_r == CIC_A || state_r == CIC_B) begin
        prev_covered_count_w = counter2_r == 1 ? 0 : nxt_covered_count;
    end
end
always @(posedge CLK) begin
    prev_covered_count_r <= prev_covered_count_w;
end

assign nxt_covered_count = (prev_covered_count_r +
    (only_covered[0] + only_covered[1] + only_covered[2] + only_covered[3])) +
    ((only_covered[4] + only_covered[5] + only_covered[6] + only_covered[7]) +
    (only_covered[8] + only_covered[9] + only_covered[10] + only_covered[11]) +
    (only_covered[12] + only_covered[13] + only_covered[14] + only_covered[15]) +
    (only_covered[16] + only_covered[17] + only_covered[18] + only_covered[19]));
always @(*) begin
    C1X = max_cx_r[0];
    C1Y = max_cy_r[0];
    C2X = max_cx_r[1];
    C2Y = max_cy_r[1];
end

always @(*) begin
    // changed_w = cx_r == 15 && cy_r == 15 ? 0 : changed_w || new_best;
    last_cx_w = last_cx_r;
    last_cy_w = last_cy_r;
    if (state_r == INPUT) begin
        last_cx_w = 0;
        last_cy_w = 0;
    end
    if (state_r == CIC_A) begin
        last_cx_w = cx_r == 15 && cy_r == 15 ? max_cx_r[1] : last_cx_r;
        last_cy_w = cx_r == 15 && cy_r == 15 ? max_cy_r[1] : last_cy_r;
    end
    else if (state_r == CIC_B) begin
        last_cx_w = cx_r == 15 && cy_r == 15 ? max_cx_r[0] : last_cx_r;
        last_cy_w = cx_r == 15 && cy_r == 15 ? max_cy_r[0] : last_cy_r;
    end
end
always @(posedge CLK) begin
    last_cx_r <= last_cx_w;
    last_cy_r <= last_cy_w;
end

always @(*) begin // TODO merge this
    for (i=0; i<2; i=i+1) begin
        max_covered_count_w[i] = max_covered_count_r[i];
    end
    if (state_r == INPUT) begin
        for (i=0; i<2; i=i+1) begin
            max_covered_count_w[i] = 0;
        end
    end
    else if (state_r == CIC_A) begin
        max_covered_count_w[0] = new_best ? nxt_covered_count : max_covered_count_r[0];
        max_covered_count_w[1] = cx_r == 15 && cy_r == 15 ? 0 : max_covered_count_r[1];
    end
    else if (state_r == CIC_B) begin
        max_covered_count_w[1] = new_best ? nxt_covered_count : max_covered_count_r[1];
        max_covered_count_w[0] = cx_r == 15 && cy_r == 15 ? 0 : max_covered_count_r[0];
    end
end
always @(posedge CLK) begin
    for (i=0; i<2; i=i+1) begin
        max_covered_count_r[i] <= max_covered_count_w[i];
    end
end

always @(*) begin
    for (i=0; i<2; i=i+1) begin
        max_cx_w[i] = max_cx_r[i];
        max_cy_w[i] = max_cy_r[i];
        for (j=0; j<N_POINTS; j=j+1) begin
            max_covered_by_w[i][j] = max_covered_by_r[i][j];
        end
    end
    if (state_r == INPUT) begin
        for (i=0; i<2; i=i+1) begin
            max_cx_w[i] = 0;
            max_cy_w[i] = 0;
            for (j=0; j<N_POINTS; j=j+1) begin
                max_covered_by_w[i][j] = 0;
            end
        end
    end
    else if (state_r == CIC_A) begin
        max_cx_w[0] = new_best ? cx_r : max_cx_r[0];
        max_cy_w[0] = new_best ? cy_r : max_cy_r[0];
        if (new_best) begin
            for (j=0; j<HALF_N_POINTS; j=j+1) begin
                max_covered_by_w[0][{j, 1'b1}] = covered[j];
                max_covered_by_w[0][{j, 1'b0}] = prev_covered_r[j];
            end
        end
    end
    else if (state_r == CIC_B) begin
        max_cx_w[1] = new_best ? cx_r : max_cx_r[1];
        max_cy_w[1] = new_best ? cy_r : max_cy_r[1];
        if (new_best) begin
            for (j=0; j<HALF_N_POINTS; j=j+1) begin
                max_covered_by_w[1][{j, 1'b1}] = covered[j];
                max_covered_by_w[1][{j, 1'b0}] = prev_covered_r[j];
            end
        end
    end
end
always @(posedge CLK) begin
    for (i=0; i<2; i=i+1) begin
        max_cx_r[i] <= max_cx_w[i];
        max_cy_r[i] <= max_cy_w[i];
        for (j=0; j<N_POINTS; j=j+1) begin
            max_covered_by_r[i][j] <= max_covered_by_w[i][j];
        end
    end
end

always @(*) begin
    cx_w = cx_r;
    cy_w = cy_r;
    if (state_r == INPUT) begin
        if (count == N_POINTS-1) begin
            cx_w = 0;
            cy_w = 0;
        end
        else begin
            cx_w = cx_r + 1;
            cy_w = cx_r == 4'b1111 ? cy_r+1 : cy_r;
        end
    end
    else if (state_r == CIC_A || state_r == CIC_B) begin
        if (counter2_r) begin
            cx_w = (cx_r == 15 ? 1 : cx_r + 1);
            cy_w = (cx_r == 15) ? (cy_r == 15 ? 0 : cy_r + 1) : cy_r;
        end
    end
    else if (state_r == OUTPUT) begin
        cx_w = 0;
        cy_w = 0;
    end
end
always @(posedge CLK) begin
    if (RST) begin
        cx_r <= 0;
        cy_r <= 0;
    end
    else begin
        cx_r <= cx_w;
        cy_r <= cy_w;
    end
end

always @(*) begin
    for (i=0; i<N_POINTS; i=i+1) begin
        x_w[i] = x_r[i];
        y_w[i] = y_r[i];
    end
    if (state_r == INPUT) begin
        x_w[count] = X;
        y_w[count] = Y;
    end
end
always @(posedge CLK) begin
    for (i=0; i<N_POINTS; i=i+1) begin
        x_r[i] <= x_w[i];
        y_r[i] <= y_w[i];
    end
end

always @(*) begin
    case (state_r)
    INPUT:
        state_w = count == N_POINTS-1 ? CIC_A : INPUT;
    CIC_A:
        state_w = cx_r == 15 && cy_r == 15 ?(converge ? OUTPUT : counter2_r ? CIC_B : CIC_A) : CIC_A;
    CIC_B:
        state_w = cx_r == 15 && cy_r == 15 ?(converge ? OUTPUT : counter2_r ? CIC_A : CIC_B) : CIC_B;
    OUTPUT:
        state_w = INPUT;
    default:
        state_w = state_r;
    endcase
end
always @(posedge CLK) begin
    if (RST) begin
        state_r <= INPUT;
    end
    else begin
        state_r <= state_w;
    end
end

endmodule


