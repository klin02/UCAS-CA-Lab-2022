//if define, use IP. else use my mul/div
	//`define USE_IP 1

//tlb random index seed
	`define TLB_RANDOM_SEED {7'b1010101,16'h2FCD}
	
//op WD
	`define ALU_OP_WD 	 19
	`define BLU_OP_WD 	 6
		
//BUS width between module
	`define BR_BUS_WD 	 34  	// 1 stall + 1 br + 32 tar
	
	`define FS_TO_DS_BUS_WD  65	// 1 expt + 32 PC + 32 Instruction_reg
	`define DS_TO_ES_BUS_WD  202 	// see detail in ID_stage
	`define ES_TO_MS_BUS_WD  174 	//see detail in EX_stage
	`define MS_TO_WS_BUS_WD  167	//see detail in MEM_stage
	
	`define WS_TO_RF_BUS_WD	 38  	//1 wen + 5 addr + 32 data

//FW BUS 
	//task 8 include valid_we / dest
	//task 9 include valid_we / dest / wdata 
		//ES: valid_ load / valid_wd / dest / wdata  , because load should block until mem
	//task 14:
		//MS: vload / rd_ok
	`define ES_FW_BUS_WD 	 43
	`define MS_FW_BUS_WD 	 44
	`define WS_FW_BUS_WD 	 42
	
//CSR NUM --basic
	`define CSR_CRMD 	14'h0000
	`define CSR_PRMD 	14'h0001
	`define CSR_ESTAT 	14'h0005
	`define CSR_ERA 	14'h0006
	`define CSR_EENTRY 	14'h000c
	`define CSR_SAVE0 	14'h0030
	`define CSR_SAVE1 	14'h0031
	`define CSR_SAVE2 	14'h0032
	`define CSR_SAVE3 	14'h0033

//CSR NUM --pro
	`define CSR_ECFG 	14'h0004
	`define CSR_BADV 	14'h0007 
	`define CSR_TID 	14'h0040 
	`define CSR_TCFG 	14'h0041 
	`define CSR_TVAL 	14'h0042
	`define CSR_TICLR 	14'h0044

//CSR NUM --basic tlb
	`define CSR_TLBIDX      14'h0010 
	`define CSR_TLBEHI 	14'h0011
	`define CSR_TLBELO0 	14'h0012 
	`define CSR_TLBELO1 	14'h0013 
	`define CSR_ASID 	14'h0018 
	`define CSR_TLBRENTRY 	14'h0088 

//CSR REGION --basic
	`define CSR_CRMD_PLV 		1:0
	`define CSR_CRMD_IE 		2
	`define CSR_PRMD_PPLV 		1:0
	`define CSR_PRMD_PIE 		2
	`define CSR_ESTAT_IS10  	1:0
	`define CSR_ERA_PC 		31:0
	`define CSR_EENTRY_VA 		31:6
	`define CSR_SAVE_DATA 		31:0

//CSR REGION --pro
	`define CSR_ECFG_LIE 		12:0
	`define CSR_TID_TID 		31:0
	`define CSR_TCFG_EN  		0
	`define CSR_TCFG_PERIODIC 	1
	`define CSR_TCFG_INITVAL 	31:2
	`define CSR_TICLR_CLR 	 	0

//CSR REGION --basic tlb
	`define CSR_TLBIDX_INDEX 	3:0
	`define CSR_TLBIDX_PS 		29:24
	`define CSR_TLBIDX_NE 		31
	`define CSR_TLBEHI_VPPN 	31:13
	`define CSR_TLBELO_V 		0
	`define CSR_TLBELO_D 		1
	`define CSR_TLBELO_PLV 		3:2
	`define CSR_TLBELO_MAT 		5:4
	`define CSR_TLBELO_G 		6
	`define CSR_TLBELO_PPN 		31:8
	`define CSR_ASID_ASID 		9:0
	`define CSR_ASID_ASIDBITS 	23:16
	`define CSR_TLBRENTRY_PA 	31:6

//ecode and esubcode
	`define ECODE_ADE 	6'h08
	`define ECODE_ALE 	6'h09
	`define ESUBCODE_ADEF 	9'h000