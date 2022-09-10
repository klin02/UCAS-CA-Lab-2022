`include "macro.v"
// Control State Register Unit
module csru (
        input   clk,
        input   reset,

//inst interface
        input [13:0]  csr_num,
        output [31:0] csr_rvalue,
        input   csr_we,
        input [31:0]  csr_wmask,
        input [31:0]  csr_wvalue,

//hardware interface
        input wb_ex,
        input ertn_flush,
        input [5:0] wb_ecode,
        input [8:0] wb_esubcode,
        input [31:0] wb_pc,
        output [31:0] ex_entry,
        output [31:0] ertn_pc
);

//tmp for basic exception, later will be input 
wire [7:0] hw_int_in;
wire ipi_int_in;
wire [31:0] timer_cnt;
assign hw_int_in = 8'b0;
assign ipi_int_in = 1'b0;
assign timer_cnt = 32'b1;

//CSR read value
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;

//different region of CSR
reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;
reg csr_crmd_da;

reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;

reg [12:0] csr_estat_is;
reg [5:0] csr_estat_ecode;      //sys 0xb
reg [8:0] csr_estat_esubcode;

reg [31:0] csr_era_pc;

reg [25:0] csr_eentry_va;

reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;
        
assign csr_crmd_rvalue = {28'b0,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};
assign csr_era_rvalue = csr_era_pc;
assign csr_eentry_rvalue = {csr_eentry_va,6'b0};
assign csr_save0_rvalue = csr_save0_data;
assign csr_save1_rvalue = csr_save1_data;
assign csr_save2_rvalue = csr_save2_data;
assign csr_save3_rvalue = csr_save3_data;

assign csr_rvalue = {32{csr_num == `CSR_CRMD}}     & csr_crmd_rvalue  |
                    {32{csr_num == `CSR_PRMD}}     & csr_prmd_rvalue  |
                    {32{csr_num == `CSR_ESTAT}}    & csr_estat_rvalue |
                    {32{csr_num == `CSR_ERA}}      & csr_era_rvalue   |
                    {32{csr_num == `CSR_EENTRY}}   & csr_eentry_rvalue|
                    {32{csr_num == `CSR_SAVE0}}    & csr_save0_data   |
                    {32{csr_num == `CSR_SAVE1}}    & csr_save1_data   |
                    {32{csr_num == `CSR_SAVE2}}    & csr_save2_data   |
                    {32{csr_num == `CSR_SAVE3}}    & csr_save3_data   ;

//following signals is to refresh PC
assign ex_entry = csr_eentry_rvalue;
assign ertn_pc = csr_era_rvalue;

//CRMD
always @(posedge clk) begin
        if(reset)
                csr_crmd_plv <= 2'b0;   
        else if(wb_ex)
                csr_crmd_plv <= 2'b0;   //highest privilege
        else if(ertn_flush)
                csr_crmd_plv <= csr_prmd_pplv;
        else if(csr_we & (csr_num == `CSR_CRMD))
                csr_crmd_plv <=  csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] |
                                ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
end

always @(posedge clk) begin
        if(reset)
                csr_crmd_ie <= 1'b0;
        else if(wb_ex)
                csr_crmd_ie <= 1'b0;    //disable interrupt
        else if(ertn_flush)
                csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we & (csr_num == `CSR_CRMD))
                csr_crmd_ie <=   csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE] | 
                                ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
end

always @ (posedge clk) begin
        csr_crmd_da <= 1'b1;
end

//PRMD
always @(posedge clk) begin
        if(wb_ex)begin
                csr_prmd_pplv <= csr_crmd_plv;
                csr_prmd_pie <= csr_crmd_ie;
        end
        else if(csr_we & (csr_num == `CSR_PRMD)) begin 
                csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV] |
                                ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
                csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE] |
                                ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
end

//ESTAT
always @(posedge clk) begin
        if(reset)
                csr_estat_is[1:0] <= 2'b0;
        else if(csr_we & (csr_num == `CSR_ESTAT))
                csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] |
                                    ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        
        csr_estat_is[9:2] <= hw_int_in[7:0];

        csr_estat_is[10] <= 1'b0;

        if(timer_cnt[31:0] == 32'b0)
                csr_estat_is[11] <= 1'b1;       //intr
        else if(csr_we & (csr_num == `CSR_TICLR) & csr_wmask[`CSR_TICLR_CLR] & csr_wvalue[`CSR_TICLR_CLR] )
                csr_estat_is[11] <= 1'b0;

        csr_estat_is[12] <= ipi_int_in;
end

always @(posedge clk) begin
        if(wb_ex) begin
                csr_estat_ecode <= wb_ecode;
                csr_estat_esubcode <= wb_esubcode;
        end
end

//ERA
always @(posedge clk) begin
        if(wb_ex)
                csr_era_pc <= wb_pc;        
        else if(csr_we & (csr_num == `CSR_ERA))
                csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC] |
                             ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end

//EENTRY
always @(posedge clk) begin
        if(csr_we & (csr_num == `CSR_EENTRY))
                csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA] | 
                                ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

//SAVE0-3
always @(posedge clk) begin
        if(csr_we & (csr_num == `CSR_SAVE0))
                csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA] |
                                 ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if(csr_we & (csr_num == `CSR_SAVE1))
                csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA] |
                                 ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if(csr_we & (csr_num == `CSR_SAVE2))
                csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA] |
                                 ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if(csr_we & (csr_num == `CSR_SAVE3))
                csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA] |
                                 ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

endmodule