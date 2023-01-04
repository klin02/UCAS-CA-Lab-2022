`include "macro.v"

module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    output wire        mem_type,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0]  data_sram_size,
    output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
//top clock
    wire    reset;
    assign  reset = ~resetn;

//handshake signals between modules
	wire fs_to_ds_valid;
	wire ds_allowin;
	wire ds_to_es_valid;
	wire es_allowin;
	wire es_to_ms_valid;
	wire ms_allowin;
	wire ms_to_ws_valid;
	wire ws_allowin;
	
//data bus between modules
	wire [`FS_TO_DS_BUS_WD-1 : 0] 	fs_to_ds_bus;
	wire [`DS_TO_ES_BUS_WD-1 : 0] 	ds_to_es_bus;
	wire [`ES_TO_MS_BUS_WD-1 : 0]	es_to_ms_bus;
	wire [`MS_TO_WS_BUS_WD-1 : 0]	ms_to_ws_bus;
	
	//by-path : WB to RF through ID 
	wire [`WS_TO_RF_BUS_WD-1 : 0]	ws_to_rf_bus;
	
    //branch data
    wire [`BR_BUS_WD-1:0]           br_bus;
	//forwarding data bus
	wire [`ES_FW_BUS_WD-1 : 0]	es_fw_bus;	
	wire [`MS_FW_BUS_WD-1 : 0]	ms_fw_bus;
	wire [`WS_FW_BUS_WD-1 : 0]	ws_fw_bus;	
	
    //exception data
    wire expt_clear;
    wire [31:0] expt_refresh_pc;
    wire has_int;

    //signal to csru/tlb
    wire  tlbrd;
    wire  tlbwr;
    wire  tlbsrch;
    wire  tlbfill;
    wire  invtlb;  
    wire [ 4:0] invtlb_op;
    wire [ 9:0] invtlb_asid;
    wire [18:0] invtlb_vppn;   

//csru -- wb_stage interface
    wire [13:0]  csr_num;
    wire [31:0]  csr_rvalue;
    wire         csr_we;
    wire [31:0]  csr_wmask;
    wire [31:0]  csr_wvalue;
    wire         wb_ex;
    wire         ertn_flush;
    wire [ 5:0]  wb_ecode;
    wire [ 8:0]  wb_esubcode;
    wire [31:0]  wb_pc;
    wire [31:0]  wb_vaddr;
    wire [31:0]  wb_tid;
    wire         csru_int;
    wire [31:0]  ex_entry;
    wire [31:0]  ertn_pc;

    wire addr_map;        //0 direct 1 map
    wire csru_dmw0_plv0;
    wire csru_dmw0_plv3;

    wire [2:0] csru_dmw0_pseg;
    wire [2:0] csru_dmw0_vseg;
    wire csru_dmw1_plv0;
    wire csru_dmw1_plv3;
    wire [2:0] csru_dmw1_pseg;
    wire [2:0] csru_dmw1_vseg;
    wire [1:0] csru_crmd_plv;

    wire [1:0] csru_dmw0_mat;
    wire [1:0] csru_dmw1_mat;

    wire [18:0] tlb_s_vppn;
    wire [ 9:0] tlb_s_asid;
    wire        tlb_s_found;
    wire [ 3:0] tlb_s_index;

