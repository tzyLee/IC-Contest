module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);

input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index;
output valid;
// reg match;
// reg [4:0] match_index;
// reg valid;

localparam LOAD_DATA = 0;
localparam MATCH_RST = 1;
localparam MATCHING = 2;
localparam OUTPUT = 3;

localparam CHAR_START = 'h5E;
localparam CHAR_END = 'h24;
localparam CHAR_ANY = 'h2E;
localparam CHAR_WILDCARD = 'h2A;
localparam CHAR_SPACE = 'h20;

reg [1:0] state_r, state_w;

reg [7:0] str_buf_r [0:31], str_buf_w [0:31]; // 32 chars
reg [7:0] ptn_buf_r [0:7], ptn_buf_w [0:7]; // 8 chars

reg str_load_r, str_load_w;

reg [5:0] counter_s_r, counter_s_w; // outer
reg [3:0] counter_p_r, counter_p_w;
reg [5:0] s_end_r, s_end_w;
reg [3:0] p_end_r, p_end_w;
reg [5:0] counter_si_r, counter_si_w; // inner
reg [5:0] match_index_r, match_index_w; // TODO remove this
reg [3:0] wild_begin_r, wild_begin_w;
reg wild_seen_r, wild_seen_w;

wire [4:0] s, si, match_idx;
wire [2:0] p;

reg match_r, match_w;

wire match_single;
wire match_accept;
wire ptr_end, str_end;
wire match_end;
wire is_wildcard, is_start;
wire [5:0] match_idx_p1;

integer i;

// combinational
assign s = counter_s_r[4:0];
assign si = counter_si_r[4:0];
assign p = counter_p_r[2:0];
assign match_idx_p1 = match_index_r+1;
assign match_idx = (match_index_r[4:0] != 0 && ptn_buf_r[0] == CHAR_START) ?
                    match_idx_p1[4:0] : match_index_r[4:0];


assign is_wildcard = ptn_buf_r[p] == CHAR_WILDCARD;
assign is_start = ptn_buf_r[0] == CHAR_START;

assign match_single = str_buf_r[si] == ptn_buf_r[p] ||
                      ptn_buf_r[p] == CHAR_ANY;
assign match_accept = match_single || (ptn_buf_r[p] == CHAR_START && str_buf_r[si] == CHAR_SPACE);
assign ptr_end = counter_p_r == p_end_r ||
                 (ptn_buf_r[p] == CHAR_END && (str_end || str_buf_r[si] == CHAR_SPACE));
wire debug1, debug2;
assign debug1 = str_buf_r[si] == CHAR_SPACE;
assign debug2 = ptn_buf_r[p] == CHAR_END;

assign str_end = counter_si_r == s_end_r;
assign match_end = ptr_end || str_end;


// output
assign valid = state_r == OUTPUT;
assign match = match_r;
assign match_index = match_idx;

always @(*) begin
    match_w = ptr_end;
end
always @(posedge clk or posedge reset) begin
    if (reset) match_r <= 0;
    else match_r <= match_w;
end

always @(*) begin
    match_index_w = counter_s_r;
end
always @(posedge clk or posedge reset) begin
    if (reset) match_index_r <= 0;
    else match_index_r <= match_index_w;
end

// counter
always @(*) begin
    case(state_r)
    LOAD_DATA: counter_s_w = isstring ? counter_s_r + 1 : counter_s_r;
    MATCH_RST: counter_s_w = 0;
    MATCHING:  counter_s_w = match_end ? 0 :
                             (is_wildcard || match_accept || wild_seen_r) ? counter_s_r :
                             counter_s_r + 1;
    OUTPUT:    counter_s_w = 1;
    default:   counter_s_w = counter_s_r;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        counter_s_r <= 0;
    end
    else begin
        counter_s_r <= counter_s_w;
    end
end

