`timescale 1ns / 1ps


module mac_blcontrol(
input sys_clk,
input sys_rst_n,
//工作开始信号
input work_en,//
input work_mode,//1write0read
//BL输入地址与操作模式
input [4:0] bl_addr_in,//10bit地址高5位
input op_mode,//为1代表set，0为reset
input op_down,//代表wl脉冲即将结束
//BL_DAC控制信号与数据
output reg [7:0] bl_digital_vol,//输出给DAC锁存器电压
output reg bl_dac_lock_en,//DAC锁存器使能
//bl_array_if控制信号与地址
output reg [4:0] bl_addr,//输给接口模块地址
output reg bl_pre_op_en,//接口模块预充电使能
output reg bl_addr_op_en,//接口模块按地址充电使能
//阵列控制信号
output reg bl_assert_en//输出给阵列读取指示信号
    );
/////////////////////////////////////////////////  
parameter IDLE = 3'b001;
parameter PRE_OP = 3'b010;
parameter ADDR_OP = 3'b011;
parameter WAIT = 3'b100;

reg [7:0] digital_data;
    
reg [2:0] state_now,state_next;

///////////////////////////////////////////////
parameter TIME_DAC = 8'b0000_1010;

reg [7:0] timer,timer_next;
wire last_cyc;
assign last_cyc = (timer ==8'b0000_0001);

////////////////////工作状态相关更新//////////////////////////
    always @(posedge sys_clk,negedge sys_rst_n)
        if (!sys_rst_n) begin
            state_now <= IDLE;
            state_next <= IDLE;
            
            timer <= 8'b0000_0000;
            timer_next <= 8'b0000_0000;                                  
        end
        else begin
            state_now <= state_next;
            timer <= timer_next;
        end
        
    always @(*) begin
        case(state_now)
            IDLE:begin 
                if(work_en) begin
                    state_next = PRE_OP;
                    timer_next = TIME_DAC;
                    
                    if(work_mode) begin
                        if(op_mode)
                            digital_data = 8'b0000_0000;
                        else 
                            digital_data = 8'b0110_1100;
                    end else
                            digital_data = 8'b0000_0000;
                end
                else begin
                    state_next = state_now;
                    timer_next = timer;
                
                    digital_data = digital_data;
                end
            end
            PRE_OP:begin
                if (last_cyc) begin
                    state_next = ADDR_OP;
                    timer_next = TIME_DAC;
                    
                    bl_pre_op_en = 1'b1;
                    bl_addr_op_en = 1'b0;
                    
                    if(work_mode) begin
                        if(op_mode)
                            digital_data =  8'b0100_1101;
                        else 
                            digital_data = 8'b0000_0000;
                    end else  
                            digital_data = 8'b0000_1000;                            
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;
                    
                    bl_pre_op_en = 1'b0;
                    bl_addr_op_en = 1'b0;
                    
                    digital_data = digital_data;
                end
            end  
            ADDR_OP:begin
                if (last_cyc) begin
                    state_next = WAIT;
                    timer_next = 8'b0000_0000; 
                    
                    bl_pre_op_en = 1'b0;
                    bl_addr_op_en = 1'b1;                                       
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;
                    
                    bl_pre_op_en = 1'b0;
                    bl_addr_op_en = 1'b0;                                    
                end         
                digital_data = digital_data;           
            end
            WAIT:begin
                if(op_down) begin
                    state_next = IDLE;
                    timer_next = 8'b0000_0000;
                end
                else begin
                    state_next = state_now;
                    timer_next = timer;
                end 
                bl_pre_op_en = 1'b0;
                bl_addr_op_en = 1'b0;                     
            end
            default:;
        endcase
    end        
//////////////////////////dac_lock_en、assert_en同步拉高/////////////////////////////////////    
    always @(posedge sys_clk,negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            digital_data <= 8'b0000_0000;
            bl_digital_vol <= 8'b0000_0000;
            bl_dac_lock_en <= 1'b0;
            
            bl_pre_op_en <= 1'b0;
            bl_addr_op_en <= 1'b0;
            
            bl_assert_en <= 1'b0;
        end
        else begin 
            case(state_now)
                IDLE:begin
                    bl_addr <= bl_addr_in;
                    
                    bl_dac_lock_en <= 1'b1; 
                    bl_digital_vol <= digital_data;            
                end
                PRE_OP:begin
                    if(last_cyc) begin                        
                        bl_dac_lock_en <= 1'b1;
                        bl_digital_vol <= digital_data;
                    end
                    else begin                        
                        bl_dac_lock_en <= 1'b0;
                        bl_digital_vol <= bl_digital_vol;
                    end                    
                end
                ADDR_OP:begin
                    if(last_cyc) begin
                       bl_assert_en <=1'b1;                       
                    end 
                    else begin
                        bl_assert_en <= 1'b0;
                    end
                    
                    bl_dac_lock_en <= 1'b0;
                    bl_digital_vol <= bl_digital_vol;                    
                end
                WAIT:begin
                    bl_assert_en <= 1'b0;
                    
                    bl_dac_lock_en <= 1'b0;
                    bl_digital_vol <= bl_digital_vol;                    
                end
                default:begin
                    digital_data <= 8'b0000_0000;
                    bl_digital_vol <= 8'b0000_0000;
                    bl_dac_lock_en <= 1'b0;
            
                    bl_pre_op_en <= 1'b0;
                    bl_addr_op_en <= 1'b0;
            
                    bl_assert_en <= 1'b0;
                end
            endcase
        end
    end    
    
endmodule
