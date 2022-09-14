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

//exception data
        output expt_clear,
        output [31:0] expt_refresh_pc,

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
        wire [31:0] ex_entry;
        wire [31:0] ertn_pc;
//addition exception data
        wire [4:0] expt_op;
        wire [14:0] expt_code;
        wire ws_csr;
        wire ws_expt;

//except code: csrrd csrwr csrxchg syscall ertn
//               4     3      2       1     0
assign csr_we = ws_valid & (|expt_op[3:2]);
assign wb_ex = ws_valid & expt_op[1];
assign ertn_flush = ws_valid & expt_op[0];
//assign {wb_esubcode,wb_ecode} = expt_code;
assign wb_ecode = expt_op[1] ? 6'hb : 6'h0;
assign wb_esubcode = 9'h0;
assign wb_pc = ws_pc;
//output 
assign expt_clear = wb_ex | ertn_flush;
assign expt_refresh_pc = {32{wb_ex}} & ex_entry | 
                         {32{ertn_flush}} & ertn_pc;

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
        .ex_entry       (ex_entry),
        .ertn_pc        (ertn_pc)
);

always@(posedge clk)begin
        if(reset)
                ms_to_ws_bus_tmp <= 168'b0;
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

assign {expt_op,
        csr_num,
        expt_code,
        csr_wmask,
        csr_wvalue,
        ws_pc,
        gr_we,
        dest,
        final_result} = ms_to_ws_bus_tmp;

assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid | ws_ready_go;

assign rf_we = gr_we & ws_valid;
assign rf_waddr = dest;
assign rf_wdata = ws_csr ? csr_rvalue : final_result;

assign ws_to_rf_bus = {rf_we,rf_waddr,rf_wdata}; //1+5+32
//debug info
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest;
assign debug_wb_rf_wdata = rf_wdata;

//by-path fw bus
assign ws_csr = ws_valid & (|expt_op[4:2]); //csrrd csrwr csrxchg
assign ws_expt = ws_valid & (|expt_op[1:0]); //syscall ertn
assign ws_fw_bus = {ws_csr,ws_expt, ws_valid & gr_we,dest,rf_wdata};

endmodule