always @(*) begin
    case(state_r)
    LOAD_DATA: counter_si_w = 0;
    MATCH_RST: counter_si_w = 0;
    MATCHING:  counter_si_w = is_wildcard ? counter_si_r :
                              match_accept || wild_seen_r ? counter_si_r+1 :
                              counter_s_r+1;
    OUTPUT:    counter_si_w = 0;
    default:   counter_si_w = counter_si_r;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        counter_si_r <= 0;
    end
    else begin
        counter_si_r <= counter_si_w;
    end
end

always @(*) begin
    case(state_r)
    LOAD_DATA: counter_p_w = ispattern ? counter_p_r + 1 : counter_p_r;
    MATCH_RST: counter_p_w = is_start ? 1 : 0;
    MATCHING:  counter_p_w = match_end ? 0 :
                             is_wildcard || match_accept ? counter_p_r+1 :
                             wild_begin_r;
    OUTPUT:    counter_p_w = ispattern ? 1 : 0;
    default:   counter_p_w = counter_p_r;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        counter_p_r <= 0;
    end
    else begin
        counter_p_r <= counter_p_w;
    end
end

always @(*) begin
    if (state_r == MATCHING) begin
        wild_seen_w = is_wildcard || wild_seen_r;
    end
    else begin
        wild_seen_w = 0;
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        wild_seen_r <= 0;
    end
    else begin
        wild_seen_r <= wild_seen_w;
    end
end

always @(*) begin
    if (state_r == MATCHING) begin
        wild_begin_w = is_wildcard ? counter_p_r+1 : wild_begin_r;
    end
    else begin
        wild_begin_w = 0;
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        wild_begin_r <= 0;
    end
    else begin
        wild_begin_r <= wild_begin_w;
    end
end

// str load -> update end position
always @(*) begin
    str_load_w = (state_r == MATCH_RST) ? 0 : isstring || str_load_r;
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        str_load_r <= 0;
    end
    else begin
        str_load_r <= str_load_w;
    end
end

// end position
always @(*) begin
    s_end_w = (state_r == MATCH_RST && str_load_r) ? counter_s_r : s_end_r;
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        s_end_r <= 0;
    end
    else begin
        s_end_r <= s_end_w;
    end
end

always @(*) begin
    p_end_w = (state_r == MATCH_RST) ? counter_p_r : p_end_r;
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        p_end_r <= 0;
    end
    else begin
        p_end_r <= p_end_w;
    end
end

// string_buf
always @(*) begin
    if (isstring) begin
        for(i=0; i<32; i=i+1) begin
            str_buf_w[i] = str_buf_r[i];
        end
        str_buf_w[s] = chardata;
    end
    else begin
        for(i=0; i<32; i=i+1) begin
            str_buf_w[i] = str_buf_r[i];
        end
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        for(i=0; i<32; i=i+1) begin
            str_buf_r[i] <= 0;
        end
    end
    else begin
        for(i=0; i<32; i=i+1) begin
            str_buf_r[i] <= str_buf_w[i];
        end
    end
end

// pattern_buf
always @(*) begin
    if (ispattern) begin
        for(i=0; i<8; i=i+1) begin
            ptn_buf_w[i] = ptn_buf_r[i];
        end
        ptn_buf_w[p] = chardata;
    end
    else begin
        for(i=0; i<8; i=i+1) begin
            ptn_buf_w[i] = ptn_buf_r[i];
        end
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        for(i=0; i<8; i=i+1) begin
            ptn_buf_r[i] <= 0;
        end
    end
    else begin
        for(i=0; i<8; i=i+1) begin
            ptn_buf_r[i] <= ptn_buf_w[i];
        end
    end
end

// State
always @(*) begin
    case (state_r)
    LOAD_DATA: state_w = (isstring || ispattern) ? LOAD_DATA : MATCH_RST;
    MATCH_RST: state_w = MATCHING;
    MATCHING:  state_w = match_end ? OUTPUT : MATCHING;
    OUTPUT:    state_w = LOAD_DATA;
    default:   state_w = LOAD_DATA;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state_r <= LOAD_DATA;
    end
    else begin
        state_r <= state_w;
    end
end


endmodule
