module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );

// localparam SEQ = 0;
// localparam LOAD = 1;
// localparam INIT = 2;

// reg [1:0] state_r, state_w;

reg [9:0] cost_sum_r, cost_sum_w;

reg [2:0] seq_r [0:7], seq_w [0:7];
reg [2:0] stack_r [0:7], stack_w [0:7]; // TODO can use fewer bits
wire [2:0] cur_seq;
wire [2:0] cur_stack;
wire [2:0] cur_swap;

reg [2:0] counter_r, counter_w;
reg [2:0] worker_r, worker_w;
wire [2:0] next_counter;
wire overflow;

reg swapped_r, swapped_w;
wire do_swap;
wire is_odd;

reg allow_swap;

wire sum_valid;
// reg swapping_r, swapping_w;

// reg [2:0] ctrl_r [0:7], ctrl_w [0:7];

// reg prev_is_swap_r [0:6], prev_is_swap_w [0:6];

reg [9:0] min_cost_r, min_cost_w;
reg [3:0] match_count_r, match_count_w;

wire is_final;
// reg [2:0] counter_r, counter_w;
// reg is_final_r, is_final_w;
// reg prev_is_final_r, prev_is_final_w;

// wire [9:0] new_cost;
integer i;

assign {overflow, next_counter} = counter_r + 1;
assign cur_seq = seq_r[counter_r];
assign cur_stack = stack_r[counter_r];
assign cur_swap = seq_r[cur_stack];
assign do_swap = cur_stack < counter_r;
assign is_odd = counter_r[0];

assign is_final = overflow && !do_swap;
assign sum_valid = swapped_r && worker_r == 1;

always @(*) begin
    W = worker_r;
    J = seq_r[worker_r];
    MatchCount = match_count_r;
    MinCost = min_cost_r;
    Valid = is_final;
end

always @(*) begin
    // allow_swap = 0;
    // if (state_r == INIT) begin
        allow_swap = worker_r == 6;
    // end
end

always @(*) begin
    worker_w = worker_r+1;
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        worker_r <= 0;
    end
    else begin
        worker_r <= worker_w;
    end
end

always @(*) begin
    counter_w = do_swap ? (allow_swap ? 0 : counter_r) : next_counter;
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
    min_cost_w = sum_valid && cost_sum_r < min_cost_r ? cost_sum_r : min_cost_r;
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
    match_count_w = sum_valid ? (
        cost_sum_r < min_cost_r ? 1 :
        cost_sum_r == min_cost_r ? match_count_r+1 :
        match_count_r
    ) : match_count_r;
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
    swapped_w = swapped_r || do_swap;
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        swapped_r <= 0;
    end
    else begin
        swapped_r <= swapped_w;
    end
end

always @(*) begin
    cost_sum_w = worker_r == 1 ? Cost : cost_sum_r + Cost;
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
    for(i=0; i<8; i=i+1) begin
        stack_w[i] = stack_r[i];
    end
    if (do_swap) begin
        stack_w[counter_r] = allow_swap ? stack_r[counter_r]+1 : stack_r[counter_r];
    end
    else begin
        stack_w[counter_r] = 0;
    end
end
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        for(i=0; i<8; i=i+1) begin
            stack_r[i] <= 0;
        end
    end
    else begin
        for(i=0; i<8; i=i+1) begin
            stack_r[i] <= stack_w[i];
        end
    end
end

always @(*) begin
    for(i=0; i<8; i=i+1) begin
        seq_w[i] = seq_r[i];
    end
    if (allow_swap && do_swap) begin
        if (is_odd) begin
            seq_w[counter_r] = cur_swap;
            seq_w[cur_stack] = cur_seq;
        end
        else begin
            seq_w[0] = cur_seq;
            seq_w[counter_r] = seq_r[0];
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

// always @(*) begin
//     case (state_r)
//     INIT: state_w = INIT;
//     endcase
// end
// always @(posedge CLK or posedge RST) begin
//     if (RST) begin
//         state_r <= INIT;
//     end
//     else begin
//         state_r <= state_w;
//     end
// end


// always @(posedge CLK or posedge RST) begin
//     if (RST) begin
//     end
//     else begin
//     end
// end
endmodule


