module cache( 
    input         clk,
    input         resetn, 
    //CPU<->CACHE interface
    input         valid,
    input         op,           //1 write 0 read
    input [ 7:0]  index,        //addr[11:4]
    input [19:0]  tag,      //pfn + addr[12]
    input [ 3:0]  offset,       //addr[3:0]
    input [ 3:0]  wstrb,
    input [31:0]  wdata,
    output        addr_ok,
    output        data_ok,
    output[31:0]  rdata,
    //CACHE<->AXI-BRIDGE interface
    //read
    output        rd_req,
    output[ 2:0]  rd_type,      //3'b000-BYTE  3'b001-HALFWORD 3'b010-WORD 3'b100-cache-row
    output[31:0]  rd_addr,
    input         rd_rdy,       //read_req can be accepted
    input         ret_valid,
    input         ret_last,
    input [31:0]  ret_data,
    //write
    output        wr_req,
    output[ 2:0]  wr_type,
    output[31:0]  wr_addr,
    output[ 3:0]  wr_wstrb,
    output[127:0] wr_data,       
    input         wr_rdy        //write_req can be accepted, actually nonsense in inst_cache
);  

localparam      IDLE    = 5'b00001,
                LOOKUP  = 5'b00010, 
                MISS    = 5'b00100,
                REPLACE = 5'b01000,
                REFILL  = 5'b10000;
localparam      WIDLE   = 2'b01,
                WRITE   = 2'b10;

/************* instance module *************/
wire [ 3:0] tagv_ram_we_0;
wire [ 7:0] tagv_ram_addr_0;
wire [23:0] tagv_ram_wdata_0;
wire [23:0] tagv_ram_rdata_0;        
tagv_ram tagv_ram_0(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (tagv_ram_we_0),
        .addra  (tagv_ram_addr_0),
        .dina   (tagv_ram_wdata_0),
        .douta  (tagv_ram_rdata_0)
);

wire [ 3:0] tagv_ram_we_1;
wire [ 7:0] tagv_ram_addr_1;
wire [23:0] tagv_ram_wdata_1;
wire [23:0] tagv_ram_rdata_1;        
tagv_ram tagv_ram_1(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (tagv_ram_we_1),
        .addra  (tagv_ram_addr_1),
        .dina   (tagv_ram_wdata_1),
        .douta  (tagv_ram_rdata_1)
);

wire       dirty_ram_we_0;
wire [7:0] dirty_ram_addr_0;
wire       dirty_ram_wdata_0;
wire       dirty_ram_rdata_0;
dirty_ram dirty_ram_0(
        .clk    (clk),
        .resetn (resetn),
        .we     (dirty_ram_we_0),
        .addr  (dirty_ram_addr_0),
        .wdata  (dirty_ram_wdata_0),
        .rdata  (dirty_ram_rdata_0)
);

wire       dirty_ram_we_1;
wire [7:0] dirty_ram_addr_1;
wire       dirty_ram_wdata_1;
wire       dirty_ram_rdata_1;
dirty_ram dirty_ram_1(
        .clk    (clk),
        .resetn (resetn),
        .we     (dirty_ram_we_1),
        .addr  (dirty_ram_addr_1),
        .wdata  (dirty_ram_wdata_1),
        .rdata  (dirty_ram_rdata_1)
);

wire [ 3:0] data_ram_we_0_0;
wire [ 7:0] data_ram_addr_0_0;
wire [31:0] data_ram_wdata_0_0;
wire [31:0] data_ram_rdata_0_0;
data_bank_ram data_bank_ram_0_0(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_0_0),
        .addra  (data_ram_addr_0_0),
        .dina   (data_ram_wdata_0_0),
        .douta  (data_ram_rdata_0_0)
);
wire [ 3:0] data_ram_we_0_1;
wire [ 7:0] data_ram_addr_0_1;
wire [31:0] data_ram_wdata_0_1;
wire [31:0] data_ram_rdata_0_1;
data_bank_ram data_bank_ram_0_1(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_0_1),
        .addra  (data_ram_addr_0_1),
        .dina   (data_ram_wdata_0_1),
        .douta  (data_ram_rdata_0_1)
);
wire [ 3:0] data_ram_we_0_2;
wire [ 7:0] data_ram_addr_0_2;
wire [31:0] data_ram_wdata_0_2;
wire [31:0] data_ram_rdata_0_2;
data_bank_ram data_bank_ram_0_2(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_0_2),
        .addra  (data_ram_addr_0_2),
        .dina   (data_ram_wdata_0_2),
        .douta  (data_ram_rdata_0_2)
);
wire [ 3:0] data_ram_we_0_3;
wire [ 7:0] data_ram_addr_0_3;
wire [31:0] data_ram_wdata_0_3;
wire [31:0] data_ram_rdata_0_3;
data_bank_ram data_bank_ram_0_3(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_0_3),
        .addra  (data_ram_addr_0_3),
        .dina   (data_ram_wdata_0_3),
        .douta  (data_ram_rdata_0_3)
);

