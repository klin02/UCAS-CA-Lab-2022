`include "macro.v"

module EX_stage(
        input   clk,
        input   reset,

//from ID
        input   ds_to_es_valid,
        input [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
//to ID
        output  es_allowin,

//from MEM
        input   ms_allowin,
//to MEM
        output  es_to_ms_valid,
        output [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,

//by-path forwarding data: to ID
        output [`ES_FW_BUS_WD-1:0] es_fw_bus,

//data_sram interface. save a clk for mem stage
        output data_sram_en,
        output [3:0] data_sram_we,
        output [31:0] data_sram_addr,
        output [31:0] data_sram_wdata,

//exception data
        input expt_clear
);
        reg [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus_tmp;
        wire [31:0] es_pc;
        reg  es_valid;
        wire es_ready_go;

        wire [4:0] expt_op;
        wire [13:0] csr_num;
        wire [14:0] expt_code;
        wire [4:0] load_op;
        wire [2:0] store_op;
        wire res_from_mem;
        wire gr_we;
        wire mem_we;
        wire [`ALU_OP_WD-1:0] alu_op;
        wire [4: 0] dest;
        wire [31:0] alu_src1   ;
        wire [31:0] alu_src2   ;
        wire [31:0] rkd_value;

        wire [31:0] alu_result ;
        wire div_block;
        wire div_out_valid;

        wire [31:0] store_data;
        wire [3:0] st_b_we;
        wire [3:0] st_h_we;
        wire [3:0] st_w_we;
//csr block fw data
        wire es_csr;
        wire es_expt;
//to MS: exception data
        wire [31:0] csr_wmask;
        wire [31:0] csr_wvalue;

alu u_alu(
    .clk        (clk),
    .reset      (reset),
    .es_valid   (es_valid),
    .div_out_valid(div_out_valid),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),   
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

always@(posedge clk)begin
        if(reset)
                ds_to_es_bus_tmp <= 197'b0;
        else if(es_allowin & ds_to_es_valid)
                ds_to_es_bus_tmp <= ds_to_es_bus;
end
always@(posedge clk)begin
        if(reset)
                es_valid <= 1'b0; 
        else if(expt_clear)
                es_valid <= 1'b0;
        else if(es_allowin)
                es_valid <= ds_to_es_valid;
end

assign  { 
        expt_op,
        csr_num,
        expt_code,
        load_op,
        store_op,
        es_pc,
        res_from_mem,
        gr_we,
        mem_we,
        alu_op,
        dest,
        alu_src1,
        alu_src2,
        rkd_value
        } = ds_to_es_bus_tmp;    

//aluop 15-18 is div related
assign div_block = es_valid & (|alu_op[18:15]) & ~div_out_valid;
assign es_ready_go = ~div_block;
assign es_allowin = ~es_valid | (ms_allowin & es_ready_go);
assign es_to_ms_valid = es_valid & es_ready_go & ~expt_clear;

//csrxchg rj_value csrwr 32h'ffffffff
assign csr_wmask = expt_op[2] ? alu_src1 : 32'hffffffff;
assign csr_wvalue = alu_src2;
assign es_to_ms_bus = { 
                        expt_op,        //5
                        csr_num,        //14
                        expt_code,      //15
                        csr_wmask,      //32
                        csr_wvalue,      //32
                        load_op,        //5
                        es_pc,          //32
                        res_from_mem,   //1
                        gr_we,          //1
                        dest,           //5     //rf waddr when csr read
                        alu_result};    //32

//by-path fw bus
        //load op: gr_we & res_from mem
        //include csr forward block data
assign es_csr = es_valid & (|expt_op[4:2]); //csrrd csrwr csrxchg
assign es_expt = es_valid & (|expt_op[1:0]); //syscall ertn
assign es_fw_bus = { es_csr,es_expt,es_valid & gr_we & res_from_mem, es_valid & gr_we, dest, alu_result};

//load: gr_we & res_from_mem
assign data_sram_en = ((gr_we & res_from_mem) | mem_we) & es_valid;

assign st_b_we = {  alu_result[1] &  alu_result[0] ,
                    alu_result[1] & ~alu_result[0] ,
                   ~alu_result[1] &  alu_result[0] ,
                   ~alu_result[1] & ~alu_result[0] 
                 };
assign st_h_we = { {2{alu_result[1]}}, {2{~alu_result[1]}} };
assign st_w_we = 4'b1111;
assign data_sram_we = {4{store_op[2]}} & st_b_we |
                      {4{store_op[1]}} & st_h_we |
                      {4{store_op[0]}} & st_w_we ;

assign data_sram_addr = alu_result;

assign store_data = {32{store_op[2]}} & {4{rkd_value[7:0]}} | 
                    {32{store_op[1]}} & {2{rkd_value[15:0]}} | 
                    {32{store_op[0]}} & rkd_value ;
assign data_sram_wdata = store_data;

endmodule        