`timescale 1ns / 1ps

// 8 通道模拟接口
interface inout_port8;
    real bus8[7:0];
    modport drive8 (output bus8);
    modport read8 ( input bus8);
endinterface

// 32 通道模拟接口
interface inout_port32;
    real bus32[31:0];
    modport drive32 (output bus32);
    modport read32 ( input bus32);
endinterface

// 双向 Bank 模块：
// 写模式：将 DAC 的 8 通道写入内部 32 通道寄存器
// 读模式：从内部寄存器读取 8 通道并驱动到 ADC，同时可从 Array 总线更新内部寄存器
module sl_bank (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        sl_addr_en,//load特定地址的电压
    input  logic        sl_pre_op_en,//load整条总线电压
    input  logic [4:0]  addr,
    input  logic        read_mode,

    inout_port8.read8    bus_dac,       // 8 通道 DAC 输入
    inout_port32.read32   bus_arr_in,    // 来自 Array 返回的数据
    inout_port32.drive32   bus_arr_out,   // 写给 Array 的总线
    inout_port8.drive8    bus_adc        // 驱动到 ADC 的总线
);
real  out_data_reg[32];
logic [1:0] region;
logic [2:0] bit_index;
int         out_pos;

    // 地址解码
    always_comb begin
            region = addr[4:3];
            bit_index = addr[2:0];     
            out_pos =  region * 8 + bit_index;
    end

    //用寄存器接收DAC电压
    always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (int i=0; i<32; i++) out_data_reg[i] <= 0.0;
  end else if (sl_pre_op_en) begin
            for (int blk = 0; blk < 4; blk++) begin
                for (int j = 0; j < 8; j++) begin
                    out_data_reg[blk*8 + j] <= bus_dac.bus8[j];
                end
            end
  end else if (sl_addr_en) begin
        out_data_reg[out_pos] <= bus_dac.bus8[bit_index];
  end
end

// 2) 组合输出：驱动 Array 与 ADC
always_comb begin
  // 默认清 0
  for (int i=0; i<32; i++) bus_arr_out.bus32[i] = 0.0;
  for (int j=0; j<8;  j++) bus_adc.bus8[j]     = 0.0;

  if(!read_mode) begin
    for (int i = 0; i < 32; i++)
      bus_arr_out.bus32[i] = out_data_reg[i];
  end
  else begin
    // Array → ADC（直接从 bus_arr_in 取值）
	      case(region)
              2'd0: for (int k = 0; k < 8; k++)
                       bus_adc.bus8[k] = bus_arr_in.bus32[k];
              2'd1: for (int k = 0; k < 8; k++)
                       bus_adc.bus8[k] = bus_arr_in.bus32[8 + k];
              2'd2: for (int k = 0; k < 8; k++)
                       bus_adc.bus8[k] = bus_arr_in.bus32[16 + k];
              2'd3: for (int k = 0; k < 8; k++)
                       bus_adc.bus8[k] = bus_arr_in.bus32[24 + k];
              default: for (int k = 0; k < 8; k++)
                         bus_adc.bus8[k] = 0.0;
            endcase
  end
  
end
    
endmodule