//tlb interface
    // search port 0 (for fetch)
    wire [18:0] tlb_s0_vppn;
    wire        tlb_s0_va_bit12; //单双页标记 与ps4MB异或后为1取xxx1，为0取xxx0
    wire [ 9:0] tlb_s0_asid;
    wire        tlb_s0_found;
    wire [ 3:0] tlb_s0_index;
    wire [19:0] tlb_s0_ppn;
    wire [ 5:0] tlb_s0_ps; //12为4KB，22为4MB
    wire [ 1:0] tlb_s0_plv;
    wire [ 1:0] tlb_s0_mat;
    wire        tlb_s0_d;
    wire        tlb_s0_v;
    // search port 1 (for load/store)
    wire [18:0] tlb_s1_vppn;
    wire        tlb_s1_va_bit12;
    wire [ 9:0] tlb_s1_asid;
    wire        tlb_s1_found;
    wire [ 3:0] tlb_s1_index;
    wire [19:0] tlb_s1_ppn;
    wire [ 5:0] tlb_s1_ps;
    wire [ 1:0] tlb_s1_plv;
    wire [ 1:0] tlb_s1_mat;
    wire        tlb_s1_d;
    wire        tlb_s1_v;
    // invtlb opcode
    wire        tlb_invtlb_valid;
    wire [ 4:0] tlb_invtlb_op;
    // write port
    wire        tlb_we; //w(rite) e(nable)
    wire [3:0]  tlb_w_index;
    wire        tlb_w_e;
    wire [18:0] tlb_w_vppn;
    wire [ 5:0] tlb_w_ps;
    wire [ 9:0] tlb_w_asid;
    wire        tlb_w_g;
    wire [19:0] tlb_w_ppn0;
    wire [ 1:0] tlb_w_plv0;
    wire [ 1:0] tlb_w_mat0;
    wire        tlb_w_d0;
    wire        tlb_w_v0;
    wire [19:0] tlb_w_ppn1;
    wire [ 1:0] tlb_w_plv1;
    wire [ 1:0] tlb_w_mat1;
    wire        tlb_w_d1;
    wire        tlb_w_v1;
    // read port
    wire [ 3:0] tlb_r_index;
    wire        tlb_r_e;
    wire [18:0] tlb_r_vppn;
    wire [ 5:0] tlb_r_ps;
    wire [ 9:0] tlb_r_asid;
    wire        tlb_r_g;
    wire [19:0] tlb_r_ppn0;
    wire [ 1:0] tlb_r_plv0;
    wire [ 1:0] tlb_r_mat0;
    wire        tlb_r_d0;
    wire        tlb_r_v0;
    wire [19:0] tlb_r_ppn1;
    wire [ 1:0] tlb_r_plv1;
    wire [ 1:0] tlb_r_mat1;
    wire        tlb_r_d1;
    wire        tlb_r_v1;

