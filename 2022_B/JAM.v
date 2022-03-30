module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );

localparam SEQ = 0;
localparam LOAD = 1;

reg state_r, state_w;

reg [9:0] cost_sum_r, cost_sum_w;

reg [2:0] seq_r [0:7], seq_w [0:7];
reg swapping_r, swapping_w;

reg prev_is_swap_r [0:6], prev_is_swap_w [0:6];

reg [9:0] min_cost_r, min_cost_w;
reg [3:0] match_count_r, match_count_w;

wire left_gt_right [0:6];
wire rfold [0:6];
wire is_swap [0:6];
wire [2:0] swap_num;

reg [2:0] counter_r, counter_w;
reg is_final_r, is_final_w;
reg prev_is_final_r, prev_is_final_w;

wire [2:0] min_gt_swap;
wire is_min_gt_swap [1:7];

wire [9:0] new_cost;
integer i;

assign left_gt_right[0] = seq_r[0] > seq_r[1];
assign left_gt_right[1] = seq_r[1] > seq_r[2];
assign left_gt_right[2] = seq_r[2] > seq_r[3];
assign left_gt_right[3] = seq_r[3] > seq_r[4];
assign left_gt_right[4] = seq_r[4] > seq_r[5];
assign left_gt_right[5] = seq_r[5] > seq_r[6];
assign left_gt_right[6] = seq_r[6] > seq_r[7];

assign rfold[0] = left_gt_right[0] & rfold[1];
assign rfold[1] = left_gt_right[1] & rfold[2];
assign rfold[2] = left_gt_right[2] & rfold[3];
assign rfold[3] = left_gt_right[3] & rfold[4];
assign rfold[4] = left_gt_right[4] & rfold[5];
assign rfold[5] = left_gt_right[5] & rfold[6];
assign rfold[6] = left_gt_right[6];

assign is_swap[0] = !rfold[0] && rfold[1];
assign is_swap[1] = !rfold[1] && rfold[2];
assign is_swap[2] = !rfold[2] && rfold[3];
assign is_swap[3] = !rfold[3] && rfold[4];
assign is_swap[4] = !rfold[4] && rfold[5];
assign is_swap[5] = !rfold[5] && rfold[6];
assign is_swap[6] = !rfold[6];

assign swap_num = (
    is_swap[0] ? seq_r[0] :
    is_swap[1] ? seq_r[1] :
    is_swap[2] ? seq_r[2] :
    is_swap[3] ? seq_r[3] :
    is_swap[4] ? seq_r[4] :
    is_swap[5] ? seq_r[5] :
                 seq_r[6]
);

assign is_min_gt_swap[1] = seq_r[1] == min_gt_swap;
assign is_min_gt_swap[2] = seq_r[2] == min_gt_swap;
assign is_min_gt_swap[3] = seq_r[3] == min_gt_swap;
assign is_min_gt_swap[4] = seq_r[4] == min_gt_swap;
assign is_min_gt_swap[5] = seq_r[5] == min_gt_swap;
assign is_min_gt_swap[6] = seq_r[6] == min_gt_swap;
assign is_min_gt_swap[7] = seq_r[7] == min_gt_swap;

assign min_gt_swap = (
    seq_r[7] > swap_num ? seq_r[7] :
    seq_r[6] > swap_num ? seq_r[6] :
    seq_r[5] > swap_num ? seq_r[5] :
    seq_r[4] > swap_num ? seq_r[4] :
    seq_r[3] > swap_num ? seq_r[3] :
    seq_r[2] > swap_num ? seq_r[2] :
    seq_r[1] > swap_num ? seq_r[1] :
                          seq_r[0]
);

assign new_cost = cost_sum_r + Cost;

// output
always @(*) begin
    W = counter_r;
    J = seq_r[counter_r];
    MinCost = min_cost_r;
    MatchCount = match_count_r;
    Valid = state_r == LOAD && counter_r == 0 && prev_is_final_r;
