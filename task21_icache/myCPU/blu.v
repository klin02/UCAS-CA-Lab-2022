`include "macro.v"
//branch logic unit
module blu(
        input [`BLU_OP_WD-1:0] blu_op,
        input [31:0] blu_src1,
        input [31:0] blu_src2,
        output blu_result
);

wire op_beq;
wire op_bne;
wire op_blt;
wire op_bge;
wire op_bltu;
wire op_bgeu;

wire beq_result;
wire bne_result;
wire blt_result;
wire bge_result;
wire bltu_result;
wire bgeu_result;

//32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign {op_beq,op_bne,op_blt,op_bge,op_bltu,op_bgeu} = blu_op;

//achieve compare by adder(sub indeed)
assign adder_a = blu_src1;
assign adder_b = ~blu_src2;
assign adder_cin = 1'b1;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

assign beq_result = ~(|adder_result);
assign bne_result = ~beq_result;
assign blt_result = (blu_src1[31] & ~blu_src2[31])  //bug: rj <0 rk >0
                | ((blu_src1[31] ~^ blu_src2[31]) & adder_result[31]); 
assign bge_result = ~blt_result;
assign bltu_result = ~adder_cout;
assign bgeu_result = ~bltu_result;

assign blu_result =     op_beq  & beq_result    |
                        op_bne  & bne_result    |
                        op_blt  & blt_result    |
                        op_bge  & bge_result    |
                        op_bltu & bltu_result   |
                        op_bgeu & bgeu_result   ;
endmodule