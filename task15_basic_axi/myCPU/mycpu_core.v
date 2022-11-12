`include "macro.v"

module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
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
        .data_sram_req  (data_sram_req),
        .data_sram_wr   (data_sram_wr),
        .data_sram_size (data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr (data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),
        .data_sram_data_ok(data_sram_data_ok),
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
        .debug_wb_pc    (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule
