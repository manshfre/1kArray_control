`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module bl_interface (
  input  logic        clk,      // 时钟
  input  logic        rst_n,    // 异步低电平复位
  
  input  logic        bl_addr_en,       // 写使能（仅在 pre_op=0 时有效）
  input  logic        bl_pre_op_en,   // 预写入全区标志
  input  logic [4:0]  addr,     // 地址：高2位选区，低3位选 bit
  
  input  real   op_vol[8],   // 8 个 real 型输入（由 8×8 bit DAC 驱动）
  output real  out_data[32]  // 32 个 real 型输出寄存器
);

  // 内部寄存器阵列
  real out_data_reg [32];

  // 区域号 0~3
  logic [1:0] region;
  // 在 op_vol 中选哪一位
  logic [2:0] bit_index;
  // 选中位的真实值
  real        sel_bit;
  // 计算绝对输出位置：region*8 + bit_index
  int         out_pos; 

  // 赋值给输出
  always_comb
  begin
    out_data = out_data_reg;
    out_pos =  region * 8 + bit_index;
  end

  always_latch begin
    if(!rst_n) begin
            bit_index = 3'b000;
            region = 2'b00;    
            sel_bit = 0.0;    
        end
        if(bl_addr_en) begin
            region = addr[4:3];
            bit_index = addr[2:0];
            sel_bit = op_vol[bit_index];            
        end
    end

  // 同步逻辑
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // 异步复位
      for (int i = 0; i < 32; i++) 
        out_data_reg[i] <= 0.0;
    end 
    else begin
      if (bl_pre_op_en) begin
        // 预写入：将 op_vol[0..7] 全部复制到 4 个 8-bit 区块
        for (int blk = 0; blk < 4; blk++) begin
          for (int j = 0; j < 8; j++) begin
            out_data_reg[blk*8 + j] <= op_vol[j];
          end
        end
      end 
      else if (bl_addr_en) begin
        // 按位写入：只更新 out_data_reg[out_pos]
           for (int i = 0; i < 32; i++) begin
                if (i == out_pos)
                    out_data_reg[i] <= sel_bit;
                else
                    out_data_reg[i] <= out_data_reg[i];
                end
             end             
//       else for (int k=0; k<32; k++)
//      // else: pre_op=0 && we=0 → out_data_reg 保持不变
//           out_data_reg [k]<=out_data_reg [k];
       end
  end

endmodule

