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
        wire expt_adem;
        wire es_tlbr;
        wire es_pil;
        wire es_pis;
        wire es_pme;
        wire es_ppi;
        wire fs_tlbr;
        wire fs_pif;
        wire fs_ppi;
        wire invtlb_op_nd;
        wire ws_tlbsrch_block;
        wire inst_tlbrd;
        wire inst_tlbwr;
        wire inst_tlbfill;
        wire refetch_tag;
        wire refetch_tag_org;
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
assign wb_ex = ws_valid & (expt_op[1] | expt_op[8] | intr_tag | invtlb_op_nd 
                          | expt_adef | expt_ine | expt_ale
                          | fs_tlbr | fs_pif | fs_ppi
                          | es_tlbr | es_pil | es_pis | es_pme | es_ppi | expt_adem); 
assign ertn_flush = ws_valid & expt_op[0];
assign wb_ecode = {6{intr_tag}}         & `ECODE_INT |
                  {6{expt_adef}}        & `ECODE_ADE |
                  {6{expt_ale}}         & `ECODE_ALE |
                  {6{expt_op[1]}}       & `ECODE_SYS |  //syscall
                  {6{expt_op[8]}}       & `ECODE_BRK |  //break
                  {6{expt_ine}}         & `ECODE_INE |
                  {6{invtlb_op_nd}}     & `ECODE_INE |  //0x1a~0x3e 保留编码
                  {6{es_pil}}           & `ECODE_PIL |
                  {6{es_pis}}           & `ECODE_PIS | 
                  {6{fs_pif}}           & `ECODE_PIF |
                  {6{es_pme}}           & `ECODE_PME |
                  {6{fs_ppi | es_ppi}}  & `ECODE_PPI |
                  {6{expt_adem}}        & `ECODE_ADE |
                  {6{fs_tlbr|es_tlbr}}  & `ECODE_TLBR;
assign wb_esubcode = {9{expt_adef}}     & `ESUBCODE_ADEF |
                     {9{expt_adem}}     & `ESUBCODE_ADEM ;
assign wb_pc = ws_pc;
assign wb_vaddr = expt_adef | fs_pif | fs_ppi | fs_tlbr ? ws_pc : final_result;
//output 
assign refetch_tag = ws_valid & refetch_tag_org;
assign expt_clear = wb_ex | ertn_flush | refetch_tag;
//考虑到ertn返回地址非对齐，设置优先级
//ex entry在csru内部考虑tlbr例外
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
        expt_adem,
        es_tlbr,
        es_pil,
        es_pis,
        es_pme,
        es_ppi,
        fs_tlbr,
        fs_pif,
        fs_ppi,
        invtlb_op_nd,
        ws_tlbsrch_block,
        inst_tlbrd,
        inst_tlbwr,
        inst_tlbfill,
        refetch_tag_org,
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
assign rf_we = gr_we & ws_valid & ~ws_expt;
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
assign ws_expt = ws_valid & ((|expt_op[1:0]) | expt_op[8] | intr_tag | refetch_tag | invtlb_op_nd 
                              | expt_adef | expt_ine | expt_ale
                              | fs_tlbr | fs_pif | fs_ppi
                              | es_tlbr | es_pil | es_pis | es_pme | es_ppi | expt_adem); 
        //syscall ertn / break / intr ade ine ale
assign ws_fw_bus = {ws_valid & ws_tlbsrch_block, ws_tlb_refetch_tag,
                    ws_csr,ws_expt, ws_valid & gr_we,dest,rf_wdata};

//tlb-csru control signal
assign tlbrd = ws_valid & inst_tlbrd;
assign tlbwr = ws_valid & inst_tlbwr;
assign tlbfill = ws_valid & inst_tlbfill;
endmodule