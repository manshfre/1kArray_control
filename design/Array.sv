`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

interface inout_port32;
    real bus32[31:0];
    modport drive32 (output bus32);
    modport read32 (input bus32);
endinterface

module mem_array #(
  parameter real VT     = 0.73,      // 阈值电压
  parameter real HRS_G  = 0.35,     // 高阻导纳
  parameter real K      = 0.06,     // 线性系数,默认8.3，这里设置成0.06是因为pre_wl没有经历预载入
  parameter real SIGMA  = 0.01      // 随机扰动标准差
)(
input  logic       tran_en,//电压施加操作完成标志，在macwl中产生
input  logic       rst_n,
input logic [9:0] addr_tar,//忆阻器地址，高5位行，低5位列
  
input logic bl_assert_en,//bl接口电压可读取指示信号
input  real        V_BL[32],

input logic wl_assert_en, //wl接口电压可读取指示信号
input  real        V_WL[32],

input logic sl_assert_en,//sl接口电压可读取指示信号
input  logic       read_mode,// 1代表读，0代表写
inout_port32.read32    SL_vol,//从bank读电压       
inout_port32.drive32    SL_current,//向bank写电流

output real G_c_reg[1024]
);
// 内部变量
real G_c[1024];
real pre_V_WL[32];
real VBL[32];
real VWL[32];
real G_var;
real SL_data[32];

  // 随机种子
    int unsigned seed = 32'h12345678;
  //读取WL、BL电压
    always_latch begin
        if(!rst_n) for (int i=0; i<32; i++) begin
            VBL[i] = 0.0;
            VWL[i] =0.0;
        end
        else begin 
        if(bl_assert_en)
            for (int i=0; i<32; i++)
                VBL[i] = V_BL[i];
        if(wl_assert_en)
            for (int i=0; i<32; i++)        
                VWL[i] = V_WL[i];
        end
    end

// 更新导纳 G_c
    always_comb begin
        if(!rst_n) for (int i=0; i<1024; i++)
            G_c[i]=HRS_G;
        else if ((VWL[addr_tar[4:0]]!=0)&&!read_mode) begin//直接忽略其他忆阻器的电导变化
                if (VWL[addr_tar[4:0]] < VT) begin
                    G_c[addr_tar] = HRS_G;
                end else begin
                    G_c[addr_tar] = G_c_reg[addr_tar] + K * (VWL[addr_tar[4:0]] - pre_V_WL[addr_tar[4:0]]) * (VBL[addr_tar[9:5]] - SL_data[addr_tar[4:0]]);
                end
        end
    end
// 计算 SL_data
    always_latch begin
        if(!rst_n)
            for (int i=0; i<32; i++) begin
                    SL_data[i] = 0.0;
                    SL_current.bus32[i] = 0.0;        
            end
        if (!read_mode) begin
            if (sl_assert_en)
                for (int i=0; i<32; i++) begin
                    SL_data[i] = SL_vol.bus32[i];  // 写模式：传入外部电压
                    SL_current.bus32[i] = 0.0;
                end
        end else begin 
            if(tran_en) for (int j=0; j<32; j++) begin                 
                SL_data[j] = VBL[addr_tar[9:5]] * 1000.0 * G_c_reg[addr_tar[9:5]*32+j];
                SL_current.bus32[j] = SL_data[j];  // 读模式：输出电流值
            end
        end
      end

// 特定时刻更新历史值
    always_ff @(posedge tran_en or negedge rst_n) begin
        if (!rst_n) begin
            for(int i=0; i<32; i++) begin
                pre_V_WL[i] <= 0.0;
            end
            for(int k=0; k<1024; k++) begin
                G_c_reg[k]  <= HRS_G;            
            end
        end 
        else begin
            if (!read_mode)begin
                G_var <= $dist_normal(seed, 0.0, SIGMA);
                G_c_reg[addr_tar]  <= G_c[addr_tar]+G_var;
                for(int j=0; j<32; j++)
                    pre_V_WL[j] <= VWL[j];//保存set、reset操作时的WL电压     
            end
         end
    end

endmodule

