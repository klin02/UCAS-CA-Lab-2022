`include "macro.v"

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
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
	

    IF_stage fs(
        .clk            (clk),
        .reset          (reset),
        .inst_sram_en   (inst_sram_en),
        .inst_sram_we   (inst_sram_we),
        .inst_sram_addr (inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .br_bus         (br_bus),
        .ds_allowin     (ds_allowin),
        .fs_to_ds_valid (fs_to_ds_valid),
        .fs_to_ds_bus   (fs_to_ds_bus)
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
        .ws_fw_bus      (ws_fw_bus)
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
        .data_sram_en   (data_sram_en),
        .data_sram_we   (data_sram_we),
        .data_sram_addr (data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
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
        .data_sram_rdata(data_sram_rdata)
    );

    WB_stage ws(
        .clk            (clk),
        .reset          (reset),
        .ms_to_ws_valid (ms_to_ws_valid),
        .ms_to_ws_bus   (ms_to_ws_bus),
        .ws_allowin     (ws_allowin),
        .ws_to_rf_bus   (ws_to_rf_bus),
        .ws_fw_bus      (ws_fw_bus),
        .debug_wb_pc    (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule
