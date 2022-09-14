//if define, use IP. else use my mul/div
	//`define USE_IP 1

//op WD
	`define ALU_OP_WD 	 19
	`define BLU_OP_WD 	 6
		
//BUS width between module
	`define BR_BUS_WD 	 33  	// 1 br + 32 tar
	
	`define FS_TO_DS_BUS_WD  65	// 32 PC + 32 Instruction_reg
	`define DS_TO_ES_BUS_WD  189 	// see detail in ID_stage
	`define ES_TO_MS_BUS_WD  167 	//see detail in EX_stage
	`define MS_TO_WS_BUS_WD  161	//see detail in MEM_stage
	
	`define WS_TO_RF_BUS_WD	 38  	//1 wen + 5 addr + 32 data

//FW BUS 
	//task 8 include valid_we / dest
	//task 9 include valid_we / dest / wdata 
		//ES: valid_ load / valid_wd / dest / wdata  , because load should block until mem
	`define ES_FW_BUS_WD 	 41
	`define MS_FW_BUS_WD 	 40
	`define WS_FW_BUS_WD 	 40
	
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

//CSR REGION --basic
	`define CSR_CRMD_PLV 	1:0
	`define CSR_CRMD_IE 	2
	`define CSR_PRMD_PPLV 	1:0
	`define CSR_PRMD_PIE 	2
	`define CSR_ESTAT_IS10  1:0
	`define CSR_ERA_PC 	31:0
	`define CSR_EENTRY_VA 	31:6
	`define CSR_SAVE_DATA 	31:0

//CSR REGION --pro
	`define CSR_ECFG_LIE 	12:0
	`define CSR_TID_TID 	31:0
	`define CSR_TCFG_EN  	0
	`define CSR_TCFG_PERIODIC 1
	`define CSR_TCFG_INITVAL 31:2
	`define CSR_TICLR_CLR 	0

//ecode and esubcode
	`define ECODE_ADE 	6'h08
	`define ECODE_ALE 	6'h09
	`define ESUBCODE_ADEF 	9'h000