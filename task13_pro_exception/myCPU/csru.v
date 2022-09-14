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
        input [31:0] wb_vaddr,   //pro
        output [31:0] wb_tid,    //pro
        output has_int,          //pro
        output [31:0] ex_entry,
        output [31:0] ertn_pc
);

//tmp for basic exception, later will be input 
wire [7:0] hw_int_in;
wire ipi_int_in;
wire [31:0] coreid_in;

assign hw_int_in = 8'b0;
assign ipi_int_in = 1'b0;
assign coreid_in = 32'b0;

//cue signals
reg [31:0] timer_cnt; //change
wire wb_ex_addr_err;
wire [31:0] tcfg_next_value;


//CSR read value
//basic
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
//pro
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;
wire [31:0] csr_ticlr_rvalue;

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
//pro
reg [12:0] csr_ecfg_lie;
reg [31:0] csr_badv_vaddr;
reg [31:0] csr_tid_tid;
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
//tval_timeval is timer_cnt
wire csr_ticlr_clr;


//basic
assign csr_crmd_rvalue = {28'b0,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};
assign csr_era_rvalue = csr_era_pc;
assign csr_eentry_rvalue = {csr_eentry_va,6'b0};
assign csr_save0_rvalue = csr_save0_data;
assign csr_save1_rvalue = csr_save1_data;
assign csr_save2_rvalue = csr_save2_data;
assign csr_save3_rvalue = csr_save3_data;
//pro
assign csr_ecfg_rvalue = {19'b0,csr_ecfg_lie};
assign csr_badv_rvalue = csr_badv_vaddr;
assign csr_tid_rvalue = csr_tid_tid;
assign csr_tcfg_rvalue = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};
assign csr_tval_rvalue = timer_cnt[31:0];
assign csr_ticlr_rvalue = {31'b0,csr_ticlr_clr};

assign csr_rvalue = {32{csr_num == `CSR_CRMD}}     & csr_crmd_rvalue  |
                    {32{csr_num == `CSR_PRMD}}     & csr_prmd_rvalue  |
                    {32{csr_num == `CSR_ESTAT}}    & csr_estat_rvalue |
                    {32{csr_num == `CSR_ERA}}      & csr_era_rvalue   |
                    {32{csr_num == `CSR_EENTRY}}   & csr_eentry_rvalue|
                    {32{csr_num == `CSR_SAVE0}}    & csr_save0_data   |
                    {32{csr_num == `CSR_SAVE1}}    & csr_save1_data   |
                    {32{csr_num == `CSR_SAVE2}}    & csr_save2_data   |
                    {32{csr_num == `CSR_SAVE3}}    & csr_save3_data   |
                    {32{csr_num == `CSR_ECFG}}     & csr_ecfg_rvalue  |  //pro
                    {32{csr_num == `CSR_BADV}}     & csr_badv_rvalue  |
                    {32{csr_num == `CSR_TID}}      & csr_tid_rvalue   |
                    {32{csr_num == `CSR_TCFG}}     & csr_tcfg_rvalue  |
                    {32{csr_num == `CSR_TVAL}}     & csr_tval_rvalue  |
                    {32{csr_num == `CSR_TICLR}}    & csr_ticlr_rvalue ;

//following signals is to IF refresh PC
assign ex_entry = csr_eentry_rvalue;
assign ertn_pc = csr_era_rvalue;
//following is to WB rdcntid
assign wb_tid = csr_tid_rvalue;
//following is to ID to mark intr
assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) & csr_crmd_ie;
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
                csr_estat_is[11] <= 1'b1;       //time intr
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

//ECFG
always @(posedge clk) begin
        if(reset)
                csr_ecfg_lie <= 13'b0;
        else if(csr_we & (csr_num == `CSR_ECFG))
                csr_ecfg_lie <=  csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE] |
                                ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
end

//BADV
assign wb_ex_addr_err = wb_ecode == `ECODE_ADE | wb_ecode == `ECODE_ALE;
always @(posedge clk) begin
        if(wb_ex & wb_ex_addr_err)
                csr_badv_vaddr <= (wb_ecode == `ECODE_ADE & wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr; 
end

//TID
always @(posedge clk) begin
        if(reset)
                csr_tid_tid <= coreid_in;
        else if(csr_we & (csr_num == `CSR_TID)) 
                csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID] |
                              ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
end

//TCFG
always @(posedge clk) begin
        if(reset)
                csr_tcfg_en <= 1'b0;
        else if(csr_we & (csr_num == `CSR_TCFG))
                csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN] |
                              ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
        
        if(csr_we & (csr_num == `CSR_TCFG)) begin
                csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC] |
                                    ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
                csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL] |
                                   ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
        end
end

//TVAL
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0] |
                        ~csr_wmask[31:0] & csr_tcfg_rvalue;

always @(posedge clk) begin
        if(reset)
                timer_cnt <= 32'hffffffff;
        else if(csr_we & (csr_num == `CSR_TCFG) & tcfg_next_value[`CSR_TCFG_EN])
                timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL],2'b0};
        else if(csr_tcfg_en & (timer_cnt != 32'hffffffff)) begin
                if((timer_cnt == 32'b0) & csr_tcfg_periodic)
                        timer_cnt <= {csr_tcfg_initval,2'b0};
                else
                        timer_cnt <= timer_cnt - 1'b1;
        end
end

//TICLR
assign csr_ticlr_clr = 1'b0;

endmodule