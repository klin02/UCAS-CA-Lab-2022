`include "macro.v"

module IF_stage(
        input  clk,
        input  reset,

//inst_sram interface
        output        inst_sram_en,
        output [3:0]  inst_sram_we,
        output [31:0] inst_sram_addr,       //block ram nextPC
        output [31:0] inst_sram_wdata,
        input  [31:0] inst_sram_rdata,

//from ID
        //branch information from ID stage
        input  [`BR_BUS_WD - 1 : 0] br_bus,
        //Signal show next state ready to accept
        input  ds_allowin,
//to ID
        //Signal show this state valid to send
        output fs_to_ds_valid,
        //data IF send to ID
        output [`FS_TO_DS_BUS_WD - 1 : 0] fs_to_ds_bus	
	
);

        wire    to_fs_valid;
        
        wire	br_taken;
	wire [31:0] br_target;

        reg     fs_valid;
        wire    fs_allowin;
        wire    fs_ready_go;

        reg [31:0] fs_pc;
        wire [31:0] nextpc;
        wire [31:0] fs_inst;

        assign inst_sram_en   = to_fs_valid & fs_allowin;
        assign inst_sram_we   = 4'b0;
        assign inst_sram_addr = nextpc;
        assign inst_sram_wdata= 32'b0;
        assign fs_inst = inst_sram_rdata;

        assign  to_fs_valid = ~reset;     

        assign  {br_taken,br_target} = br_bus;

        always @(posedge clk) begin
                if(reset)
                        fs_valid <= 1'b0;
                else if(fs_allowin)
                        fs_valid <= to_fs_valid;
        end

        assign  fs_allowin = ~fs_valid | (ds_allowin & fs_ready_go);
        assign  fs_ready_go = 1'b1;     //always done within one clk
        assign  fs_to_ds_valid = fs_valid & fs_ready_go & ~br_taken; // op next branch is invalid
        assign  fs_to_ds_bus   = {fs_pc,fs_inst};

        always @(posedge clk)begin
                if(reset)
                        fs_pc <= 32'h1bfffffc;
                else if(fs_allowin)
                        fs_pc <= nextpc;
        end

        assign nextpc = br_taken        ? br_target:
                        fs_pc + 32'h4;

endmodule 