module tlb #
(
        parameter TLBNUM = 16
)
(
        input  wire                      clk,
        // search port 0 (for fetch)
        input  wire [18:0]               s0_vppn,
        input  wire                      s0_va_bit12, //单双页标记 与ps4MB异或后为1取xxx1，为0取xxx0
        input  wire [ 9:0]               s0_asid,
        output wire                      s0_found,
        output wire [$clog2(TLBNUM)-1:0] s0_index,
        output wire [19:0]               s0_ppn,
        output wire [ 5:0]               s0_ps, //12为4KB，22为4MB
        output wire [ 1:0]               s0_plv,
        output wire [ 1:0]               s0_mat,
        output wire                      s0_d,
        output wire                      s0_v,
        // search port 1 (for load/store)
        input  wire [18:0]               s1_vppn,
        input  wire                      s1_va_bit12,
        input  wire [ 9:0]               s1_asid,
        output wire                      s1_found,
        output wire [$clog2(TLBNUM)-1:0] s1_index,
        output wire [19:0]               s1_ppn,
        output wire [ 5:0]               s1_ps,
        output wire [ 1:0]               s1_plv,
        output wire [ 1:0]               s1_mat,
        output wire                      s1_d,
        output wire                      s1_v,
        // invtlb opcode
        input  wire                      invtlb_valid,
        input  wire [4:0]                invtlb_op,
        // write port
        input  wire                      we, //w(rite) e(nable)
        input  wire [$clog2(TLBNUM)-1:0] w_index,
        input  wire                      w_e,
        input  wire [18:0]               w_vppn,
        input  wire [ 5:0]               w_ps,
        input  wire [ 9:0]               w_asid,
        input  wire                      w_g,
        input  wire [19:0]               w_ppn0,
        input  wire [ 1:0]               w_plv0,
        input  wire [ 1:0]               w_mat0,
        input  wire                      w_d0,
        input  wire                      w_v0,
        input  wire [19:0]               w_ppn1,
        input  wire [ 1:0]               w_plv1,
        input  wire [ 1:0]               w_mat1,
        input  wire                      w_d1,
        input  wire                      w_v1,
        // read port
        input  wire [$clog2(TLBNUM)-1:0] r_index,
        output wire                      r_e,
        output wire [18:0]               r_vppn,
        output wire [ 5:0]               r_ps,
        output wire [ 9:0]               r_asid,
        output wire                      r_g,
        output wire [19:0]               r_ppn0,
        output wire [ 1:0]               r_plv0,
        output wire [ 1:0]               r_mat0,
        output wire                      r_d0,
        output wire                      r_v0,
        output wire [19:0]               r_ppn1,
        output wire [ 1:0]               r_plv1,
        output wire [ 1:0]               r_mat1,
        output wire                      r_d1,
        output wire                      r_v1
);

reg  [TLBNUM-1:0] tlb_e;
reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg  [      18:0] tlb_vppn [TLBNUM-1:0];
reg  [       9:0] tlb_asid [TLBNUM-1:0];
reg  [TLBNUM-1:0] tlb_g;
reg  [      19:0] tlb_ppn0 [TLBNUM-1:0];
reg  [       1:0] tlb_plv0 [TLBNUM-1:0];
reg  [       1:0] tlb_mat0 [TLBNUM-1:0];
reg  [TLBNUM-1:0] tlb_d0;
reg  [TLBNUM-1:0] tlb_v0;
reg  [      19:0] tlb_ppn1 [TLBNUM-1:0];
reg  [       1:0] tlb_plv1 [TLBNUM-1:0];
reg  [       1:0] tlb_mat1 [TLBNUM-1:0];
reg  [TLBNUM-1:0] tlb_d1;
reg  [TLBNUM-1:0] tlb_v1; 

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;

wire [TLBNUM-1:0] cond1;//G位为0
wire [TLBNUM-1:0] cond2;//G为为1 
wire [TLBNUM-1:0] cond3;//s1_asid为ASID域
wire [TLBNUM-1:0] cond4;//s1_vppn与VPPN和PS匹配       

genvar i;
generate
        for(i=0;i<TLBNUM;i=i+1) begin: match0_gen
                assign match0[i] = tlb_e[i]
                                 & (s0_vppn[18:10] == tlb_vppn[i][18:10])
                                 & (tlb_ps4MB[i] | (s0_vppn[9:0] == tlb_vppn[i][9:0]))
                                 & ((s0_asid == tlb_asid[i]) | tlb_g[i]);
        end
endgenerate

genvar j;
generate
        for(j=0;j<TLBNUM;j=j+1) begin: match1_gen
                assign match1[j] = tlb_e[j]
                                 & (s1_vppn[18:10] == tlb_vppn[j][18:10])
                                 & (tlb_ps4MB[j] | (s1_vppn[9:0] == tlb_vppn[j][9:0]))
                                 & ((s1_asid == tlb_asid[j]) | tlb_g[j]);
        end
endgenerate

genvar c1;
generate
        for(c1=0;c1<TLBNUM;c1=c1+1) begin: cond1_gen
                assign cond1[c1] = ~tlb_g[c1];
        end
endgenerate

genvar c2;
generate
        for(c2=0;c2<TLBNUM;c2=c2+1) begin: cond2_gen
                assign cond2[c2] = tlb_g[c2];
        end
endgenerate

genvar c3;
generate
        for(c3=0;c3<TLBNUM;c3=c3+1) begin: cond3_gen
                assign cond3[c3] = s1_asid == tlb_asid[c3];
        end
endgenerate

genvar c4;
generate
        for(c4=0;c4<TLBNUM;c4=c4+1) begin: cond4_gen
                assign cond4[c4] = (s1_vppn[18:10] == tlb_vppn[c4][18:10]) 
                                 & (tlb_ps4MB[c4] | (s1_vppn[9:0] == tlb_vppn[c4][9:0]));
        end
