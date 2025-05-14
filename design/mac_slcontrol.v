`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////

module mac_slcontrol(
input sys_clk,
input sys_rst_n,
//工作开始信号
input work_en,
input work_mode,//1write0read
//input awake,
//BL输入地址与操作模式
input [4:0] sl_addr_in,
input op_mode,//为1代表set，0为reset
input op_down,//代表wl脉冲结束
//BL_DAC控制信号与数据
output reg [7:0] sl_digital_vol,
output reg sl_dac_lock_en,
//bl_array_if控制信号与地址
output reg [4:0] sl_addr,
output reg sl_pre_op_en,
output reg sl_addr_op_en,
//output reg sl_adc_lock_en,
//阵列控制信号
output reg sl_assert_en
    );
/////////////////////////////////////////////////    
parameter IDLE = 3'b001;
parameter PRE_OP = 3'b010;
parameter ADDR_OP = 3'b011;
parameter WAIT = 3'b100;
    
reg [2:0] state_now,state_next;

///////////////////////////////////////////////
parameter TIME_DAC = 8'b0000_1010;

reg [7:0] timer,timer_next;
wire last_cyc;
assign last_cyc = (timer ==8'b0000_0001);

////////////////////工作状态相关更新//////////////////////////
reg [7:0] digital_data;

//    always @(posedge sys_clk,negedge sys_rst_n)
//        if(!sys_rst_n) begin
//            work_down <= 1'b0;
//        end
//        else if(op_down)
//            work_down <= 1'b1;
//        else 
//            work_down <=1'b0;
/////////////////////状态同步更新//////////////////////////    
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
                    if(work_mode) begin
                        state_next = PRE_OP;
                        timer_next = TIME_DAC;
                        
                        digital_data = 8'b0000_0000;
                    end
                    else begin
                        state_next = WAIT;
                        timer_next = 8'b0000_0000;
                    end
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
                    
                    sl_pre_op_en = 1'b1;
                    sl_addr_op_en = 1'b0;
                    
                    if(op_mode)
                        digital_data =  8'b0000_0000;
                    else 
                        digital_data = 8'b0110_1100;
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;
                    
                    sl_pre_op_en = 1'b0;
                    sl_addr_op_en = 1'b0;
                    
                    digital_data = digital_data;
                end
            end  
            ADDR_OP:begin
                if (last_cyc) begin
                    state_next = WAIT;
                    timer_next = 8'b0000_0000; 
                    
                    sl_pre_op_en = 1'b0;
                    sl_addr_op_en = 1'b1;                                       
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;
                    
                    sl_pre_op_en = 1'b0;
                    sl_addr_op_en = 1'b0;                                    
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
                sl_pre_op_en = 1'b0;
                sl_addr_op_en = 1'b0;                     
            end
            default:;
        endcase
    end        
//////////////////////////dac_lock、assert_en同步加载/////////////////////////////////////    
    always @(posedge sys_clk,negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            digital_data <= 8'b0000_0000;
            sl_digital_vol <= 8'b0000_0000;
            sl_dac_lock_en <= 1'b0;
            
            sl_pre_op_en <= 1'b0;
            sl_addr_op_en <= 1'b0;
            
            sl_assert_en <= 1'b0;
        end
        else begin 
            case(state_now)
                IDLE:begin
                    sl_addr <= sl_addr_in;
                    
                    sl_dac_lock_en <= 1'b1; 
                    sl_digital_vol <= digital_data;            
                end
                PRE_OP:begin
                    if(last_cyc) begin                        
                        sl_dac_lock_en <= 1'b1;
                        sl_digital_vol <= digital_data;
                    end
                    else begin                        
                        sl_dac_lock_en <= 1'b0;
                        sl_digital_vol <= sl_digital_vol;
                    end                    
                end
                ADDR_OP:begin
                    if(last_cyc) begin
                       sl_assert_en <=1'b1;                       
                    end 
                    else begin
                        sl_assert_en <= 1'b0;
                    end
                    
                    sl_dac_lock_en <= 1'b0;
                    sl_digital_vol <= sl_digital_vol;                    
                end
                WAIT:begin
                    sl_addr <= sl_addr_in;                
                    sl_assert_en <= 1'b0;
                    
                    sl_dac_lock_en <= 1'b0;
                    sl_digital_vol <= sl_digital_vol;                    
                end
                default:begin
                    digital_data <= 8'b0000_0000;
                    sl_digital_vol <= 8'b0000_0000;
                    sl_dac_lock_en <= 1'b0;
            
                    sl_pre_op_en <= 1'b0;
                    sl_addr_op_en <= 1'b0;
            
                    sl_assert_en <= 1'b0;
                end
            endcase
        end
    end    
    
endmodule
