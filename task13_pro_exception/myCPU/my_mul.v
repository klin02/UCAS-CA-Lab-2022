module my_mul(
        input clk,
        input reset,
        input mul_signed,
        input [31:0] x,
        input [31:0] y,
        output [63:0] result
);
        //add 2 bit for signed/unsigned mul -> signed mul
        wire [33:0] a;
        wire [33:0] b;

        wire [34:0] b_slo; //左移一位，末尾填0 shift left one
        wire [67:0] p[16:0]; //17个68位部分积
        wire [16:0] t_p[67:0]; //p的转置
        wire [16:0] c; //17个末位加1信号，最高两位将连接最终加法器，其余接入华莱士树

        //wallce cin/cout/c/s
        wire [14:0] wal_cin[67:0];
        wire [14:0] wal_cout[67:0];
        wire [67:0] wal_c;
        wire [67:0] wal_s;

        //final adder
        reg [67:0] adder_a;
        reg [67:0] adder_b;
        reg adder_cin;
        wire [67:0] adder_result;

        assign a = {{2{mul_signed & x[31]}},x};
        assign b = {{2{mul_signed & y[31]}},y};
        assign b_slo = {b,1'b0};
generate
        genvar i;
        for(i=0;i<17;i=i+1) begin: gen_p_and_c
                assign p[i] =   {68{b_slo[2*i+2:2*i] == 3'b000 | b_slo[2*i+2:2*i] == 3'b111}} & 68'b0 |
                                {68{b_slo[2*i+2:2*i] == 3'b001 | b_slo[2*i+2:2*i] == 3'b010}} & {{(34-2*i){a[33]}},a,{(2*i){1'd0}}} |
                                {68{b_slo[2*i+2:2*i] == 3'b011}} & {{(33-2*i){a[33]}},a,{(2*i+1){1'd0}}} | 
                                {68{b_slo[2*i+2:2*i] == 3'b100}} & {{(33-2*i){~a[33]}},~a,{(2*i+1){1'd1}}} |
                                {68{b_slo[2*i+2:2*i] == 3'b101 | b_slo[2*i+2:2*i] == 3'b110}} & {{(34-2*i){~a[33]}},~a,{(2*i){1'd1}}} ;
                assign c[i] = b_slo[2*i+2:2*i] == 3'b100 | b_slo[2*i+2:2*i] == 3'b101 | b_slo[2*i+2:2*i] == 3'b110;
        end
endgenerate

generate
        genvar j;
        for(j=0;j<68;j=j+1) begin: transmit_p
        assign t_p[j] = {p[16][j],p[15][j],p[14][j],p[13][j],p[12][j],p[11][j],p[10][j],p[9][j],p[8][j],
                p[7][j],p[6][j],p[5][j],p[4][j],p[3][j],p[2][j],p[1][j],p[0][j]};
        end
endgenerate

assign wal_cin[0] = c[14:0];

generate
        genvar gv;
        for(gv=0;gv<67;gv=gv+1) begin: wal_connect
        assign wal_cin[gv+1] = wal_cout[gv];
        end
endgenerate

generate
        genvar k;
        for(k=0;k<68;k=k+1) begin: wallace_tree
        wallace_17 wal(t_p[k],wal_cin[k],wal_cout[k],wal_c[k],wal_s[k]);
        end
endgenerate

always @(posedge clk) begin
        if(reset) begin
                adder_a <= 68'b0;
                adder_b <= 68'b0;
                adder_cin <= 1'b0;
        end 
        else begin
                adder_a <= {wal_c[66:0],c[15]};
                adder_b <= wal_s;
                adder_cin <= c[16];
        end
end

assign adder_result = adder_a + adder_b + adder_cin;
assign result = adder_result[63:0];
endmodule

module wallace_17 (
        input wire [16:0] n,
        input wire [14:0] cin,
        output wire [14:0] cout,
        output wire c,
        output wire s
);
wire [14:0] tmp;
//first floor: 6
adder_1 a1(n[ 0],n[ 1],n[ 2],cout[ 0],tmp[ 0]);
adder_1 a2(n[ 3],n[ 4],n[ 5],cout[ 1],tmp[ 1]);
adder_1 a3(n[ 6],n[ 7],n[ 8],cout[ 2],tmp[ 2]);
adder_1 a4(n[ 9],n[10],n[11],cout[ 3],tmp[ 3]);
adder_1 a5(n[12],n[13],n[14],cout[ 4],tmp[ 4]);
adder_1 a6(n[15],n[16],1'b0 ,cout[ 5],tmp[ 5]);
//second floor: 3
adder_1 b1(tmp[0],tmp[1],tmp[2],cout[6],tmp[6]);
adder_1 b2(tmp[3],tmp[4],tmp[5],cout[7],tmp[7]);
adder_1 b3(cin[0],cin[1],cin[2],cout[8],tmp[8]);
//third floor: 3
adder_1 c1(tmp[6],tmp[7],tmp[8],cout[9],tmp[9]);
adder_1 c2(cin[3],cin[4],cin[5],cout[10],tmp[10]);
adder_1 c3(cin[6],cin[7],cin[8],cout[11],tmp[11]);
//fourth floor: 2
adder_1 d1(tmp[9],tmp[10],tmp[11],cout[12],tmp[12]);
adder_1 d2(cin[9],cin[10],cin[11],cout[13],tmp[13]);
//fifth floor: 1
adder_1 e1(tmp[12],tmp[13],cin[12],cout[14],tmp[14]);
//sixth floor: 1
adder_1 f1(tmp[14],cin[13],cin[14],c,s);

endmodule

module adder_1 (
        input wire a,
        input wire b,
        input wire cin,
        output wire cout,
        output wire s
);

assign {cout,s} = a+b+cin;
endmodule