endgenerate

assign s0_found = |match0;
assign s1_found = |match1;

assign s0_index = ({4{match0[ 0]}} & 4'd0 )
                | ({4{match0[ 1]}} & 4'd1 )
                | ({4{match0[ 2]}} & 4'd2 )
                | ({4{match0[ 3]}} & 4'd3 )
                | ({4{match0[ 4]}} & 4'd4 )
                | ({4{match0[ 5]}} & 4'd5 )
                | ({4{match0[ 6]}} & 4'd6 )
                | ({4{match0[ 7]}} & 4'd7 )
                | ({4{match0[ 8]}} & 4'd8 )
                | ({4{match0[ 9]}} & 4'd9 )
                | ({4{match0[10]}} & 4'd10)
                | ({4{match0[11]}} & 4'd11)
                | ({4{match0[12]}} & 4'd12)
                | ({4{match0[13]}} & 4'd13)
                | ({4{match0[14]}} & 4'd14)
                | ({4{match0[15]}} & 4'd15);

assign s1_index = ({4{match1[ 0]}} & 4'd0 )
                | ({4{match1[ 1]}} & 4'd1 )
                | ({4{match1[ 2]}} & 4'd2 )
                | ({4{match1[ 3]}} & 4'd3 )
                | ({4{match1[ 4]}} & 4'd4 )
                | ({4{match1[ 5]}} & 4'd5 )
                | ({4{match1[ 6]}} & 4'd6 )
                | ({4{match1[ 7]}} & 4'd7 )
                | ({4{match1[ 8]}} & 4'd8 )
                | ({4{match1[ 9]}} & 4'd9 )
                | ({4{match1[10]}} & 4'd10)
                | ({4{match1[11]}} & 4'd11)
                | ({4{match1[12]}} & 4'd12)
                | ({4{match1[13]}} & 4'd13)
                | ({4{match1[14]}} & 4'd14)
                | ({4{match1[15]}} & 4'd15);

assign s0_ppn = (tlb_ps4MB[s0_index] ^ s0_va_bit12) ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_ps  = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
assign s0_plv = (tlb_ps4MB[s0_index] ^ s0_va_bit12) ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat = (tlb_ps4MB[s0_index] ^ s0_va_bit12) ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d   = (tlb_ps4MB[s0_index] ^ s0_va_bit12) ? tlb_d1[s0_index]   : tlb_d0[s0_index];
assign s0_v   = (tlb_ps4MB[s0_index] ^ s0_va_bit12) ? tlb_v1[s0_index]   : tlb_v0[s0_index];

assign s1_ppn = (tlb_ps4MB[s1_index] ^ s1_va_bit12) ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_ps  = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
assign s1_plv = (tlb_ps4MB[s1_index] ^ s1_va_bit12) ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat = (tlb_ps4MB[s1_index] ^ s1_va_bit12) ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d   = (tlb_ps4MB[s1_index] ^ s1_va_bit12) ? tlb_d1[s1_index]   : tlb_d0[s1_index];
assign s1_v   = (tlb_ps4MB[s1_index] ^ s1_va_bit12) ? tlb_v1[s1_index]   : tlb_v0[s1_index];

//read port
assign r_e    = tlb_e[r_index];
assign r_vppn = tlb_vppn[r_index];
assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
assign r_asid = tlb_asid[r_index];
assign r_g    = tlb_g[r_index];
assign r_ppn0 = tlb_ppn0[r_index];
assign r_plv0 = tlb_plv0[r_index];
assign r_mat0 = tlb_mat0[r_index];
assign r_d0   = tlb_d0[r_index];
assign r_v0   = tlb_v0[r_index];
assign r_ppn1 = tlb_ppn1[r_index];
assign r_plv1 = tlb_plv1[r_index];
assign r_mat1 = tlb_mat1[r_index];
assign r_d1   = tlb_d1[r_index];
assign r_v1   = tlb_v1[r_index];

//write port
always @(posedge clk) begin
        if(we) begin
                tlb_e[w_index] <= w_e;
                tlb_vppn[w_index] <= w_vppn;
                tlb_ps4MB[w_index] <= (w_ps == 6'd22);
                tlb_asid[w_index] <= w_asid;
                tlb_g[w_index] <= w_g;
                tlb_ppn0[w_index] <= w_ppn0;
                tlb_plv0[w_index] <= w_plv0;
                tlb_mat0[w_index] <= w_mat0;
                tlb_d0[w_index] <= w_d0;
                tlb_v0[w_index] <= w_v0;
                tlb_ppn1[w_index] <= w_ppn1;
                tlb_plv1[w_index] <= w_plv1;
                tlb_mat1[w_index] <= w_mat1;
                tlb_d1[w_index] <= w_d1;
                tlb_v1[w_index] <= w_v1;
        end
        else if(invtlb_valid) begin
                if(invtlb_op == 5'h00 | invtlb_op == 5'h01)
                        tlb_e <= 16'b0;
                else if(invtlb_op == 5'h02) //cond2
                        tlb_e <= tlb_e & ~cond2;
                else if(invtlb_op == 5'h03) //cond1
                        tlb_e <= tlb_e & ~cond1;
                else if(invtlb_op == 5'h04) //cond1 & cond3
                        tlb_e <= tlb_e & ~(cond1 & cond3);
                else if(invtlb_op == 5'h05) //cond1 & cond3 & cond4
                        tlb_e <= tlb_e & ~(cond1 & cond3 & cond4);
                else if(invtlb_op == 5'h06) //(cond2 | cond3) & cond4
                        tlb_e <= tlb_e & ~((cond2 | cond3) & cond4);
        end
end

endmodule