//addr_map interface
    // inst sram interface
    wire        fs_req;
    wire [31:0] fs_addr;
    wire        fs_tlbr;
    wire        fs_pif;
    wire        fs_ppi;
    wire        fs_en_dmw;
    wire        fs_en_dmw0;
    wire        fs_en_dmw1;
    wire [ 2:0] fs_dmw_pseg;
    wire [ 5:0] fs_ps;
    wire [19:0] fs_ppn;

    // data sram interface
    wire        es_req;
    wire [31:0] es_addr;
    wire        es_tlbr;
    wire        es_pil;
    wire        es_pis;
    wire        es_ppi;
    wire        es_pme;
    wire        es_en_dmw;
    wire        es_en_dmw0;
    wire        es_en_dmw1;
    wire [ 2:0] es_dmw_pseg;
    wire [ 5:0] es_ps;
    wire [19:0] es_ppn;

    IF_stage fs(
        .clk            (clk),
        .reset          (reset),
        .inst_sram_req  (inst_sram_req),
        .inst_sram_wr   (inst_sram_wr),
        .inst_sram_size (inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr (inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata(inst_sram_rdata),
        
        .br_bus         (br_bus),
        .ds_allowin     (ds_allowin),
        .fs_to_ds_valid (fs_to_ds_valid),
        .fs_to_ds_bus   (fs_to_ds_bus),
        
        .fs_req         (fs_req),
        .fs_addr        (fs_addr),
        .addr_map       (addr_map),
        .fs_tlbr        (fs_tlbr),
        .fs_pif         (fs_pif),
        .fs_ppi         (fs_ppi),
        .fs_en_dmw      (fs_en_dmw),
        .fs_dmw_pseg    (fs_dmw_pseg),
        .fs_ps          (fs_ps),
        .fs_ppn         (fs_ppn),

        .expt_clear     (expt_clear),
        .expt_refresh_pc(expt_refresh_pc)
    );

    ID_stage ds(
        .clk            (clk),
        .reset          (reset),
        .fs_to_ds_valid (fs_to_ds_valid),
        .fs_to_ds_bus   (fs_to_ds_bus),
        .ds_allowin     (ds_allowin),
        .br_bus         (br_bus),
        .es_allowin     (es_allowin),
        .ds_to_es_valid (ds_to_es_valid),
        .ds_to_es_bus   (ds_to_es_bus),
        .ws_to_rf_bus   (ws_to_rf_bus),
        .es_fw_bus      (es_fw_bus),
        .ms_fw_bus      (ms_fw_bus),
        .ws_fw_bus      (ws_fw_bus),
        .expt_clear     (expt_clear),
        .has_int        (has_int)
    );

    EX_stage es(
        .clk            (clk),
        .reset          (reset),
        .ds_to_es_valid (ds_to_es_valid),
        .ds_to_es_bus   (ds_to_es_bus),
        .es_allowin     (es_allowin),
        .ms_allowin     (ms_allowin),
        .es_to_ms_valid (es_to_ms_valid),
        .es_to_ms_bus   (es_to_ms_bus),
        .es_fw_bus      (es_fw_bus),

        .tlbsrch        (tlbsrch),
        .invtlb         (invtlb),
        .invtlb_op      (invtlb_op),
        .invtlb_asid    (invtlb_asid),
        .invtlb_vppn    (invtlb_vppn),

        .data_sram_req  (data_sram_req),
        .data_sram_wr   (data_sram_wr),
        .data_sram_size (data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr (data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),
        .data_sram_data_ok(data_sram_data_ok),

        .es_req         (es_req),
        .es_addr        (es_addr),
        .addr_map       (addr_map),
        .es_tlbr        (es_tlbr),
        .es_pil         (es_pil),
        .es_pis         (es_pis),
        .es_ppi         (es_ppi),
        .es_pme         (es_pme),
        .es_en_dmw      (es_en_dmw),
        .es_dmw_pseg    (es_dmw_pseg),
        .es_ps          (es_ps),
        .es_ppn         (es_ppn),

        .expt_clear     (expt_clear)
    );

    MEM_stage ms(
        .clk            (clk),
        .reset          (reset),
        .es_to_ms_valid (es_to_ms_valid),
        .es_to_ms_bus   (es_to_ms_bus),
        .ms_allowin     (ms_allowin),
        .ws_allowin     (ws_allowin),
        .ms_to_ws_valid (ms_to_ws_valid),
        .ms_to_ws_bus   (ms_to_ws_bus),
        .ms_fw_bus      (ms_fw_bus),
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),
        .expt_clear     (expt_clear)
    );

    WB_stage ws(
        .clk            (clk),
        .reset          (reset),
        .ms_to_ws_valid (ms_to_ws_valid),
        .ms_to_ws_bus   (ms_to_ws_bus),
        .ws_allowin     (ws_allowin),
        .ws_to_rf_bus   (ws_to_rf_bus),
        .ws_fw_bus      (ws_fw_bus),
        .expt_clear     (expt_clear),
        .expt_refresh_pc(expt_refresh_pc),
        .has_int        (has_int),

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
        .csru_int       (csru_int),
        .ex_entry       (ex_entry),
        .ertn_pc        (ertn_pc),

        .tlbrd          (tlbrd),
        .tlbwr          (tlbwr),
        .tlbfill        (tlbfill),
        .debug_wb_pc    (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

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
        .csru_int       (csru_int),
        .ex_entry       (ex_entry),
        .ertn_pc        (ertn_pc),

        .addr_map       (addr_map),
        .csru_dmw0_plv0 (csru_dmw0_plv0),
        .csru_dmw0_plv3 (csru_dmw0_plv3),
        .csru_dmw0_pseg (csru_dmw0_pseg),
        .csru_dmw0_vseg (csru_dmw0_vseg),
        .csru_dmw1_plv0 (csru_dmw1_plv0),
        .csru_dmw1_plv3 (csru_dmw1_plv3),
        .csru_dmw1_pseg (csru_dmw1_pseg),
        .csru_dmw1_vseg (csru_dmw1_vseg),
        .csru_crmd_plv  (csru_crmd_plv),

        .csru_dmw0_mat  (csru_dmw0_mat),
        .csru_dmw1_mat  (csru_dmw1_mat),
        .csru_crmd_datf (csru_crmd_datf),
        .csru_crmd_datm (csru_crmd_datm),

        .tlbrd          (tlbrd),
        .tlbwr          (tlbwr),
        .tlbsrch        (tlbsrch),
        .tlbfill        (tlbfill),
        .invtlb         (invtlb),

        .tlb_s_vppn     (tlb_s_vppn),
        .tlb_s_asid     (tlb_s_asid),
        .tlb_s_found    (tlb_s_found),
        .tlb_s_index    (tlb_s_index),

        .tlb_w_index    (tlb_w_index    ),
        .tlb_w_e        (tlb_w_e        ),
        .tlb_w_vppn     (tlb_w_vppn     ),
        .tlb_w_ps       (tlb_w_ps       ),
        .tlb_w_asid     (tlb_w_asid     ),
        .tlb_w_g        (tlb_w_g        ),
        .tlb_w_ppn0     (tlb_w_ppn0     ),
        .tlb_w_plv0     (tlb_w_plv0     ),
        .tlb_w_mat0     (tlb_w_mat0     ),
        .tlb_w_d0       (tlb_w_d0       ),
        .tlb_w_v0       (tlb_w_v0       ),
        .tlb_w_ppn1     (tlb_w_ppn1     ),
        .tlb_w_plv1     (tlb_w_plv1     ),
        .tlb_w_mat1     (tlb_w_mat1     ),
        .tlb_w_d1       (tlb_w_d1       ),
        .tlb_w_v1       (tlb_w_v1       ),

        .tlb_r_index    (tlb_r_index    ),
        .tlb_r_e        (tlb_r_e        ),
        .tlb_r_vppn     (tlb_r_vppn     ),
        .tlb_r_ps       (tlb_r_ps       ),
        .tlb_r_asid     (tlb_r_asid     ),
        .tlb_r_g        (tlb_r_g        ),
        .tlb_r_ppn0     (tlb_r_ppn0     ),
        .tlb_r_plv0     (tlb_r_plv0     ),
        .tlb_r_mat0     (tlb_r_mat0     ),
        .tlb_r_d0       (tlb_r_d0       ),
        .tlb_r_v0       (tlb_r_v0       ),
        .tlb_r_ppn1     (tlb_r_ppn1     ),
        .tlb_r_plv1     (tlb_r_plv1     ),
        .tlb_r_mat1     (tlb_r_mat1     ),
        .tlb_r_d1       (tlb_r_d1       ),
        .tlb_r_v1       (tlb_r_v1       )
    );


    // assign mem_type = ~addr_map & (csru_crmd_datf == 2'b01) | 
    //                   addr_map &  fs_en_dmw0 & (csru_dmw0_mat == 2'b01) | 
    //                   addr_map &  fs_en_dmw1 & (csru_dmw1_mat == 2'b01) | 
    //                   addr_map & ~fs_en_dmw  & (tlb_s0_mat == 2'b01) ;
    assign mem_type = 1'b1;

    assign tlb_we = tlbwr | tlbfill;
    assign tlb_invtlb_valid = invtlb;
    assign tlb_invtlb_op = invtlb_op;
    assign tlb_s0_vppn = fs_addr[31:13];
    assign tlb_s0_va_bit12 = fs_addr[12];
    assign tlb_s0_asid = tlb_s_asid;
    assign tlb_s1_vppn = invtlb ? invtlb_vppn : tlbsrch ? tlb_s_vppn : es_addr[31:13]; 
    assign tlb_s1_va_bit12 = es_addr[12];
    assign tlb_s1_asid = invtlb ? invtlb_asid : tlb_s_asid;
    assign tlb_s_found = tlb_s1_found;
    assign tlb_s_index = tlb_s1_index;

    assign fs_tlbr = fs_req & addr_map & ~fs_en_dmw & ~tlb_s0_found;
    assign fs_pif  = fs_req & addr_map & tlb_s0_found & ~tlb_s0_v;
    assign fs_ppi  = fs_req & addr_map & tlb_s0_found & tlb_s0_v & ((csru_crmd_plv == 2'b11) & (tlb_s0_plv == 2'b00));
    assign fs_en_dmw0 = (((csru_crmd_plv == 2'b00) & csru_dmw0_plv0) | ((csru_crmd_plv == 2'b11) & csru_dmw0_plv3))
                        & (fs_addr[31:29] == csru_dmw0_vseg);
    assign fs_en_dmw1 = (((csru_crmd_plv == 2'b00) & csru_dmw1_plv0) | ((csru_crmd_plv == 2'b11) & csru_dmw1_plv3))
                        & (fs_addr[31:29] == csru_dmw1_vseg);
    assign fs_en_dmw = fs_en_dmw0 | fs_en_dmw1;
    assign fs_dmw_pseg = fs_en_dmw0 ? csru_dmw0_pseg : csru_dmw1_pseg;
    assign fs_ps = tlb_s0_ps;
    assign fs_ppn = tlb_s0_ppn;

    assign es_tlbr = es_req & addr_map & ~es_en_dmw &~tlb_s1_found;
    assign es_pil  = es_req & ~data_sram_wr & addr_map & tlb_s1_found & ~tlb_s1_v;
    assign es_pis  = es_req &  data_sram_wr & addr_map & tlb_s1_found & ~tlb_s1_v;
    assign es_ppi  = es_req & addr_map & tlb_s1_found & tlb_s1_v & ((csru_crmd_plv == 2'b11) & (tlb_s1_plv == 2'b00));
    assign es_pme  = es_req &  data_sram_wr & addr_map & tlb_s1_found & tlb_s1_v 
                    & ((csru_crmd_plv == 2'b00) | (csru_crmd_plv == tlb_s1_plv) ) & ~tlb_s1_d;
    assign es_en_dmw0 = (((csru_crmd_plv == 2'b00) & csru_dmw0_plv0) | ((csru_crmd_plv == 2'b11) & csru_dmw0_plv3))
                        & (es_addr[31:29] == csru_dmw0_vseg);
    assign es_en_dmw1 = (((csru_crmd_plv == 2'b00) & csru_dmw1_plv0) | ((csru_crmd_plv == 2'b11) & csru_dmw1_plv3))
                        & (es_addr[31:29] == csru_dmw1_vseg);
    assign es_en_dmw = es_en_dmw0 | es_en_dmw1;
    assign es_dmw_pseg = es_en_dmw0 ? csru_dmw0_pseg : csru_dmw1_pseg;
    assign es_ps = tlb_s1_ps;
    assign es_ppn = tlb_s1_ppn;

    tlb u_tlb (
        .clk         (clk            ),
        .s0_vppn     (tlb_s0_vppn    ),
        .s0_va_bit12 (tlb_s0_va_bit12),
        .s0_asid     (tlb_s0_asid    ),
        .s0_found    (tlb_s0_found   ),
        .s0_index    (tlb_s0_index   ),
        .s0_ppn      (tlb_s0_ppn     ),
        .s0_ps       (tlb_s0_ps      ),
        .s0_plv      (tlb_s0_plv     ),
        .s0_mat      (tlb_s0_mat     ),
        .s0_d        (tlb_s0_d       ),
        .s0_v        (tlb_s0_v       ),

        .s1_vppn     (tlb_s1_vppn    ),
        .s1_va_bit12 (tlb_s1_va_bit12),
        .s1_asid     (tlb_s1_asid    ),
        .s1_found    (tlb_s1_found   ),
        .s1_index    (tlb_s1_index   ),
        .s1_ppn      (tlb_s1_ppn     ),
        .s1_ps       (tlb_s1_ps      ),
        .s1_plv      (tlb_s1_plv     ),
        .s1_mat      (tlb_s1_mat     ),
        .s1_d        (tlb_s1_d       ),
        .s1_v        (tlb_s1_v       ),

        .invtlb_valid(tlb_invtlb_valid),
        .invtlb_op   (tlb_invtlb_op   ),

        .we          (tlb_we         ),
        .w_index     (tlb_w_index    ),
        .w_e         (tlb_w_e        ),
        .w_vppn      (tlb_w_vppn     ),
        .w_ps        (tlb_w_ps       ),
        .w_asid      (tlb_w_asid     ),
        .w_g         (tlb_w_g        ),
        .w_ppn0      (tlb_w_ppn0     ),
        .w_plv0      (tlb_w_plv0     ),
        .w_mat0      (tlb_w_mat0     ),
        .w_d0        (tlb_w_d0       ),
        .w_v0        (tlb_w_v0       ),
        .w_ppn1      (tlb_w_ppn1     ),
        .w_plv1      (tlb_w_plv1     ),
        .w_mat1      (tlb_w_mat1     ),
        .w_d1        (tlb_w_d1       ),
        .w_v1        (tlb_w_v1       ),

        .r_index     (tlb_r_index    ),
        .r_e         (tlb_r_e        ),
        .r_vppn      (tlb_r_vppn     ),
        .r_ps        (tlb_r_ps       ),
        .r_asid      (tlb_r_asid     ),
        .r_g         (tlb_r_g        ),
        .r_ppn0      (tlb_r_ppn0     ),
        .r_plv0      (tlb_r_plv0     ),
        .r_mat0      (tlb_r_mat0     ),
        .r_d0        (tlb_r_d0       ),
        .r_v0        (tlb_r_v0       ),
        .r_ppn1      (tlb_r_ppn1     ),
        .r_plv1      (tlb_r_plv1     ),
        .r_mat1      (tlb_r_mat1     ),
        .r_d1        (tlb_r_d1       ),
        .r_v1        (tlb_r_v1       )
    );
endmodule
