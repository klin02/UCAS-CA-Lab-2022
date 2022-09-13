module my_div(
        input clk,
        input reset,
        input div,
        input div_signed,
        input [31:0] x,
        input [31:0] y,
        output [31:0] s, //商
        output [31:0] r, //余数
        output complete
);
        wire x_signed;
        wire y_signed;
        wire s_signed;
        wire r_signed;
        wire [31:0] x_abs;
        wire [31:0] y_abs;
        reg [63:0] div_a;
        reg [63:0] div_mask; //初始为高33位为0，其余位为1，然后循环右移。为1的对应部分将保留
        reg [31:0] div_s;
        wire [31:0] div_r;
        reg [5:0] time_cnter;

        wire ss_res_is_pos;
        wire [63:0] ss_a_aligned;

        assign x_signed = x[31] & div_signed;
        assign y_signed = y[31] & div_signed;
        assign s_signed = (x[31]^y[31]) & div_signed;
        assign r_signed = x[31] & div_signed;
        assign x_abs = ({32{x_signed}}^x) + x_signed;
        assign y_abs = ({32{y_signed}}^y) + y_signed;

        always @(posedge clk) begin
                if(div & (time_cnter == 6'b0))
                        div_mask <= 64'h000000007fffffff;
                else
                        div_mask <= {1'b1,div_mask[63:1]};
        end
        always @(posedge clk) begin
                if(div & (time_cnter == 6'b0))
                        div_a <= {32'b0,x_abs};
                else if(ss_res_is_pos) //第一次对应的time为1
                        div_a <= ( div_mask & div_a ) | ss_a_aligned;
        end
        always @(posedge clk) begin
                if(div & (time_cnter == 6'b0))
                        div_s <= 32'b0;
                else 
                        div_s <= {div_s[30:0],ss_res_is_pos};
        end
                        
        always @(posedge clk) begin
                if(reset | ~div | complete)
                        time_cnter <= 6'b0;
                else 
                        time_cnter <= time_cnter + 1'b1;
        end
        assign complete = time_cnter == 6'd33;

        shift_sub ss1(
                .a_in           (div_a),
                .time_cnter     (time_cnter),
                .b              (y_abs),
                .res_is_pos     (ss_res_is_pos),
                .a_aligned      (ss_a_aligned)
        );

        assign div_r = div_a[31:0];
        assign s = ({32{s_signed}}^div_s) + s_signed;
        assign r = ({32{r_signed}}^div_r) + r_signed;
endmodule

module shift_sub (
        input wire [63:0] a_in,
        input wire [5:0 ] time_cnter,
        input wire [31:0] b,
        output wire res_is_pos,         //结果为正数
        output wire [63:0] a_aligned  //将待更新值移到相应位置
);
        wire [64:0] a_in_shift; //将其零拓展一位后根据time移位，从而使最高33位为操作数
        //suber
        wire [32:0] adder_a;
        wire [32:0] adder_b;
        wire adder_cin;
        wire [32:0] adder_res;
        wire [64:0] a_aligned_shift;

        assign a_in_shift = {1'b0,a_in} << time_cnter;
        assign adder_a = a_in_shift[64:32];
        assign adder_b = ~{1'b0,b};
        assign adder_cin = 1'b1;
        assign adder_res = adder_a + adder_b + adder_cin;
        
        assign a_aligned_shift = {adder_res,32'b0}>>time_cnter;
        assign a_aligned = a_aligned_shift[63:0];
        assign res_is_pos = ~adder_res[32];
endmodule 