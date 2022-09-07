//BUS width between module
	`define BR_BUS_WD 	 33  	// 1 br + 32 tar
	
	`define FS_TO_DS_BUS_WD  64	// 32 PC + 32 Instruction_reg
	`define DS_TO_ES_BUS_WD  148 	// see detail in ID_stage
	`define ES_TO_MS_BUS_WD  71 	//see detail in EX_stage
	`define MS_TO_WS_BUS_WD  70	//see detail in MEM_stage
	
	`define WS_TO_RF_BUS_WD	 38  	//1 wen + 5 addr + 32 data
