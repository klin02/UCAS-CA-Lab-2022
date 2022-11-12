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
//intr tag --to ID
        output has_int,
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

//csru interface
        wire [13:0]  csr_num;
        wire [31:0] csr_rvalue;
        wire   csr_we;
        wire [31:0]  csr_wmask;
        wire [31:0]  csr_wvalue;
        wire wb_ex;
        wire ertn_flush;
        wire [5:0] wb_ecode;
        wire [8:0] wb_esubcode;
        wire [31:0] wb_pc;
        wire [31:0] wb_vaddr;
        wire [31:0] wb_tid;
        wire [31:0] ex_entry;
        wire [31:0] ertn_pc;
//addition exception data
        wire intr_tag;
        wire expt_adef;
        wire expt_ine;
        wire expt_ale;

        wire [8:0] expt_op;
        wire ws_csr;
        wire ws_expt;

//overall time cnter for rdcnt
        reg [63:0] ws_timer;

//except code: break rdcntid rdcntvl rdcntvh csrrd csrwr csrxchg syscall ertn
//               8      7       6       5      4     3      2       1     0
assign csr_we = ws_valid & (|expt_op[3:2]);
assign wb_ex = ws_valid & (expt_op[1] | expt_op[8] | intr_tag | expt_adef | expt_ine | expt_ale);
assign ertn_flush = ws_valid & expt_op[0];
assign wb_ecode = {6{intr_tag}}         & 6'h00 |
                  {6{expt_adef}}        & 6'h08 |
                  {6{expt_ale}}         & 6'h09 |
                  {6{expt_op[1]}}       & 6'h0b |  //syscall
                  {6{expt_op[8]}}       & 6'h0c |  //break
                  {6{expt_ine}}         & 6'h0d ;
assign wb_esubcode = {9{expt_adef}}     & 9'h000;
assign wb_pc = ws_pc;
assign wb_vaddr = final_result;
//output 
assign expt_clear = wb_ex | ertn_flush;
//考虑到ertn返回地址非对齐，设置优先级
assign expt_refresh_pc = wb_ex ? ex_entry : ertn_flush? ertn_pc : 32'b0;

csru u_csru(
        .clk            (clk),
        .reset          (reset),
        .csr_num        (csr_num),
        .csr_rvalue     (csr_rvalue),
        .csr_we         (csr_we),
        .csr_wmask      (csr_wmask),
        .csr_wvalue     (csr_wvalue),
        .wb_ex          (wb_ex),
        .ertn_flush     (ertn_flush),
        .wb_ecode       (wb_ecode),
        .wb_esubcode    (wb_esubcode),
        .wb_pc          (wb_pc),
        .wb_vaddr       (wb_vaddr),
        .wb_tid         (wb_tid),
        .has_int        (has_int),
        .ex_entry       (ex_entry),
        .ertn_pc        (ertn_pc)
);

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

assign rf_we = gr_we & ws_valid & ~expt_adef & ~expt_ale & ~expt_ine;
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
assign ws_csr = ws_valid & (|expt_op[7:2]); //csrrd csrwr csrxchg rdcnt
assign ws_expt = ws_valid & ((|expt_op[1:0]) | expt_op[8] | intr_tag | expt_adef | expt_ine | expt_ale); 
        //syscall ertn / break / intr ade ine ale
assign ws_fw_bus = {ws_csr,ws_expt, ws_valid & gr_we,dest,rf_wdata};

endmodule