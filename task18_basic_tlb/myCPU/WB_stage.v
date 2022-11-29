`include "macro.v"

module WB_stage(
        input   clk,
        input   reset,

//from MEM
        input ms_to_ws_valid,
        input [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
//to MEM
        output ws_allowin,

//to RF(ID)
        output [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,

//by-path forwarding data: to ID
        output [`WS_FW_BUS_WD-1:0] ws_fw_bus,

//exception data --to IF
        output expt_clear,
        output [31:0] expt_refresh_pc,
//intr tag --to ID and csru
        output has_int,

//csru interface
        output [13:0] csr_num,
        input  [31:0] csr_rvalue,
        output        csr_we,
        output [31:0] csr_wmask,
        output [31:0] csr_wvalue,
        output        wb_ex,
        output        ertn_flush,
        output [ 5:0] wb_ecode,
        output [ 8:0] wb_esubcode,
        output [31:0] wb_pc,
        output [31:0] wb_vaddr,
        input  [31:0] wb_tid,
        input         csru_int,
        input  [31:0] ex_entry,
        input  [31:0] ertn_pc,

//to tlb-csru 
        output tlbrd,
        output tlbwr,
        output tlbfill,

//trace debug interface
        output [31:0] debug_wb_pc,
        output [ 3:0] debug_wb_rf_we,
        output [ 4:0] debug_wb_rf_wnum,
        output [31:0] debug_wb_rf_wdata
);
        reg [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_tmp;
        wire [31:0] ws_pc;
        reg ws_valid;
        wire ws_ready_go;

        wire gr_we;
        wire [4:0] dest;
        wire [31:0] final_result;
        
        wire        rf_we   ;
        wire [ 4:0] rf_waddr;
        wire [31:0] rf_wdata;

//addition exception data
        wire invtlb_op_nd;
        wire ws_tlbsrch_block;
        wire inst_tlbrd;
        wire inst_tlbwr;
        wire inst_tlbfill;
        wire refetch_tag;
        wire intr_tag;
        wire expt_adef;
        wire expt_ine;
        wire expt_ale;

        wire [8:0] expt_op;
        wire ws_csr;
        wire ws_expt;
        wire ws_tlb_refetch_tag;

//overall time cnter for rdcnt
        reg [63:0] ws_timer;

//except code: break rdcntid rdcntvl rdcntvh csrrd csrwr csrxchg syscall ertn
//               8      7       6       5      4     3      2       1     0
assign csr_we = ws_valid & (|expt_op[3:2]);
assign wb_ex = ws_valid & (expt_op[1] | expt_op[8] | intr_tag | invtlb_op_nd | expt_adef | expt_ine | expt_ale);
assign ertn_flush = ws_valid & expt_op[0];
assign wb_ecode = {6{intr_tag}}         & 6'h00 |
                  {6{expt_adef}}        & 6'h08 |
                  {6{expt_ale}}         & 6'h09 |
                  {6{expt_op[1]}}       & 6'h0b |  //syscall
                  {6{expt_op[8]}}       & 6'h0c |  //break
                  {6{expt_ine}}         & 6'h0d |
                  {6{invtlb_op_nd}}     & 6'h0d ;  //0x1a~0x3e 保留编码
assign wb_esubcode = {9{expt_adef}}     & 9'h000;
assign wb_pc = ws_pc;
assign wb_vaddr = final_result;
//output 
assign expt_clear = wb_ex | ertn_flush | refetch_tag;
//考虑到ertn返回地址非对齐，设置优先级
assign expt_refresh_pc = wb_ex ? ex_entry : ertn_flush? ertn_pc : refetch_tag ? ws_pc : 32'b0;
assign has_int = csru_int;

always@(posedge clk)begin
        if(reset)
                ms_to_ws_bus_tmp <= {`MS_TO_WS_BUS_WD{1'b0}};
        else if(ws_allowin & ms_to_ws_valid)
                ms_to_ws_bus_tmp <= ms_to_ws_bus;
end
always@(posedge clk)begin
        if(reset)
                ws_valid <= 1'b0;
        else if(expt_clear)
                ws_valid <= 1'b0; 
        else if(ws_allowin)
                ws_valid <= ms_to_ws_valid;
end

assign {
        invtlb_op_nd,
        ws_tlbsrch_block,
        inst_tlbrd,
        inst_tlbwr,
        inst_tlbfill,
        refetch_tag,
        intr_tag,       
        expt_adef,      
        expt_ine,       
        expt_ale,       
        expt_op,        
        csr_num,
        csr_wmask,
        csr_wvalue,
        ws_pc,
        gr_we,
        dest,
        final_result} = ms_to_ws_bus_tmp;

assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid | ws_ready_go;

always @(posedge clk)begin
        if(reset)
                ws_timer <= 64'b0;
        else    
                ws_timer <= ws_timer +1'b1;
end

//中断和重取标记可能标记到写寄存器指令
assign rf_we = gr_we & ws_valid & ~expt_adef & ~expt_ale & ~expt_ine & ~intr_tag & ~refetch_tag;
assign rf_waddr = dest;
assign rf_wdata = |expt_op[4:2] ? csr_rvalue :     //csr
                  expt_op[5]    ? ws_timer[63:32] : //rdcntvh
                  expt_op[6]    ? ws_timer[31:0]  : //rdcntvl
                  expt_op[7]    ? wb_tid :
                  final_result;

assign ws_to_rf_bus = {rf_we,rf_waddr,rf_wdata}; //1+5+32
//debug info
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest;
assign debug_wb_rf_wdata = rf_wdata;

//by-path fw bus
assign ws_tlb_refetch_tag = ws_valid & (inst_tlbrd | inst_tlbwr | inst_tlbfill);
assign ws_csr = ws_valid & (|expt_op[7:2]); //csrrd csrwr csrxchg rdcnt
assign ws_expt = ws_valid & ((|expt_op[1:0]) | expt_op[8] | intr_tag | refetch_tag | invtlb_op_nd | expt_adef | expt_ine | expt_ale); 
        //syscall ertn / break / intr ade ine ale
assign ws_fw_bus = {ws_valid & ws_tlbsrch_block, ws_tlb_refetch_tag,
                    ws_csr,ws_expt, ws_valid & gr_we,dest,rf_wdata};

//tlb-csru control signal
assign tlbrd = ws_valid & inst_tlbrd;
assign tlbwr = ws_valid & inst_tlbwr;
assign tlbfill = ws_valid & inst_tlbfill;
endmodule