end

always @(*) begin
    swapping_w = !swapping_r;
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        swapping_r <= 1;
    end
    else begin
        swapping_r <= swapping_w;
    end
end

always @(*) begin
    is_final_w = state_r == LOAD ? rfold[0] :
                 state_r == SEQ && counter_r[0] ? 0 : is_final_r;
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        is_final_r <= 1;
    end
    else begin
        is_final_r <= is_final_w;
    end
end

always @(*) begin
    prev_is_final_w = is_final_r;
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        prev_is_final_r <= 0;
    end
    else begin
        prev_is_final_r <= prev_is_final_w;
    end
end

always @(*) begin
    prev_is_swap_w[0] = is_swap[0];
    prev_is_swap_w[1] = is_swap[1];
    prev_is_swap_w[2] = is_swap[2];
    prev_is_swap_w[3] = is_swap[3];
    prev_is_swap_w[4] = is_swap[4];
    prev_is_swap_w[5] = is_swap[5];
    prev_is_swap_w[6] = is_swap[6];
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        for(i=0; i<7; i=i+1) begin
            prev_is_swap_r[i] <= 0;
        end
    end
    else begin
        for(i=0; i<7; i=i+1) begin
            prev_is_swap_r[i] <= prev_is_swap_w[i];
        end
    end
end

always @(*) begin
    case (state_r)
    LOAD: counter_w = counter_r + 1;
    SEQ:  counter_w = swapping_r ? counter_r+1 : 0;
    endcase
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        counter_r <= 0;
    end
    else begin
        counter_r <= counter_w;
    end
end

always @(*) begin
    cost_sum_w = cost_sum_r;
    if (state_r == SEQ) begin
        if (counter_r[0]) begin
            cost_sum_w = 0;
        end
        else begin
            cost_sum_w = new_cost;
        end
    end
    else if (state_r == LOAD) begin
        if (counter_r != 0) begin
            cost_sum_w = new_cost;
        end
    end
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        cost_sum_r <= 0;
    end
    else begin
        cost_sum_r <= cost_sum_w;
    end
end

always @(*) begin
    min_cost_w = min_cost_r;
    if (state_r == SEQ) begin
        if (counter_r[0]) begin
            min_cost_w = min_cost_r < cost_sum_r ? min_cost_r : cost_sum_r;
        end
    end
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        min_cost_r <= 10'b11_1111_1111;
    end
    else begin
        min_cost_r <= min_cost_w;
    end
end

always @(*) begin
    match_count_w = match_count_r;
    if (state_r == SEQ) begin
        if (counter_r[0]) begin
            match_count_w = min_cost_r > cost_sum_r ? 1 :
                            min_cost_r == cost_sum_r ? match_count_r+1 : match_count_r;
        end
    end
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        match_count_r <= 0;
    end
    else begin
        match_count_r <= match_count_w;
    end
end


