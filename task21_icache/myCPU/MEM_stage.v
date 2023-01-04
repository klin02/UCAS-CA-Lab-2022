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
        input  wire        data_sram_data_ok,
        input  wire [31:0] data_sram_rdata,

//exception data
        input expt_clear
);

        reg [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus_tmp;
        wire [31:0] ms_pc;
        reg ms_valid;
        wire ms_ready_go;

        wire is_ld_st;
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

//exception data
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
        wire ms_tlbsrch_block;
        wire inst_tlbrd;
        wire inst_tlbwr;
        wire inst_tlbfill;
        wire refetch_tag;
        wire intr_tag;
        wire expt_adef;
        wire expt_ine;
        wire expt_ale;

        wire [8:0] expt_op;
        wire [13:0] csr_num;
        wire [31:0] csr_wmask;
        wire [31:0] csr_wvalue;
        wire ms_tlb_refetch_tag;
        wire ms_csr;
        wire ms_expt;

always@(posedge clk)begin
        if(reset)
                es_to_ms_bus_tmp <= {`ES_TO_MS_BUS_WD{1'b0}};
        else if(ms_allowin & es_to_ms_valid)
                es_to_ms_bus_tmp <= es_to_ms_bus;
end
always@(posedge clk)begin
        if(reset)
                ms_valid <= 1'b0;
        else if(expt_clear)
                ms_valid <= 1'b0; 
        else if(ms_allowin)
                ms_valid <= es_to_ms_valid;
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
        ms_tlbsrch_block,
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
        is_ld_st,
        load_op,
        ms_pc,
        res_from_mem,
        gr_we,
        dest,
        alu_result} = es_to_ms_bus_tmp;

assign load_offset = alu_result[1:0];
assign ms_ready_go = ~is_ld_st | (is_ld_st & (data_sram_data_ok | ms_expt));
assign ms_allowin = ~ms_valid | (ws_allowin & ms_ready_go);
assign ms_to_ws_valid = ms_valid & ms_ready_go & ~expt_clear; 

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
assign final_result = res_from_mem & ~expt_ale & ~expt_adem & ~es_tlbr & ~es_pil & ~es_pis & ~es_pme & ~es_ppi? 
                        mem_result : alu_result;
        //when expt_ale happen. ld will not work, so mem_result is useless. final result is overuserd by vaddr

assign ms_to_ws_bus = { 
                        expt_adem,
                        es_tlbr,
                        es_pil,
                        es_pis,
                        es_pme,
                        es_ppi,
                        fs_tlbr,
                        fs_pif,
                        fs_ppi,
                        invtlb_op_nd,   //1
                        ms_tlbsrch_block,//1
                        inst_tlbrd,     //1
                        inst_tlbwr,     //1
                        inst_tlbfill,   //1
                        refetch_tag,    //1
                        intr_tag,       //1
                        expt_adef,      //1
                        expt_ine,       //1
                        expt_ale,       //1
                        expt_op,        //9
                        csr_num,        //14
                        csr_wmask,      //32
                        csr_wvalue,      //32
                        ms_pc,          //32
                        gr_we,          //1
                        dest,           //5
                        final_result};  //32    //vaddr when expt_ale happen

//by-path fw bus
assign ms_tlb_refetch_tag = ms_valid & (inst_tlbrd | inst_tlbwr | inst_tlbfill);
assign ms_csr = ms_valid & (|expt_op[7:2]); //csrrd csrwr csrxchg rdcnt
assign ms_expt = ms_valid & ((|expt_op[1:0]) | expt_op[8] | intr_tag | refetch_tag | invtlb_op_nd 
                              | expt_adef | expt_ine | expt_ale
                              | fs_tlbr | fs_pif | fs_ppi
                              | es_tlbr | es_pil | es_pis | es_pme | es_ppi | expt_adem); 
        //syscall ertn / break / intr ade ine ale 
assign ms_fw_bus = {ms_valid & ms_tlbsrch_block, ms_tlb_refetch_tag,
                   ms_csr,ms_expt,ms_valid & gr_we & res_from_mem,
                   is_ld_st & data_sram_data_ok,ms_valid & gr_we,dest,final_result};

endmodule