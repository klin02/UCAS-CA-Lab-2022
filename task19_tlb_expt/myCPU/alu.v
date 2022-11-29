`include "macro.v"

module alu(
  input  clk,
  input  reset,
  input  es_valid,
  output mul_out_valid,  //1 when IP
  output div_out_valid,  //div result is valid
  input  wire [`ALU_OP_WD-1:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
//pro calc
wire op_mul_w;
wire op_mulh_w;
wire op_mulh_wu;
wire op_div_w;
wire op_mod_w;
wire op_div_wu;
wire op_mod_wu;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
//pro calc
assign op_mul_w   = alu_op[12];
assign op_mulh_w  = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign op_div_w   = alu_op[15];
assign op_mod_w   = alu_op[16];
assign op_div_wu  = alu_op[17];
assign op_mod_wu  = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
//pro calc
`ifdef USE_IP
    wire [63:0] mul_s64_result;
    wire [63:0] mul_u64_result;
`else
    reg mul_valid_en;
    reg mul_in_delay;
    wire mul_signed;
    wire [63:0] mul_64_result;
    wire div_signed;
`endif
wire [31:0] mul_w_result;
wire [31:0] mulh_w_result;
wire [31:0] mulh_wu_result;
wire [31:0] div_result;
wire [31:0] mod_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

//32-bit divisor
`ifdef USE_IP
    reg tvalid_en;  //reset ->1  handshake ->0  dout_valid ->1
    //tvalid shared by dividend and divisor
    wire div_s_tvalid;    //signed
    wire div_u_tvalid;    //unsigned
    wire dividend_tready; //signed or unsigned
    wire dividend_s_tready;
    wire dividend_u_tready;
    wire divisor_tready;
    wire divisor_s_tready;
    wire divisor_u_tready;
    wire [31:0] dividend_tdata;
    wire [31:0] divisor_tdata;
    wire dout_tvalid;
    wire dout_s_tvalid;
    wire dout_u_tvalid;
    wire [63:0] dout_tdata;
    wire [63:0] dout_s_tdata;
    wire [63:0] dout_u_tdata;
`else
    wire div_valid;
`endif 

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;  //取反加1
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])  //bug: rj <0 rk >0
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);  //rj-rk < 0

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout; //true

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2; //在top中已经进行通过need_ui5进行了移位

//bug: 顺序错误
// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

// MUL_W MULH_W MULH_WU result
`ifdef USE_IP
    assign mul_s64_result = $signed(alu_src1) * $signed(alu_src2);
    assign mul_u64_result = alu_src1 * alu_src2;
    assign mul_w_result   = mul_s64_result[31:0];
    assign mulh_w_result  = mul_s64_result[63:32];
    assign mulh_wu_result = mul_u64_result[63:32];
    assign mul_out_valid = 1'b1;
`else
    assign mul_signed = op_mulh_w;
    my_mul inst_mul(
      .clk          (clk),
      .reset        (reset),
      .mul_signed   (mul_signed),
      .x            (alu_src1),
      .y            (alu_src2),
      .result       (mul_64_result)
    );
    assign mul_w_result = mul_64_result[31:0];
    assign mulh_w_result = mul_64_result[63:32];
    assign mulh_wu_result = mul_64_result[63:32];

    always @(posedge clk) begin
      mul_in_delay <= es_valid & (op_mul_w | op_mulh_w | op_mulh_wu);
    end
    always @(posedge clk) begin
        mul_valid_en <= ~mul_in_delay;
    end
    assign mul_out_valid = mul_in_delay & mul_valid_en;
`endif

// DIV_W(U) MOD_W(U) result
`ifdef USE_IP
    always @(posedge clk) begin
      if(reset)
        tvalid_en <= 1'b1;
      else if( (div_s_tvalid | div_u_tvalid) & (dividend_tready & divisor_tready) )
        tvalid_en <= 1'b0;
      else if( dout_tvalid)
        tvalid_en <= 1'b1;
    end
    assign div_s_tvalid = es_valid & (op_div_w | op_mod_w ) & tvalid_en;
    assign div_u_tvalid = es_valid & (op_div_wu | op_mod_wu ) & tvalid_en;
    assign dividend_tready = ( (op_div_w | op_mod_w) & dividend_s_tready ) | 
                            ( (op_div_wu | op_mod_wu) & dividend_u_tready ) ;
    assign divisor_tready = ( (op_div_w | op_mod_w) & divisor_s_tready ) | 
                            ( (op_div_wu | op_mod_wu) & divisor_u_tready ) ;
    assign dividend_tdata = alu_src1;
    assign divisor_tdata = alu_src2;
    assign {div_result,mod_result} = dout_tdata;
    assign div_out_valid = dout_tvalid;
    assign dout_tvalid = dout_s_tvalid | dout_u_tvalid;
    assign dout_tdata = {64{dout_s_tvalid}} & dout_s_tdata | 
                        {64{dout_u_tvalid}} & dout_u_tdata;

    ip_signed_div s_div(
      .aclk(clk),
      .s_axis_dividend_tvalid(div_s_tvalid),
      .s_axis_dividend_tready(dividend_s_tready),
      .s_axis_dividend_tdata(dividend_tdata),
      .s_axis_divisor_tvalid(div_s_tvalid),
      .s_axis_divisor_tready(divisor_s_tready),
      .s_axis_divisor_tdata(divisor_tdata),
      .m_axis_dout_tvalid(dout_s_tvalid),
      .m_axis_dout_tdata(dout_s_tdata)
    );

    ip_unsigned_div u_div(
      .aclk(clk),
      .s_axis_dividend_tvalid(div_u_tvalid),
      .s_axis_dividend_tready(dividend_u_tready),
      .s_axis_dividend_tdata(dividend_tdata),
      .s_axis_divisor_tvalid(div_u_tvalid),
      .s_axis_divisor_tready(divisor_u_tready),
      .s_axis_divisor_tdata(divisor_tdata),
      .m_axis_dout_tvalid(dout_u_tvalid),
      .m_axis_dout_tdata(dout_u_tdata)
    );
`else
    assign div_valid = es_valid & (op_div_w | op_mod_w | op_div_wu | op_mod_wu);
    assign div_signed = op_div_w | op_mod_w;
    my_div inst_div(
      .clk      (clk),
      .reset    (reset),
      .div      (div_valid),
      .div_signed(div_signed),
      .x        (alu_src1),
      .y        (alu_src2),
      .s        (div_result),
      .r        (mod_result),
      .complete (div_out_valid)
    );
`endif 
// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mul_w     }} & mul_w_result)  //pro calc
                  | ({32{op_mulh_w    }} & mulh_w_result)
                  | ({32{op_mulh_wu   }} & mulh_wu_result)
                  | ({32{op_div_w|op_div_wu}} & div_result)
                  | ({32{op_mod_w|op_mod_wu}} & mod_result)
                  ;

endmodule
