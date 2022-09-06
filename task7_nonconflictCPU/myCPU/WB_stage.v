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

always@(posedge clk)begin
        if(reset)
                ms_to_ws_bus_tmp <= 70'b0;
        else if(ws_allowin & ms_to_ws_valid)
                ms_to_ws_bus_tmp <= ms_to_ws_bus;
end
always@(posedge clk)begin
        if(reset)
                ws_valid <= 1'b0; 
        else if(ws_allowin)
                ws_valid <= ms_to_ws_valid;
end

assign {ws_pc,gr_we,dest,final_result} = ms_to_ws_bus_tmp;

assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid | ws_ready_go;

assign rf_we = gr_we & ws_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

assign ws_to_rf_bus = {rf_we,rf_waddr,rf_wdata}; //1+5+32
//debug info
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest;
assign debug_wb_rf_wdata = final_result;

endmodule