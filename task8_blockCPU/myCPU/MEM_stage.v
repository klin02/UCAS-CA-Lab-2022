`include "macro.v"

module MEM_stage(
        input   clk,
        input   reset,

//from EX
        input   es_to_ms_valid,
        input [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
//to EX
        output  ms_allowin,

//from WB
        input   ws_allowin,
//to WB
        output  ms_to_ws_valid,
        output  [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,

//by-path forwarding data: to ID
        output [`MS_FW_BUS_WD-1:0] ms_fw_bus,

//data_sram interface
        input [31:0] data_sram_rdata
);

        reg [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus_tmp;
        wire [31:0] ms_pc;
        reg ms_valid;
        wire ms_ready_go;

        wire res_from_mem;
        wire gr_we;
        wire [4: 0] dest;
        wire [31:0] alu_result;

        wire [31:0] final_result;
        wire [31:0] mem_result;

always@(posedge clk)begin
        if(reset)
                es_to_ms_bus_tmp <= 71'b0;
        else if(ms_allowin & es_to_ms_valid)
                es_to_ms_bus_tmp <= es_to_ms_bus;
end
always@(posedge clk)begin
        if(reset)
                ms_valid <= 1'b0; 
        else if(ms_allowin)
                ms_valid <= es_to_ms_valid;
end

assign { ms_pc,
        res_from_mem,
        gr_we,
        dest,
        alu_result} = es_to_ms_bus_tmp;

assign ms_ready_go = 1'b1;
assign ms_allowin = ~ms_valid | (ws_allowin & ms_ready_go);
assign ms_to_ws_valid = ms_valid & ms_ready_go;

assign mem_result = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign ms_to_ws_bus = { ms_pc,          //32
                        gr_we,          //1
                        dest,           //5
                        final_result};  //32

//by-path fw bus
assign ms_fw_bus = {ms_valid & gr_we,dest};

endmodule