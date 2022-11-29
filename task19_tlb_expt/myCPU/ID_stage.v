`include "macro.v"

module ID_stage(
        input   clk,
        input   reset,

//from IF
        input   fs_to_ds_valid,
        input [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
//to IF
        output  ds_allowin,
        output [`BR_BUS_WD-1:0] br_bus,

//from EX
        input   es_allowin,
//to EX
        output  ds_to_es_valid,
        output [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,

//from WB
        input [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,

//from EX,MEM,WB: by-path fowarding data, include csr block data
        input [`ES_FW_BUS_WD-1:0] es_fw_bus,
        input [`MS_FW_BUS_WD-1:0] ms_fw_bus,
        input [`WS_FW_BUS_WD-1:0] ws_fw_bus,

//exception data
        input expt_clear,
        input has_int
);
        
        reg [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus_tmp;
        wire [31:0] ds_pc;
        wire [31:0] ds_inst;

        wire fs_tlbr;
        wire fs_pif;
        wire fs_ppi;
//expection data -- pro
        wire expt_adef;
        wire expt_ine;
        wire rdcnt_dst_is_rj;
        wire intr_tag; //get from WB
//branch bus
        wire br_stall; //表示本条为br指令，且还未计算完
        wire br_taken; //表示本条为br指令，且计算结果是跳转
        wire[31:0] br_target;
//ds_to_es_bus  
        //basic tlb
        wire [4:0] invtlb_op;
        //basic exception
        wire [8:0] expt_op;     //add 4 bit for break and rdcnt
        wire [13:0] csr_num;
        wire [4:0] load_op;
        wire [2:0] store_op;
        wire res_from_mem;
        wire gr_we;
        wire mem_we;
        wire [`ALU_OP_WD-1:0] alu_op;  //add 7 bit for mul and div
        wire [4: 0] dest;
        wire [31:0] alu_src1   ;
        wire [31:0] alu_src2   ;
        wire [31:0] rkd_value;

//decode signals
        wire        src1_is_pc;
        wire        src2_is_imm;
        wire        dst_is_r1;
        wire        src_reg_is_rd;
        wire [31:0] rj_value;
        wire [31:0] imm;
        wire [31:0] br_offs;
        wire [31:0] jirl_offs;
//blu related signals
        wire [`BLU_OP_WD-1:0] blu_op;
        wire [31:0] blu_src1;
        wire [31:0] blu_src2;
        wire blu_result;

        wire [ 5:0] op_31_26;
        wire [ 3:0] op_25_22;
        wire [ 1:0] op_21_20;
        wire [ 4:0] op_19_15;
        wire [ 4:0] rd;
        wire [ 4:0] rj;
        wire [ 4:0] rk;
        wire [11:0] i12;
        wire [19:0] i20;
        wire [15:0] i16;
        wire [25:0] i26;


        wire [63:0] op_31_26_d;
        wire [15:0] op_25_22_d;
        wire [ 3:0] op_21_20_d;
        wire [31:0] op_19_15_d;

        wire        inst_add_w;
        wire        inst_sub_w;
        wire        inst_slt;
        wire        inst_sltu;
        wire        inst_nor;
        wire        inst_and;
        wire        inst_or;
        wire        inst_xor;
        wire        inst_slli_w;
        wire        inst_srli_w;
        wire        inst_srai_w;
        wire        inst_addi_w;
        wire        inst_ld_w;
        wire        inst_st_w;
        wire        inst_jirl;
        wire        inst_b;
        wire        inst_bl;
        wire        inst_beq;
        wire        inst_bne;
        wire        inst_lu12i_w;
// task10: pro calc
        wire        inst_slti;
        wire        inst_sltui;
        wire        inst_andi;
        wire        inst_ori;
        wire        inst_xori;
        wire        inst_sll_w;
        wire        inst_srl_w;
        wire        inst_sra_w;
        wire        inst_pcaddu12i;
        wire        inst_mul_w;
        wire        inst_mulh_w;
        wire        inst_mulh_wu;
        wire        inst_div_w;
        wire        inst_mod_w;
        wire        inst_div_wu;
        wire        inst_mod_wu;
//pro br
        wire        inst_blt;
        wire        inst_bge;
        wire        inst_bltu;
        wire        inst_bgeu;
//pro ls
        wire        inst_ld_b;
        wire        inst_ld_h;
        wire        inst_ld_bu;
        wire        inst_ld_hu;
        wire        inst_st_b;
        wire        inst_st_h;
//basic exception
        wire        inst_syscall;
        wire        inst_csrrd;
        wire        inst_csrwr;
        wire        inst_csrxchg;
        wire        inst_ertn;
//pro exception
        wire        inst_break; 
        wire        inst_rdcntid_w;
        wire        inst_rdcntvl_w;
        wire        inst_rdcntvh_w;
//basic tlb
        wire        inst_tlbsrch;
        wire        inst_tlbrd;
        wire        inst_tlbwr;
        wire        inst_tlbfill;
        wire        inst_invtlb;

        wire        need_ui5;
        wire        need_si12;
        wire        need_si16;
        wire        need_si20;
        wire        need_si26;
        wire        src2_is_4;
//pro calc
        wire        need_ui12;

        wire [ 4:0] rf_raddr1;
        wire [31:0] rf_rdata1;
        wire [ 4:0] rf_raddr2;
        wire [31:0] rf_rdata2;
//following signals is from WB
        wire        rf_we   ;
        wire [ 4:0] rf_waddr;
        wire [31:0] rf_wdata;

//control unit
        reg ds_valid;
        wire ds_ready_go;

//fw related signals
        wire es_vload; //valid load
        wire es_fw_vwe; //valid we
        wire [4:0] es_fw_dest;
        wire [31:0] es_fw_wdata;
        wire ms_fw_vwe;
        wire ms_vload;
        wire ms_rd_ok;
        wire [4:0] ms_fw_dest;
        wire [31:0] ms_fw_wdata;
        wire ws_fw_vwe;
        wire [4:0] ws_fw_dest;
        wire [31:0] ws_fw_wdata;
//signals to save useless block
        wire raddr1_valid;
        wire raddr2_valid;
//when using forward, only es_load will cause a block
        wire es_block;
        wire ms_block;
        wire usr_block;
//block caused by csr read after write or expt
        wire csr_block;
        wire es_csr_block;
        wire ms_csr_block;
        wire ws_csr_block;
        wire expt_block;
        wire es_csr;  //dest will be cover in gr fw dest, include csrrd and csrxchg
        wire ms_csr;
        wire ws_csr;
        wire es_expt;   //sycall or ertn
        wire ms_expt;
        wire ws_expt;
//tlb srch block, caused by csrwr or csrxchg(change asid or tlbehi) and tlbrd
//the block signal will be generated at ID stage, but only signal from forwarding stage works
        wire ds_tlbsrch_block;
        wire tlbsrch_block;
        wire es_tlbsrch_block;
        wire ms_tlbsrch_block;
        wire ws_tlbsrch_block;
//tlb refetch mark, generated by tlbrd tlbwr tlbfill invtlb
        wire es_tlb_refetch_tag;
        wire ms_tlb_refetch_tag;
        wire ws_tlb_refetch_tag;
        wire refetch_tag;
//invtlb op undefined also as a kind of expt
        wire invtlb_op_nd;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];
//basic exception
assign csr_num = ds_inst[23:10];
//basic tlb
assign invtlb_op = ds_inst[4:0];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
//task10: pro calc
assign inst_slti        = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui       = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi        = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori         = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori        = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i   = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_mul_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//pro br
assign inst_blt         = op_31_26_d[6'h18];
assign inst_bge         = op_31_26_d[6'h19];
assign inst_bltu        = op_31_26_d[6'h1a];
assign inst_bgeu        = op_31_26_d[6'h1b];
//pro ls
assign inst_ld_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu       = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu       = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
//basic exception
assign inst_syscall     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_csrrd       = op_31_26_d[6'h01] & ~(|ds_inst[25:24]) & ~(|ds_inst[9:6]) & ~ds_inst[5];
assign inst_csrwr       = op_31_26_d[6'h01] & ~(|ds_inst[25:24]) & ~(|ds_inst[9:6]) &  ds_inst[5];
assign inst_csrxchg     = op_31_26_d[6'h01] & ~(|ds_inst[25:24]) &  (|ds_inst[9:6]);
assign inst_ertn        = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01110);
//pro exception
assign inst_break       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntid_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11000) & ~(|ds_inst[4:0]); 
assign inst_rdcntvl_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11000) & ~(|ds_inst[9:5]);
assign inst_rdcntvh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11001) & ~(|ds_inst[9:5]);
//basic tlb
assign inst_tlbsrch     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01010) & ~(|ds_inst[9:0]);
assign inst_tlbrd       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01011) & ~(|ds_inst[9:0]);
assign inst_tlbwr       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01100) & ~(|ds_inst[9:0]);
assign inst_tlbfill     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01101) & ~(|ds_inst[9:0]);
assign inst_invtlb      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

//>= 0x7 00111
assign invtlb_op_nd = inst_invtlb & ((|invtlb_op[4:3]) | (&invtlb_op[2:0]));

assign expt_ine = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor | inst_slli_w | inst_srli_w | 
                    inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w |
                    inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddu12i | inst_mul_w |
                    inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu |
                    inst_blt | inst_bge | inst_bltu | inst_bgeu |
                    inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h |
                    inst_syscall | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn |
                    inst_break | inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w |
                    inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb)
                & ~(expt_adef | fs_tlbr | fs_pif | fs_ppi);

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i
                    | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h ; // pro ls
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui 
                   | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h ; // pro ls
assign need_si16  =  inst_jirl | inst_beq | inst_bne 
                   | inst_blt | inst_bge | inst_bltu | inst_bgeu; //pro br
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
//pro calc
assign need_ui12  =  inst_andi | inst_ori | inst_xori;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {20'b0,i12[11:0]}          : // pro calc
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                /*need_si16*/{{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w 
                     | inst_blt | inst_bge | inst_bltu | inst_bgeu //pro br
                     | inst_st_b | inst_st_h                       //pro ls
                     | inst_csrwr | inst_csrxchg;                  //basic exception

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   | //pro calc
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i |
                       inst_ld_b |   //pro ls
                       inst_ld_h | 
                       inst_ld_bu | 
                       inst_ld_hu | 
                       inst_st_b | 
                       inst_st_h  ;

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu ; //pro ls
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b 
                     & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu //pro br
                     & ~inst_st_b & ~inst_st_h                         //pro ls
                     & ~inst_syscall & ~inst_ertn        //basic exception 
                     & ~inst_break
                     & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb;                                    //pro exception
assign mem_we        = inst_st_w | inst_st_b | inst_st_h ;
assign rdcnt_dst_is_rj = inst_rdcntid_w; //pro
assign dest          =  dst_is_r1 ? 5'd1 :              //overuse by rdcnt
                        rdcnt_dst_is_rj? rj: 
                        rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

//blu: branch logic unit: judge whether br is valid
blu u_blu(
        .blu_op (blu_op),
        .blu_src1 (blu_src1),
        .blu_src2 (blu_src2),
        .blu_result (blu_result)
);

assign blu_op = {inst_beq,inst_bne,inst_blt,inst_bge,inst_bltu,inst_bgeu};
assign blu_src1 = rj_value;
assign blu_src2 = rkd_value;
assign br_stall = (|blu_op) & ds_valid & (usr_block | csr_block);
assign br_taken =  ( ((|blu_op) & blu_result) //6 kind of br
                   | inst_jirl
                   | inst_bl
                   | inst_b) & ds_valid & ~br_stall; //bug1
assign br_target = (inst_beq | inst_bne | inst_bl | inst_b | inst_blt | inst_bge | inst_bltu | inst_bgeu) ? (ds_pc + br_offs) :   
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign br_bus = {br_stall,br_taken,br_target};

assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign {rf_we,rf_waddr,rf_wdata} = ws_to_rf_bus;
assign {
        fs_tlbr,
        fs_pif,
        fs_ppi,
        expt_adef,
        ds_pc,
        ds_inst} = fs_to_ds_bus_tmp;
always@(posedge clk)begin
        if(reset)
                fs_to_ds_bus_tmp <= {`FS_TO_DS_BUS_WD{1'b0}};
        else if(ds_allowin & fs_to_ds_valid)
                fs_to_ds_bus_tmp <= fs_to_ds_bus;
end
always@(posedge clk)begin
        if(reset)
                ds_valid <= 1'b0; 
        else if(expt_clear)
                ds_valid <= 1'b0;
        else if(ds_allowin)
                ds_valid <= fs_to_ds_valid;
end
assign ds_ready_go = ~usr_block & ~csr_block & ~expt_block & ~tlbsrch_block;
assign ds_allowin = ~ds_valid | (ds_ready_go & es_allowin);
assign ds_to_es_valid = ds_valid & ds_ready_go & ~expt_clear;

assign load_op = {inst_ld_b,inst_ld_h,inst_ld_w,inst_ld_bu,inst_ld_hu};
assign store_op = {inst_st_b,inst_st_h,inst_st_w};
assign expt_op = {inst_break,inst_rdcntid_w,inst_rdcntvl_w,inst_rdcntvh_w,inst_csrrd,inst_csrwr,inst_csrxchg,inst_syscall,inst_ertn};

assign intr_tag = has_int;
assign refetch_tag = es_tlb_refetch_tag | ms_tlb_refetch_tag | ws_tlb_refetch_tag;
assign ds_tlbsrch_block = inst_tlbrd | ((inst_csrwr | inst_csrxchg) & ((csr_num == `CSR_ASID) | (csr_num == `CSR_TLBEHI)));

assign ds_to_es_bus = { 
                        fs_tlbr,        
                        fs_pif,
                        fs_ppi,
                        invtlb_op_nd,   //1
                        ds_tlbsrch_block,//1
                        inst_tlbsrch,   //1
                        inst_tlbrd,     //1
                        inst_tlbwr,     //1
                        inst_tlbfill,   //1
                        inst_invtlb,    //1
                        invtlb_op,      //5
                        refetch_tag,    //1
                        intr_tag,       //1
                        expt_adef,      //1
                        expt_ine,       //1
                        expt_op,        //9
                        csr_num,        //14
                        load_op,        //5
                        store_op,       //3
                        ds_pc,          //32
                        res_from_mem,   //1
                        gr_we,          //1
                        mem_we,         //1
                        alu_op,         //19
                        dest,           //5     //rf waddr when csr and rdcnt
                        alu_src1,       //32    //wmask when csr write
                        alu_src2,       //32  
                        rkd_value       //32    //wvalue when csr write
                        };

//fw data
assign {es_tlbsrch_block,es_tlb_refetch_tag,es_csr,es_expt,es_vload,es_fw_vwe,es_fw_dest,es_fw_wdata} = es_fw_bus;
assign {ms_tlbsrch_block,ms_tlb_refetch_tag,ms_csr,ms_expt,ms_vload,ms_rd_ok,ms_fw_vwe,ms_fw_dest,ms_fw_wdata} = ms_fw_bus;
assign {ws_tlbsrch_block,ws_tlb_refetch_tag,ws_csr,ws_expt,ws_fw_vwe,ws_fw_dest,ws_fw_wdata} = ws_fw_bus;
//exclude out inst which not use the addr
assign raddr1_valid = ~inst_lu12i_w & ~inst_b & ~inst_bl & ~inst_pcaddu12i
                    & ~inst_csrwr & ~inst_csrrd & ~inst_syscall & ~inst_ertn   //basic exception
                    & ~inst_break & ~inst_rdcntid_w & ~inst_rdcntvl_w & ~inst_rdcntvh_w ;  //pro exception
assign raddr2_valid =   ~inst_lu12i_w 
                        & ~inst_slli_w & ~inst_srli_w & ~inst_srai_w 
                        & ~inst_addi_w & ~inst_ld_w
                        & ~inst_jirl & ~inst_b & ~inst_bl 
                        & ~inst_slti & ~inst_sltui              //pro calc
                        & ~inst_andi & ~inst_ori & ~inst_xori
                        & ~inst_pcaddu12i
                        & ~inst_ld_b & ~inst_ld_h & ~inst_ld_bu & ~inst_ld_hu //pro ls 
                        & ~inst_csrrd & ~inst_syscall & ~inst_ertn  //basic expt
                        & ~inst_break & ~inst_rdcntid_w & ~inst_rdcntvl_w & ~inst_rdcntvh_w ;  //pro expt 

assign rj_value =       ~(|rf_raddr1) ? 32'b0 :
                        es_fw_vwe & ~es_vload & (es_fw_dest == rf_raddr1) ? es_fw_wdata : //exclude load
                        ms_fw_vwe & (ms_fw_dest == rf_raddr1) ? ms_fw_wdata : 
                        ws_fw_vwe & (ws_fw_dest == rf_raddr1) ? ws_fw_wdata :
                        rf_rdata1;
assign rkd_value =      ~(|rf_raddr2) ? 32'b0 :
                        es_fw_vwe & ~es_vload & (es_fw_dest == rf_raddr2) ? es_fw_wdata : 
                        ms_fw_vwe & (ms_fw_dest == rf_raddr2) ? ms_fw_wdata : 
                        ws_fw_vwe & (ws_fw_dest == rf_raddr2) ? ws_fw_wdata :
                        rf_rdata2;
assign es_block =es_vload & es_fw_vwe & (|es_fw_dest) & 
                (
                (raddr1_valid & (es_fw_dest == rf_raddr1)) | 
                (raddr2_valid & (es_fw_dest == rf_raddr2)) 
                );
assign ms_block =ms_vload & ~ms_rd_ok & (|ms_fw_dest) & 
                (
                (raddr1_valid & (ms_fw_dest == rf_raddr1)) | 
                (raddr2_valid & (ms_fw_dest == rf_raddr2)) 
                );
assign usr_block = es_block | ms_block;
//csr block is overused by rdcnt
assign es_csr_block = es_fw_vwe & es_csr & (|es_fw_dest) &
                        (
                        (raddr1_valid & (es_fw_dest == rf_raddr1)) |
                        (raddr2_valid & (es_fw_dest == rf_raddr2))
                        );
assign ms_csr_block = ms_fw_vwe & ms_csr & (|ms_fw_dest) &
                        (
                        (raddr1_valid & (ms_fw_dest == rf_raddr1)) |
                        (raddr2_valid & (ms_fw_dest == rf_raddr2))
                        );
assign ws_csr_block = ws_fw_vwe & ws_csr & (|ws_fw_dest) &
                        (
                        (raddr1_valid & (ws_fw_dest == rf_raddr1)) |
                        (raddr2_valid & (ws_fw_dest == rf_raddr2))
                        );                        
assign csr_block = es_csr_block | ms_csr_block | ws_csr_block ;

//syscall block is overused by break
assign expt_block = es_expt | ms_expt | ws_expt;

//tlbsrch block
assign tlbsrch_block = es_tlbsrch_block | ms_tlbsrch_block | ws_tlbsrch_block;

endmodule