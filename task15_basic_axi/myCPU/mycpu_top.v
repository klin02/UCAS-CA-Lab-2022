`include "macro.v"

module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    //AR channel
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    //R channel
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    //AW channel
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    //W channel
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    //B channel
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    //debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

//cpu inst sram
wire        cpu_inst_req;
wire        cpu_inst_wr;
wire [ 2:0] cpu_inst_size;
wire [ 1:0] cpu_inst_size_org;
wire [ 3:0] cpu_inst_wstrb;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_wdata;
wire        cpu_inst_addr_ok;
wire        cpu_inst_data_ok;
wire [31:0] cpu_inst_rdata;
//cpu data sram
wire        cpu_data_req;
wire        cpu_data_wr;
wire [ 2:0] cpu_data_size;
wire [ 1:0] cpu_data_size_org;
wire [ 3:0] cpu_data_wstrb;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
wire        cpu_data_addr_ok;
wire        cpu_data_data_ok;
wire [31:0] cpu_data_rdata;


//通道分拆
wire        ar_cpu_data_req;
wire        aw_w_cpu_data_req;

wire        ar_cpu_data_addr_ok;
wire        aw_w_cpu_data_addr_ok;

wire        r_cpu_data_data_ok;
wire        b_cpu_data_data_ok;

//请求未响应缓冲区
reg [1:0]  wr_req_cnt;
reg [31:0] wr_req_addr_buf1;
reg [31:0] wr_req_addr_buf2;
wire raw_stall; //read after write
reg [1:0]  rd_req_cnt;
reg [31:0] rd_req_addr_buf1;
reg [31:0] rd_req_addr_buf2;
wire war_stall; //write after read

//AR channel
reg [1:0]  ar_state; //00 init 01 data 10 inst
//由于两个ram可能同时发起读事务，且需要保持不变，分别设置缓冲区
reg        ar_inst_buf_begin; //请求发起当拍为高，随后为低，请求握手下一拍为高
reg [ 2:0] ar_inst_size_buf;
reg [31:0] ar_inst_addr_buf;
reg        ar_data_buf_begin;
reg [ 2:0] ar_data_size_buf;
reg [31:0] ar_data_addr_buf;

//R channel
reg         r_inst_buf_valid;
reg [31:0]  r_inst_buf;
reg         r_data_buf_valid;
reg [31:0]  r_data_buf;

//AW/W channel
reg [ 2:0]aw_w_state; 
reg       aw_w_data_buf_begin;
reg [ 2:0]aw_w_data_size_buf;
reg [ 3:0]aw_w_data_wstrb_buf;
reg [31:0]aw_w_data_addr_buf;
reg [31:0]aw_w_data_wdata_buf;

//B channel
reg       b_resp_buf_valid;

//core interface
mycpu_core core(
    .clk              (aclk   ),
    .resetn           (aresetn),  //low active

    .inst_sram_req    (cpu_inst_req    ),
    .inst_sram_wr     (cpu_inst_wr     ),
    .inst_sram_size   (cpu_inst_size_org),
    .inst_sram_wstrb  (cpu_inst_wstrb  ),
    .inst_sram_addr   (cpu_inst_addr   ),
    .inst_sram_wdata  (cpu_inst_wdata  ),
    .inst_sram_addr_ok(cpu_inst_addr_ok),
    .inst_sram_data_ok(cpu_inst_data_ok),
    .inst_sram_rdata  (cpu_inst_rdata  ),
    
    .data_sram_req    (cpu_data_req    ),
    .data_sram_wr     (cpu_data_wr     ),
    .data_sram_size   (cpu_data_size_org),
    .data_sram_wstrb  (cpu_data_wstrb  ),
    .data_sram_addr   (cpu_data_addr   ),
    .data_sram_wdata  (cpu_data_wdata  ),
    .data_sram_addr_ok(cpu_data_addr_ok),
    .data_sram_data_ok(cpu_data_data_ok),
    .data_sram_rdata  (cpu_data_rdata  ),

    //debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
assign cpu_inst_size = {1'b0,cpu_inst_size_org};
assign cpu_data_size = {1'b0,cpu_data_size_org};
assign ar_cpu_data_req = cpu_data_req & ~cpu_data_wr;
assign aw_w_cpu_data_req = cpu_data_req &  cpu_data_wr;
assign cpu_data_addr_ok = ar_cpu_data_addr_ok | aw_w_cpu_data_addr_ok;
assign cpu_data_data_ok = r_cpu_data_data_ok | b_cpu_data_data_ok;
//考虑到AXI读写之间具有乱序性，考虑设置请求地址缓存区辅助判断
//由于流水线设计，最多两个data事务进行重叠，因此读写均设置两个缓冲区即可
//使用req作为进入条件，可以保证data读写请求不重合，且严格保证顺序

always@(posedge aclk) begin
    if(~aresetn)
        wr_req_cnt <= 2'b0;
    else if(wr_req_cnt == 2'b00)
    begin
        if((aw_w_state == 3'b000) & aw_w_cpu_data_req)
        begin
            wr_req_cnt <= 2'b01;
            wr_req_addr_buf1 <= cpu_data_addr;
        end
    end
    else if(wr_req_cnt == 2'b01)
    begin
        if((aw_w_state == 3'b000) & aw_w_cpu_data_req & bvalid & bready)//同时加减
        begin
            wr_req_cnt <= 2'b01;
            wr_req_addr_buf1 <= cpu_data_addr;
        end
        else if((aw_w_state == 3'b000) & aw_w_cpu_data_req)
        begin
            wr_req_cnt <= 2'b10;
            wr_req_addr_buf2 <= cpu_data_addr;
        end
        else if(bvalid & bready)
        begin
            wr_req_cnt <= 2'b00;
        end
    end
    else if(wr_req_cnt == 2'b10)
    begin
        if(bvalid & bready)
        begin
            wr_req_cnt <= 2'b01;
            wr_req_addr_buf1 <= wr_req_addr_buf2;
        end
    end
end

assign raw_stall = ((wr_req_cnt == 2'b01) | (wr_req_cnt == 2'b10)) & (ar_data_addr_buf[31:2] == wr_req_addr_buf1[31:2]) | 
                   (wr_req_cnt == 2'b10) & (ar_data_addr_buf[31:2] == wr_req_addr_buf2[31:2]);

always@(posedge aclk) begin
    if(~aresetn)
        rd_req_cnt <= 2'b00;
    else if(rd_req_cnt == 2'b00)
    begin
        if((ar_state == 2'b00) & ar_cpu_data_req)
        begin
            rd_req_cnt <= 2'b01;
            rd_req_addr_buf1 <= cpu_data_addr;
        end
    end
    else if(rd_req_cnt == 2'b01)
    begin
        if((ar_state == 2'b00) & ar_cpu_data_req & (rid == 4'b1) & rvalid & rready)
        begin
            rd_req_cnt <= 2'b01;
            rd_req_addr_buf1 <= cpu_data_addr;
        end
        else if((ar_state == 2'b00) & ar_cpu_data_req)
        begin
            rd_req_cnt <= 2'b10;
            rd_req_addr_buf2 <= cpu_data_addr;
        end
        else if((rid == 4'b1) & rvalid & rready)
        begin
            rd_req_cnt <= 2'b00;
        end
    end
    else if(rd_req_cnt == 2'b10)
    begin
        if((rid == 4'b1) & rvalid & rready)
        begin
            rd_req_cnt <= 2'b01;
            rd_req_addr_buf1 <= rd_req_addr_buf2;
        end
    end
end

assign war_stall = ((rd_req_cnt == 2'b01) | (rd_req_cnt == 2'b10)) & (aw_w_data_addr_buf[31:2] == rd_req_addr_buf1[31:2]) | 
                   (rd_req_cnt == 2'b10) & (aw_w_data_addr_buf[31:2] == rd_req_addr_buf2[31:2]);
                   
//AR channel

always@(posedge aclk) begin
    if(~aresetn)
        ar_inst_buf_begin <= 1'b1;
    else if(cpu_inst_req & ar_inst_buf_begin)
    begin
        ar_inst_size_buf <= cpu_inst_size;
        ar_inst_addr_buf <= cpu_inst_addr;
        ar_inst_buf_begin <= 1'b0;
    end
    else if(cpu_inst_addr_ok)
        ar_inst_buf_begin <= 1'b1;
end

always@(posedge aclk) begin
    if(~aresetn)
        ar_data_buf_begin <= 1'b1;
    else if(ar_cpu_data_req & ar_data_buf_begin)
    begin
        ar_data_size_buf <= cpu_data_size;
        ar_data_addr_buf <= cpu_data_addr;
        ar_data_buf_begin <= 1'b0;
    end
    else if(ar_cpu_data_addr_ok)
        ar_data_buf_begin <= 1'b1;
end

always@(posedge aclk) begin
    if(~aresetn)
        ar_state <= 2'b00;
    else if(ar_state == 2'b00)
    begin//条件具有优先级
        if(ar_cpu_data_req)
            ar_state <= 2'b10;
        else if(cpu_inst_req)
            ar_state <= 2'b01;
    end
    else if(ar_state == 2'b01) //inst
    begin
        if(arready)
            ar_state <= 2'b00;
    end
    else if(ar_state == 2'b10)
    begin
        if(arready & ~raw_stall)
            ar_state <= 2'b00;
        else if(~raw_stall) //不需堵塞，还未等待到arready，进入req with no stall
            ar_state <= 2'b11;
    end
    else if(ar_state == 2'b11)
    begin
        if(arready)
            ar_state <= 2'b00;
    end
end

//state
//01 req inst
//10 req data
//11 req data with no stall
assign arid   = ar_state == 2'b01 ? 4'b0 :
                (ar_state == 2'b10) | (ar_state == 2'b11) ? 4'b1 : 0;
assign araddr = ar_state == 2'b01 ? ar_inst_addr_buf :
                (ar_state == 2'b10) | (ar_state == 2'b11) ? ar_data_addr_buf : 0;
assign arsize = ar_state == 2'b01 ? ar_inst_size_buf :
                (ar_state == 2'b10) | (ar_state == 2'b11) ? ar_data_size_buf : 0;
assign arlen = 8'b0;
assign arburst = 2'b01;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arvalid = (ar_state == 2'b01) | (ar_state == 2'b10 & ~raw_stall) | (ar_state == 2'b11);
assign ar_cpu_data_addr_ok =  ((ar_state == 2'b10 & ~raw_stall) | (ar_state == 2'b11) )
                              & arready;
assign cpu_inst_addr_ok = (ar_state == 2'b01)
                          & arready;

//R channel

always@(posedge aclk)begin
    if(~aresetn)
        r_inst_buf_valid <= 1'b0;
    else if((rid == 4'b0) & rvalid & rready)
    begin
        r_inst_buf_valid <= 1'b1;
        r_inst_buf <= rdata;
    end
    else 
        r_inst_buf_valid <= 1'b0; //保证只拉高一拍
end
always@(posedge aclk)begin
    if(~aresetn)
        r_data_buf_valid <= 1'b0;
    else if((rid == 4'b1) & rvalid & rready)
    begin
        r_data_buf_valid <= 1'b1;
        r_data_buf <= rdata;
    end
    else 
        r_data_buf_valid <= 1'b0;
end

assign rready = aresetn;
assign cpu_inst_data_ok = r_inst_buf_valid;
assign r_cpu_data_data_ok = r_data_buf_valid;
assign cpu_inst_rdata = r_inst_buf;
assign cpu_data_rdata = r_data_buf;
//rresp and rlast is ignored

//AW/W channel
//req下一拍必然进入下一状态，且不再考虑stall。以免相互阻塞
//state:
//001 req
//010 req and no stall
//100 awready yes | wready  no
//101 awready  no | wready yes

always@(posedge aclk)begin
    if(~aresetn)
        aw_w_data_buf_begin <= 1'b1;
    else if(aw_w_cpu_data_req & aw_w_data_buf_begin)
    begin
        aw_w_data_size_buf <= cpu_data_size;
        aw_w_data_wstrb_buf <= cpu_data_wstrb;
        aw_w_data_addr_buf <= cpu_data_addr;
        aw_w_data_wdata_buf <= cpu_data_wdata;
        aw_w_data_buf_begin <= 1'b0;
    end
    else if(aw_w_cpu_data_addr_ok)
        aw_w_data_buf_begin <= 1'b1;
end

always@(posedge aclk)begin
    if(~aresetn)
        aw_w_state <= 3'b000;
    else if(aw_w_state == 3'b000)
    begin
        if(aw_w_cpu_data_req)
            aw_w_state <= 3'b001;
    end
    else if(aw_w_state == 3'b001)
    begin
        if(war_stall)
            aw_w_state <= 3'b001;
        else if(awready & wready)
            aw_w_state <= 3'b000;
        else if(awready)
            aw_w_state <= 3'b100;
        else if(wready)
            aw_w_state <= 3'b101;
        else    
            aw_w_state <= 3'b010;
    end
    else if(aw_w_state <= 3'b010)
    begin
        if(awready & wready)
            aw_w_state <= 3'b000;
        else if(awready)
            aw_w_state <= 3'b100;
        else if(wready)
            aw_w_state <= 3'b101;
    end
    else if(aw_w_state == 3'b100)
    begin
        if(wready)
            aw_w_state <= 3'b000;
    end
    else if(aw_w_state == 3'b101)
    begin
        if(awready)
            aw_w_state <= 3'b000;
    end
end

//AW channel
assign awid = 4'b1;
assign awaddr = aw_w_data_addr_buf;
assign awlen = 8'b0;
assign awsize = aw_w_data_size_buf;
assign awburst = 2'b01;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
//state 100: aw channel handshake is done
assign awvalid = (aw_w_state == 3'b001 & ~war_stall) | 
                 (aw_w_state == 3'b010)|
                 (aw_w_state == 3'b101);

//W channel
assign wid = 4'b1;
assign wdata = aw_w_data_wdata_buf;
assign wlast = 1'b1;
assign wstrb = aw_w_data_wstrb_buf;
assign wvalid = (aw_w_state == 3'b001 & ~war_stall) | 
                (aw_w_state == 3'b010)|
                (aw_w_state == 3'b100);

assign aw_w_cpu_data_addr_ok = (aw_w_state == 3'b001) & awready & wready & ~war_stall |
                               (aw_w_state == 3'b010) & awready & wready |
                               (aw_w_state == 3'b100) & wready |
                               (aw_w_state == 3'b101) & awready;

//B channel
//bid and bresp can be ignored
assign bready = aresetn;
always@(posedge aclk) begin
    if(~aresetn)
        b_resp_buf_valid <= 1'b0;
    else if(bvalid & bready)
        b_resp_buf_valid <= 1'b1;
    else
        b_resp_buf_valid <= 1'b0;
end        
assign b_cpu_data_data_ok = b_resp_buf_valid;
endmodule
