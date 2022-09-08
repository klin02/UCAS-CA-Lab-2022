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

        wire [4:0]  load_op;
        wire res_from_mem;
        wire gr_we;
        wire [4: 0] dest;
        wire [31:0] alu_result;

        wire [1:0]  load_offset;
        wire [31:0] ld_b_result;
        wire [31:0] ld_h_result;
        wire [31:0] ld_w_result;
        wire [31:0] ld_bu_result;
        wire [31:0] ld_hu_result;
        wire [31:0] final_result;
        wire [31:0] mem_result;

always@(posedge clk)begin
        if(reset)
                es_to_ms_bus_tmp <= 76'b0;
        else if(ms_allowin & es_to_ms_valid)
                es_to_ms_bus_tmp <= es_to_ms_bus;
end
always@(posedge clk)begin
        if(reset)
                ms_valid <= 1'b0; 
        else if(ms_allowin)
                ms_valid <= es_to_ms_valid;
end

assign { 
        load_op,
        ms_pc,
        res_from_mem,
        gr_we,
        dest,
        alu_result} = es_to_ms_bus_tmp;

assign load_offset = alu_result[1:0];
assign ms_ready_go = 1'b1;
assign ms_allowin = ~ms_valid | (ws_allowin & ms_ready_go);
assign ms_to_ws_valid = ms_valid & ms_ready_go;

//assign mem_result = data_sram_rdata;
assign ld_b_result = {32{load_offset == 2'b00}} & {{24{data_sram_rdata[ 7]}},data_sram_rdata[ 7: 0]} | 
                     {32{load_offset == 2'b01}} & {{24{data_sram_rdata[15]}},data_sram_rdata[15: 8]} | 
                     {32{load_offset == 2'b10}} & {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]} | 
                     {32{load_offset == 2'b11}} & {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]} ;
assign ld_h_result = {32{load_offset[1] == 1'b0}} & {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]} | 
                     {32{load_offset[1] == 1'b1}} & {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]} ;
assign ld_w_result = data_sram_rdata;
assign ld_bu_result = {32{load_offset == 2'b00}} & {24'b0,data_sram_rdata[ 7: 0]} | 
                      {32{load_offset == 2'b01}} & {24'b0,data_sram_rdata[15: 8]} | 
                      {32{load_offset == 2'b10}} & {24'b0,data_sram_rdata[23:16]} | 
                      {32{load_offset == 2'b11}} & {24'b0,data_sram_rdata[31:24]} ;
assign ld_hu_result = {32{load_offset[1] == 1'b0}} & {16'b0,data_sram_rdata[15:0]} | 
                      {32{load_offset[1] == 1'b1}} & {16'b0,data_sram_rdata[31:16]} ;

assign mem_result = {32{load_op[4]}} & ld_b_result |
                    {32{load_op[3]}} & ld_h_result |
                    {32{load_op[2]}} & ld_w_result |
                    {32{load_op[1]}} & ld_bu_result |
                    {32{load_op[0]}} & ld_hu_result ;
assign final_result = res_from_mem ? mem_result : alu_result;

assign ms_to_ws_bus = { ms_pc,          //32
                        gr_we,          //1
                        dest,           //5
                        final_result};  //32

//by-path fw bus
assign ms_fw_bus = {ms_valid & gr_we,dest,final_result};

endmodule