always @(*) begin
    for(i=0; i<8; i=i+1) begin
        seq_w[i] = seq_r[i];
    end
    if (state_r == SEQ) begin
        if (swapping_r) begin
            seq_w[0] = (is_swap[0] ? min_gt_swap : seq_r[0]);

            seq_w[1] = (is_min_gt_swap[1] ? (
                seq_r[0]
            ) : is_swap[1] ? min_gt_swap : seq_r[1]);

            seq_w[2] = (is_min_gt_swap[2] ? (
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) : is_swap[2] ? min_gt_swap : seq_r[2]);

            seq_w[3] = (is_min_gt_swap[3] ? (
                is_swap[2] ? seq_r[2] :
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) : is_swap[3] ? min_gt_swap : seq_r[3]);

            seq_w[4] = (is_min_gt_swap[4] ? (
                is_swap[3] ? seq_r[3] :
                is_swap[2] ? seq_r[2] :
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) : is_swap[4] ? min_gt_swap : seq_r[4]);

            seq_w[5] = (is_min_gt_swap[5] ? (
                is_swap[4] ? seq_r[4] :
                is_swap[3] ? seq_r[3] :
                is_swap[2] ? seq_r[2] :
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) : is_swap[5] ? min_gt_swap : seq_r[5]);

            seq_w[6] = (is_min_gt_swap[6] ? (
                is_swap[5] ? seq_r[5] :
                is_swap[4] ? seq_r[4] :
                is_swap[3] ? seq_r[3] :
                is_swap[2] ? seq_r[2] :
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) : is_swap[6] ? min_gt_swap : seq_r[6]);

            seq_w[7] = (is_min_gt_swap[7] ? (
                is_swap[6] ? seq_r[6] :
                is_swap[5] ? seq_r[5] :
                is_swap[4] ? seq_r[4] :
                is_swap[3] ? seq_r[3] :
                is_swap[2] ? seq_r[2] :
                is_swap[1] ? seq_r[1] : seq_r[0]
            ) :  seq_r[7]);
        end
        else begin
            seq_w[0] = seq_r[0];
            seq_w[1] = prev_is_swap_r[0] ? seq_r[7] : seq_r[1];
            seq_w[2] = (
                prev_is_swap_r[0] ? seq_r[6] :
                prev_is_swap_r[1] ? seq_r[7] : seq_r[2]
            );
            seq_w[3] = (
                prev_is_swap_r[0] ? seq_r[5] :
                prev_is_swap_r[1] ? seq_r[6] :
                prev_is_swap_r[2] ? seq_r[7] : seq_r[3]
            );
            seq_w[4] = (
                // prev_is_swap_r[0] ? seq_r[4] :
                prev_is_swap_r[1] ? seq_r[5] :
                prev_is_swap_r[2] ? seq_r[6] :
                prev_is_swap_r[3] ? seq_r[7] : seq_r[4]
            );
            seq_w[5] = (
                prev_is_swap_r[0] ? seq_r[3] :
                prev_is_swap_r[1] ? seq_r[4] :
                // prev_is_swap_r[2] ? seq_r[5] :
                prev_is_swap_r[3] ? seq_r[6] :
                prev_is_swap_r[4] ? seq_r[7] : seq_r[5]
            );
            seq_w[6] = (
                prev_is_swap_r[0] ? seq_r[2] :
                prev_is_swap_r[1] ? seq_r[3] :
                prev_is_swap_r[2] ? seq_r[4] :
                prev_is_swap_r[3] ? seq_r[5] :
                // prev_is_swap_r[4] ? seq_r[6] :
                prev_is_swap_r[5] ? seq_r[7] : seq_r[6]
            );
            seq_w[7] = (
                prev_is_swap_r[0] ? seq_r[1] :
                prev_is_swap_r[1] ? seq_r[2] :
                prev_is_swap_r[2] ? seq_r[3] :
                prev_is_swap_r[3] ? seq_r[4] :
                prev_is_swap_r[4] ? seq_r[5] :
                prev_is_swap_r[5] ? seq_r[6] :
                // prev_is_swap_r[6] ? seq_r[7] :
                                    seq_r[7]
            );
        end
    end
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        for(i=0; i<8; i=i+1) begin
            seq_r[i] <= i[2:0];
        end
    end
    else begin
        for(i=0; i<8; i=i+1) begin
            seq_r[i] <= seq_w[i];
        end
    end
end

always @(*) begin
    case (state_r)
    SEQ:  state_w = counter_r == 1 ? LOAD : SEQ;
    LOAD: state_w = counter_r == 7 ? SEQ : LOAD;
    endcase
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        state_r <= LOAD;
    end
    else begin
        state_r <= state_w;
    end
end


// always @(posedge CLK or posedge RST) begin
//     if (RST) begin
//     end
//     else begin
//     end
// end
endmodule


