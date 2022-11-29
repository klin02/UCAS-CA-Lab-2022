`include "macro.v"

module IF_stage(
        input  clk,
        input  reset,

//inst_sram interface
        output wire        inst_sram_req,
        output wire        inst_sram_wr,
        output wire [1:0]  inst_sram_size,
        output wire [3:0]  inst_sram_wstrb,
        output wire [31:0] inst_sram_addr,
        output wire [31:0] inst_sram_wdata,
        input  wire        inst_sram_addr_ok,
        input  wire        inst_sram_data_ok,
        input  wire [31:0] inst_sram_rdata,

//from ID
        //branch information from ID stage
        input  [`BR_BUS_WD - 1 : 0] br_bus,
        //Signal show next state ready to accept
        input  ds_allowin,
//to ID
        //Signal show this state valid to send
        output fs_to_ds_valid,
        //data IF send to ID
        output [`FS_TO_DS_BUS_WD - 1 : 0] fs_to_ds_bus,

//addr map interface
        output fs_req,
        output [31:0] fs_addr,
        input addr_map,
        input fs_tlbr,
        input fs_pif,
        input fs_ppi,
        input fs_en_dmw,
        input [2:0] fs_dmw_pseg,
        input [5:0] fs_ps,
        input [19:0] fs_ppn,

//exception data
        input expt_clear,
        input [31:0] expt_refresh_pc
);

        wire    to_fs_valid;
        
        wire    br_stall;
        wire	br_taken;
        reg     br_taken_delay;
	wire [31:0] br_target;

        reg     fs_valid;
        wire    fs_allowin;
        wire    fs_ready_go;
        reg     fs_pass_delay; //allowin和readygo握手时，数据响应，将其延迟以使能req

        reg [31:0] fs_pc;
        wire [31:0] nextpc;
        wire [31:0] fs_inst;

//exception data: one clk delay to wait for all stage clear
        reg expt_clear_delay;
        reg [31:0] expt_refresh_pc_delay;
//如果有数据还未返还，设置该信号用于将其无效化
        reg inst_rd_invalid;        

        reg fs_tlbr_delay;
        reg fs_pif_delay;
        reg fs_ppi_delay;
        wire expt_adef;
        reg expt_adef_delay; //下一拍才完成pc等更新，且传递也最好传递delay
        reg inst_req_en; //保证事务不重叠
//考虑 IF ready go为1，即返回数据，但ds allowin为低的情形，需要暂存该inst
        reg [31:0] inst_buf;
        reg inst_buf_valid;

        always@(posedge clk)begin
        if(reset)
                inst_req_en<= 1'b1;
        else if(inst_sram_req & inst_sram_addr_ok)
                inst_req_en<= 1'b0;
        else if(inst_sram_data_ok)
                inst_req_en<= 1'b1;
        end

//addr_map signals
        //不考虑地址翻译相关例外的请求和原地址
        assign fs_req = to_fs_valid & fs_allowin & inst_req_en & ~br_stall & ~inst_buf_valid;
        assign fs_addr = nextpc;

        assign inst_sram_req  = fs_req & ~fs_tlbr & ~fs_pif & ~fs_ppi & ~expt_adef;
        assign inst_sram_wr   = 1'b0;
        assign inst_sram_size = 2'b10;
        assign inst_sram_addr = addr_map ? (fs_en_dmw ? {fs_dmw_pseg,fs_addr[28:0]} 
                                                      : (fs_ps == 6'd12 ? {fs_ppn,fs_addr[11:0]} 
                                                                        : {fs_ppn,fs_addr[21:0]}))
                                         : fs_addr ;
        assign inst_sram_wstrb = 4'b0;
        assign inst_sram_wdata= 32'b0;
        assign fs_inst = inst_buf_valid ? inst_buf : inst_sram_rdata;

        assign  to_fs_valid = ~reset;     

        //br stall进行阻塞判断，br taken则用于对取指地址进行选择
        assign  {br_stall,br_taken,br_target} = br_bus;

        always @(posedge clk) begin
                if(reset)
                        fs_valid <= 1'b0;
                else if(expt_clear)
                        fs_valid <= 1'b0;
                else if(inst_sram_req & inst_sram_addr_ok & ~inst_rd_invalid & fs_allowin)//请求握手后，下一拍会置为1，如果未进入下一级，则allowin拉低，不会再请求
                //请求握手后pc才更新，valid也才相应更新
                        fs_valid <= to_fs_valid;
                else if((expt_adef | fs_tlbr | fs_pif | fs_ppi) & fs_allowin) 
                        fs_valid <= to_fs_valid;
        end

        always @(posedge clk) begin
                if(reset)
                        inst_rd_invalid <= 1'b0;
                else if(expt_clear & inst_sram_req) //发生异常而数据还未返还
                        inst_rd_invalid <= 1'b1; //用于将所返还数据取消
                else if(inst_sram_data_ok)
                        inst_rd_invalid <= 1'b0; //下一拍才改变，则data ok拍不影响
        end
        
        //更改allowin相关判断条件，当流向下一级后即可allowin，再请求成功后拉低
        always @(posedge clk) begin
                if(reset)
                        fs_pass_delay <= 1'b0;
                else if(inst_sram_req & inst_sram_addr_ok & fs_allowin)
                        fs_pass_delay <= 1'b0;
                else if(ds_allowin&fs_ready_go)
                        fs_pass_delay <= 1'b1;

        end

        //当ready go拉高，allowin为低时，暂存指令
        always @(posedge clk) begin
                if(reset) 
                begin
                        inst_buf_valid <= 1'b0;
                        inst_buf <= 32'b0;
                end
                else if(fs_ready_go & ~ds_allowin)
                begin
                        inst_buf_valid <= 1'b1;
                        inst_buf <= inst_sram_rdata;
                end
                else if(fs_ready_go & ds_allowin) //成功进入，取消该缓存
                begin
                        inst_buf_valid <= 1'b0;
                        inst_buf <= 32'b0;
                end
        end

        assign  fs_allowin = ~fs_valid | (ds_allowin&fs_ready_go) | fs_pass_delay;
        //发生adef时也要传向下一级
        //接受到br_taken要进行访存，因此不能拉高br_taken
        assign  fs_ready_go = inst_sram_data_ok & ~(br_taken|br_taken_delay) & ~inst_rd_invalid 
                             | inst_buf_valid | expt_adef_delay | fs_tlbr_delay | fs_pif_delay | fs_ppi_delay;   
        //暂时取消br taken。数据握手下一拍还无指令要流向下一级
        assign  fs_to_ds_valid = fs_valid & fs_ready_go & ~expt_clear; // inst next branch is invalid
        assign  fs_to_ds_bus   = {
                                fs_tlbr_delay,
                                fs_pif_delay,
                                fs_ppi_delay,
                                expt_adef_delay,
                                fs_pc,
                                fs_inst
                                };

        always @(posedge clk)begin
                if(reset)
                        fs_pc <= 32'h1bfffffc;
                else if(inst_sram_req & inst_sram_addr_ok & ~inst_rd_invalid & fs_allowin) //请求握手成功再更新，防止本条指令被冲掉
                        fs_pc <= nextpc;
                else if((expt_adef | fs_tlbr | fs_pif | fs_ppi) & fs_allowin) // 下一拍更新成非对齐指令/出错地址后传递
                        fs_pc <= nextpc;
        end

        //考虑到异常清空流水线时，还有事务未完成，将会把请求拖延，因此不能仅延迟一拍
        always @(posedge clk) begin
                if(reset)
                        expt_clear_delay <= 1'b0;
                else if(expt_clear) begin
                        expt_clear_delay <= 1'b1;
                        expt_refresh_pc_delay <= expt_refresh_pc;
                end
                else if(inst_sram_req & inst_sram_addr_ok & ~inst_rd_invalid) //再次发起有效请求后才取消
                        expt_clear_delay <= 1'b0;
        end

        //考虑到返回数据后下一拍本该请求，但是addr_ok为低，应当保持br_taken信号，br_target会自动锁存
        //如果可以发起请求，就无需进行delay。同时，如果拉高，下一次请求成功后应当消除。因此，always条件具优先级
        always @(posedge clk) begin
                if(reset)
                        br_taken_delay <= 1'b0;
                else if(inst_sram_req & inst_sram_addr_ok)
                        br_taken_delay <= 1'b0;
                else if(br_taken) //需要对上述条件取反
                        br_taken_delay <= 1'b1;
        end

        assign nextpc = expt_clear_delay? expt_refresh_pc_delay :
                        br_taken|br_taken_delay        ? br_target: //实际取指时stall为低
                        fs_pc + 32'h4;

        //不对齐 或 无法通过DMW合法访问2^31 ~ 2^32-1
        assign expt_adef = fs_req & ((fs_addr[1:0] != 2'b0) |
                                     (fs_addr[31] & addr_map & ~fs_en_dmw));

        always@(posedge clk) begin
                if(reset)
                        expt_adef_delay <= 1'b0;
                else if(expt_adef)
                        expt_adef_delay <= 1'b1;
                else if(fs_ready_go & ds_allowin)
                        expt_adef_delay <= 1'b0;
        end
        always@(posedge clk) begin
                if(reset)
                        fs_tlbr_delay <= 1'b0;
                else if(fs_tlbr)
                        fs_tlbr_delay <= 1'b1;
                else if(fs_ready_go & ds_allowin)
                        fs_tlbr_delay <= 1'b0;
        end
        always@(posedge clk) begin
                if(reset)
                        fs_pif_delay <= 1'b0;
                else if(fs_pif)
                        fs_pif_delay <= 1'b1;
                else if(fs_ready_go & ds_allowin)
                        fs_pif_delay <= 1'b0;
        end
        always@(posedge clk) begin
                if(reset)
                        fs_ppi_delay <= 1'b0;
                else if(fs_ppi)
                        fs_ppi_delay <= 1'b1;
                else if(fs_ready_go & ds_allowin)
                        fs_ppi_delay <= 1'b0;
        end
endmodule 