wire [ 3:0] data_ram_we_1_0;
wire [ 7:0] data_ram_addr_1_0;
wire [31:0] data_ram_wdata_1_0;
wire [31:0] data_ram_rdata_1_0;
data_bank_ram data_bank_ram_1_0(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_1_0),
        .addra  (data_ram_addr_1_0),
        .dina   (data_ram_wdata_1_0),
        .douta  (data_ram_rdata_1_0)
);
wire [ 3:0] data_ram_we_1_1;
wire [ 7:0] data_ram_addr_1_1;
wire [31:0] data_ram_wdata_1_1;
wire [31:0] data_ram_rdata_1_1;
data_bank_ram data_bank_ram_1_1(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_1_1),
        .addra  (data_ram_addr_1_1),
        .dina   (data_ram_wdata_1_1),
        .douta  (data_ram_rdata_1_1)
);
wire [ 3:0] data_ram_we_1_2;
wire [ 7:0] data_ram_addr_1_2;
wire [31:0] data_ram_wdata_1_2;
wire [31:0] data_ram_rdata_1_2;
data_bank_ram data_bank_ram_1_2(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_1_2),
        .addra  (data_ram_addr_1_2),
        .dina   (data_ram_wdata_1_2),
        .douta  (data_ram_rdata_1_2)
);
wire [ 3:0] data_ram_we_1_3;
wire [ 7:0] data_ram_addr_1_3;
wire [31:0] data_ram_wdata_1_3;
wire [31:0] data_ram_rdata_1_3;
data_bank_ram data_bank_ram_1_3(
        .clka   (clk),
        .ena    (1'b1),
        .wea    (data_ram_we_1_3),
        .addra  (data_ram_addr_1_3),
        .dina   (data_ram_wdata_1_3),
        .douta  (data_ram_rdata_1_3)
);
/****************************************/

reg         wr_req_r;

reg  [ 4:0] cur_state;
reg  [ 4:0] next_state;

reg  [ 1:0] wbuf_cur_state;
reg  [ 1:0] wbuf_next_state;

reg         in_work;  //表示当前处理是否结束
reg         wr_req_r;
wire        work_done;

//Request Buffer
reg         op_r;
reg  [ 7:0] index_r;
reg  [19:0] tag_r;
reg  [ 3:0] offset_r;
reg  [ 3:0] wstrb_r;
reg  [31:0] wdata_r;

//Miss Buffer
reg         replace_way;
reg  [ 1:0] ret_cnt;
wire        replace_dirty;
//Write Buffer
reg         wbuf_way;
reg [ 1:0]  wbuf_bank;
reg [ 7:0]  wbuf_index;
reg [ 3:0]  wbuf_wstrb;
reg [31:0]  wbuf_wdata;

//LFSR
reg  [22:0] pseudo_random_23;

wire        hit_write_0;
wire        hit_write_1;
wire        hit_write;
wire        hit_write_block;
wire        cache_hit;

wire         way0_hit;
wire [ 19:0] way0_tag;
wire         way0_v;
wire         way0_dirty;
wire [127:0] way0_data;
wire         way1_hit;
wire [ 19:0] way1_tag;
wire         way1_v;
wire         way1_dirty;
wire [127:0] way1_data;

wire [ 32:0] way0_load_word;
wire [ 32:0] way1_load_word;
wire [ 32:0] load_res;
wire [127:0] replace_data;

wire [ 7:0]  data_ram_addr;
wire [ 3:0]  data_ram_mask_refill; //写操作时掩码
wire [31:0]  data_ram_wdata_refill;  //混合写cache和回填数据
wire [31:0]  data_ram_wdata; //各片相同，配合ram写使能信号

reg  [31:0]  rdata_refill_r;
wire [31:0]  replace_tag;

//Request Buffer
always @(posedge clk) begin
        if(~resetn) begin
                in_work <= 1'b0;
                op_r <= 1'b0;
                index_r <= 8'b0;
                tag_r <= 20'b0;
                offset_r <= 4'b0;
                wstrb_r <= 4'b0;
                wdata_r <= 32'b0;        
        end
        else if(valid & (~in_work | work_done)) begin //cache操作限制了事务不应进行重叠，为保持流水级不变，可以不给addr ok
                in_work <= 1'b1;
                op_r <= op;
                index_r <= index;
                tag_r <= tag;
                offset_r <= offset;
                wstrb_r <= wstrb;
                wdata_r <= wdata;
        end
        else if(work_done) begin
                in_work <= 1'b0;
        end
end

//Miss Buffer
always @(posedge clk) begin
        if(~resetn) 
                replace_way <= 1'b0;
        else if(cur_state == REFILL & ret_valid & ret_last)
                replace_way <= pseudo_random_23[0];
end
always @(posedge clk) begin
        if(~resetn) 
                ret_cnt <= 2'b0;
        else if(ret_valid)
                ret_cnt <= ret_cnt + 2'b01;
        else if((wbuf_cur_state == REPLACE) & rd_rdy)
                ret_cnt <= 2'b0;
end

//LFSR
always @(posedge clk) begin
        if (~resetn)
                pseudo_random_23 <= {7'b1010101,16'h00FF};
        else
                pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
end

always @(posedge clk) begin
        if(~resetn)
                cur_state <= IDLE;
        else
                cur_state <= next_state;
end
always @(*) begin
        case(cur_state)
        IDLE: begin
                if((valid | in_work) & ~hit_write_block) //此处用in work表示因为冲突未能离开idle态的情况
                        next_state = LOOKUP;
                else
                        next_state = IDLE;
        end
        LOOKUP: begin
                if(cache_hit & (~valid | (valid & hit_write_block)))
                        next_state = IDLE;
                else if(cache_hit & valid & ~hit_write_block)
                        next_state = LOOKUP;
                else if(~cache_hit)
                        next_state = MISS;
                else
                        next_state = LOOKUP;
        end
        MISS: begin
                if(~wr_rdy)
                        next_state = MISS;
                else 
                        next_state = REPLACE;
        end
        REPLACE: begin
                if(~rd_rdy)
                        next_state = REPLACE;
                else
                        next_state = REFILL;
        end
        REFILL: begin
                if(ret_valid & ret_last)
                        next_state = IDLE;
                else
                        next_state = REFILL;
        end
        default:
                next_state = IDLE;
        endcase
end

//Write Buffer
always @(posedge clk) begin
        if(~resetn) 
                wbuf_cur_state <= WIDLE;
        else
                wbuf_cur_state <= wbuf_next_state;
end
always @(*) begin
        case(wbuf_cur_state)
        WIDLE: begin
                if(hit_write)
                        wbuf_next_state = WRITE;
                else
                        wbuf_next_state = WIDLE;
        end
        WRITE: begin
                if(hit_write)
                        wbuf_next_state = WRITE;
                else
                        wbuf_next_state = WIDLE;
        end
        endcase
end
always @(posedge clk)begin
        if(~resetn) begin
                wbuf_way <= 1'b0;
                wbuf_bank <= 2'b0;
                wbuf_index <= 8'b0;
                wbuf_wstrb <= 4'b0;
                wbuf_wdata <= 32'b0;
        end
        else if(hit_write)begin
                wbuf_way <= way1_hit;
                wbuf_bank <= offset_r[3:2];
                wbuf_index <= index_r;
                wbuf_wstrb <= wstrb_r;
                wbuf_wdata <= wdata_r;
        end
end

//避免引入RAM输出端到输入端路径，如cache_hit，data_ok
assign tagv_ram_addr_0 = cur_state == LOOKUP ? index : index_r;
assign tagv_ram_addr_1 = cur_state == LOOKUP ? index : index_r;
//重填时应用
assign tagv_ram_we_0 = {4{(cur_state == REFILL) & ~replace_way}};
assign tagv_ram_we_1 = {4{(cur_state == REFILL) &  replace_way}};
assign tagv_ram_wdata_0 = {tag_r,1'b1,3'b0};
assign tagv_ram_wdata_1 = {tag_r,1'b1,3'b0};
assign {way0_tag,way0_v} = tagv_ram_rdata_0[23:3];
assign {way1_tag,way1_v} = tagv_ram_rdata_1[23:3];

//写命中或replace时更新
assign dirty_ram_addr_0 = index_r;
assign dirty_ram_addr_1 = index_r;
assign dirty_ram_we_0 = hit_write_0     | 
                        (cur_state == MISS)   & ~replace_way ;
assign dirty_ram_we_1 = hit_write_1     | 
                        (cur_state == MISS)   &  replace_way ;
assign dirty_ram_wdata_0 = op_r; //replace时读操作写0
assign dirty_ram_wdata_1 = op_r;
assign way0_dirty = dirty_ram_rdata_0;
assign way1_dirty = dirty_ram_rdata_1;

//write when hit_write(LOOKUP) or REFILL
assign data_ram_addr = wbuf_cur_state == WRITE ? wbuf_index : index_r;
assign data_ram_addr_0_0 = index_r;
assign data_ram_addr_0_1 = index_r;
assign data_ram_addr_0_2 = index_r;
assign data_ram_addr_0_3 = index_r;
assign data_ram_addr_1_0 = index_r;
assign data_ram_addr_1_1 = index_r;
assign data_ram_addr_1_2 = index_r;
assign data_ram_addr_1_3 = index_r;

assign data_ram_we_0_0 = {4{(wbuf_cur_state == WRITE) & ~wbuf_way & (wbuf_bank == 2'b00)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) & ~replace_way & ret_valid & ret_cnt == 2'b00}};
assign data_ram_we_0_1 = {4{(wbuf_cur_state == WRITE) & ~wbuf_way & (wbuf_bank == 2'b01)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) & ~replace_way & ret_valid & ret_cnt == 2'b01}};
assign data_ram_we_0_2 = {4{(wbuf_cur_state == WRITE) & ~wbuf_way & (wbuf_bank == 2'b10)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) & ~replace_way & ret_valid & ret_cnt == 2'b10}};     
assign data_ram_we_0_3 = {4{(wbuf_cur_state == WRITE) & ~wbuf_way & (wbuf_bank == 2'b11)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) & ~replace_way & ret_valid & ret_cnt == 2'b11}};
assign data_ram_we_1_0 = {4{(wbuf_cur_state == WRITE) &  wbuf_way & (wbuf_bank == 2'b00)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) &  replace_way & ret_valid & ret_cnt == 2'b00}};
assign data_ram_we_1_1 = {4{(wbuf_cur_state == WRITE) &  wbuf_way & (wbuf_bank == 2'b01)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) &  replace_way & ret_valid & ret_cnt == 2'b01}};
assign data_ram_we_1_2 = {4{(wbuf_cur_state == WRITE) &  wbuf_way & (wbuf_bank == 2'b10)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) &  replace_way & ret_valid & ret_cnt == 2'b10}};     
assign data_ram_we_1_3 = {4{(wbuf_cur_state == WRITE) &  wbuf_way & (wbuf_bank == 2'b11)}} & wbuf_wstrb | 
                         {4{(cur_state == REFILL) &  replace_way & ret_valid & ret_cnt == 2'b11}};                
assign way0_data = {data_ram_rdata_0_3,data_ram_rdata_0_2,data_ram_rdata_0_1,data_ram_rdata_0_0};
assign way1_data = {data_ram_rdata_1_3,data_ram_rdata_1_2,data_ram_rdata_1_1,data_ram_rdata_1_0};
//wdata: hit write时配合写使能，直接赋值；Refill时与写数据混合
assign data_ram_mask_refill = {4{op_r}} & wstrb_r;
assign data_ram_wdata_refill =  {
                                {8{data_ram_mask_refill[3]}} & wdata_r[31:24] | {8{~data_ram_mask_refill[3]}} & ret_data[31:24] ,
                                {8{data_ram_mask_refill[2]}} & wdata_r[23:16] | {8{~data_ram_mask_refill[2]}} & ret_data[23:16] ,
                                {8{data_ram_mask_refill[1]}} & wdata_r[15: 8] | {8{~data_ram_mask_refill[1]}} & ret_data[15: 8] ,
                                {8{data_ram_mask_refill[0]}} & wdata_r[ 7: 0] | {8{~data_ram_mask_refill[0]}} & ret_data[ 7: 0] 
                                };
assign data_ram_wdata = wbuf_cur_state == WRITE ? wbuf_wdata : 
                        offset_r[3:2] == ret_cnt? data_ram_wdata_refill :
                        ret_data;
assign data_ram_wdata_0_0 = data_ram_wdata;
assign data_ram_wdata_0_1 = data_ram_wdata;
assign data_ram_wdata_0_2 = data_ram_wdata;
assign data_ram_wdata_0_3 = data_ram_wdata;
assign data_ram_wdata_1_0 = data_ram_wdata;
assign data_ram_wdata_1_1 = data_ram_wdata;
assign data_ram_wdata_1_2 = data_ram_wdata;
assign data_ram_wdata_1_3 = data_ram_wdata;

assign way0_load_word = way0_data[offset_r[3:2]*32 +: 32];
assign way1_load_word = way1_data[offset_r[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word |
                  {32{way1_hit}} & way1_load_word ;
assign replace_data = replace_way ? way1_data : way0_data;

assign way0_hit = way0_v & (way0_tag == tag_r);
assign way1_hit = way1_v & (way1_tag == tag_r);
assign cache_hit = way0_hit | way1_hit;
assign hit_write_0 = (cur_state == LOOKUP) & way0_hit & op_r;
assign hit_write_1 = (cur_state == LOOKUP) & way1_hit & op_r;
assign hit_write = hit_write_0 | hit_write_1;
assign hit_write_block = valid & ~op & 
                        (
                         hit_write & (index == index_r) & (offset[3:2] == offset_r[3:2]) |
                         (wbuf_cur_state == WRITE) & (index == wbuf_index) & (offset[3:2] == wbuf_bank)
                        ) ;
//module port control
//cpu interface
always @(posedge clk) begin
        if(~resetn)
                rdata_refill_r <= 32'b0;
        else if((offset_r[3:2] == ret_cnt) & ret_valid) //读操作已经设置过设置掩码保证全为返还数据
                rdata_refill_r <= data_ram_wdata_refill;
end
assign addr_ok = (cur_state == IDLE & valid) | ((cur_state == LOOKUP) & cache_hit & valid & ~hit_write_block);
assign data_ok = ((cur_state == LOOKUP) & cache_hit) |
                 ((cur_state == LOOKUP) & op_r)      | //write
                 ((cur_state == REFILL) & (offset_r[3:2] == ret_cnt) & ret_valid & ~op_r);
assign work_done = ((cur_state == LOOKUP) & cache_hit) | ((cur_state == IDLE) & in_work); //last时最后一个数据还未写
// assign data_ok = ((cur_state == LOOKUP) & cache_hit) | ((cur_state == IDLE) & in_work);
assign rdata = (cur_state == LOOKUP) & cache_hit ? load_res : data_ram_wdata_refill;

//axi interface
assign replace_dirty = replace_way ? way1_dirty : way0_dirty;
always @(posedge clk)begin
        if(~resetn)
                wr_req_r <= 1'b0;
        else if((cur_state == MISS) & wr_rdy & replace_dirty)
                wr_req_r <= 1'b1;
        else if(wr_rdy)
                wr_req_r <= 1'b0;
end
assign rd_req = cur_state == REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {tag_r,index_r,4'b0};
assign wr_req = wr_req_r;
assign wr_type = 3'b100;
assign replace_tag = replace_way ? way1_tag : way0_tag;
assign wr_addr = {replace_tag,index_r,4'b0};
assign wr_wstrb = 4'b1111;
assign wr_data = replace_data;

endmodule



/*************** DIRTY RAM *********************/
module dirty_ram (
        input           clk,
        input           resetn,
        input           we,
        input [7:0]     addr,
        output          wdata,
        output          rdata
);
reg [255:0] dirty_array;

always @(posedge clk) begin
        if(~resetn)
                dirty_array <= 256'b0;
        else if(we)
                dirty_array[addr] <= wdata;
end
assign rdata = dirty_array[addr];

endmodule