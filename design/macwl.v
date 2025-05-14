`timescale 1ns / 1ps


module mac_wlcontrol(
input sys_clk,
input sys_rst_n,
//工作开始信号
input work_en,
input work_mode,//1是write,0是read
//input awake,
//BL输入地址与操作模式
input [4:0] wl_addr_in,
input [7:0] wl_digital_vol_in,
//代表wl脉冲结束
//BL_DAC控制信号与数据
output reg [7:0] wl_digital_vol,
output reg wl_dac_lock_en,
//bl_array_if控制信号与地址
output reg [4:0] wl_addr,
output reg wl_pre_op_en,
output reg wl_addr_op_en,
input bl_over,sl_over,
//阵列控制信号
output reg wl_assert_en,
output op_down_com,//操作即将结束标志
output reg pulse_down,//脉冲结束标志
output reg read_down//READ操作结束标志
    );
/////////////////////////////////////////////////    
parameter IDLE = 3'b001;
parameter PRE_OP = 3'b010;
parameter ADDR_OP = 3'b011;
parameter WAIT_BLSL = 3'b100;
parameter WAIT_OVER =3'b101;
parameter WAIT_READ = 3'b110;

    
reg [2:0] state_now,state_next;

///////////////////////////////////////////////
parameter TIME_DAC = 8'b0000_1010;
parameter TIME_ADC = 8'b0000_1010;
parameter TIME_PULSE = 8'b0000_1010;

reg [7:0] timer,timer_next;
wire last_cyc;
assign last_cyc = (timer ==8'b0000_0001);
assign load_en = (timer_next == 8'b0000_0001);

reg [1:0] load_cnt;
wire last_load;
assign last_load = (load_cnt == 2'b11);
////////////////////工作状态相关更新//////////////////////////
reg [7:0] digital_data;

reg op_down;
reg read_down_en;
assign op_down_com = work_mode?op_down:read_down_en;

    always @(posedge sys_clk,negedge sys_rst_n)
        if(!sys_rst_n) begin
            pulse_down <= 1'b0;
            op_down <= 1'b0;
            read_down_en <= 1'b0;
        end
        else if(op_down) begin
            pulse_down <= 1'b1;
        end else
            pulse_down <=1'b0;
            
//    always @(posedge sys_clk,negedge sys_rst_n)
//        if(!sys_rst_n)
//            read_down_en <= 1'b0;
//        else if(pulse_down&&(!work_mode))
//            read_down_en <= 1'b1;
//        else 
//            read_down_en <=1'b0;
            
    always @(posedge sys_clk,negedge sys_rst_n)
        if(!sys_rst_n)
            read_down <= 1'b0;
        else if(read_down_en&&(!work_mode))
            read_down <= 1'b1;
        else 
            read_down <=1'b0;      
/////////////////////状态同步更新//////////////////////////    
    always @(posedge sys_clk,negedge sys_rst_n)
        if (!sys_rst_n) begin
            state_now <= IDLE;
            state_next <= IDLE;
            
            timer <= 8'b0000_0000;
            timer_next <= 8'b0000_0000;   
            
            wl_pre_op_en = 1'b0;
            wl_addr_op_en = 1'b0;                                     
        end
        else begin
            state_now <= state_next;
            
            timer <= timer_next;
        end
        
    always @(posedge sys_clk,negedge sys_rst_n) begin
        if(!sys_rst_n)
            load_cnt <= 2'b00;    
        else if (load_en)
            load_cnt <= load_cnt+1;
        else if(load_cnt==2'b11)
            load_cnt <= 2'b00;
    end
    
    always @(posedge sys_clk,negedge sys_rst_n)
        if(!sys_rst_n)
            wl_assert_en <= 1'b0;
        else if ((bl_over && (!work_mode||sl_over))||last_load)
            wl_assert_en <= 1'b1;
        else wl_assert_en <= 1'b0;
            
    always @(*) begin
        case(state_now)
            IDLE:begin 
                if(work_en) begin
                    state_next = PRE_OP;
                    timer_next = TIME_DAC;

                    digital_data = 8'b0000_0000;                   
                end
                else begin
                    state_next = state_now;
                    timer_next = timer;
                
                    digital_data = digital_data;
                    
                    wl_pre_op_en = 1'b0;
                    wl_addr_op_en = 1'b0;      
                    
                    op_down = 1'b0;        
                    read_down_en = 1'b0;            
                end
            end
            PRE_OP:begin
                if (last_cyc) begin
                    state_next = ADDR_OP;
                    timer_next = TIME_DAC;
                    
                    wl_pre_op_en = 1'b1;
                    wl_addr_op_en = 1'b0;
                    
                    digital_data = wl_digital_vol_in;
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;
                    
                    wl_pre_op_en = 1'b0;
                    wl_addr_op_en = 1'b0;
                    
                    digital_data = digital_data;
                end
            end  
            ADDR_OP:begin
                if (last_cyc) begin
                    if(last_load) begin
                        state_next = WAIT_OVER;
                        timer_next = TIME_PULSE;
                    end
                    else begin
                        state_next = WAIT_BLSL;
                        timer_next = 8'b0000_0000;    
                    end                                        
                    wl_pre_op_en = 1'b0;
                    wl_addr_op_en = 1'b1;                                                   
                end
                else begin
                    state_next = state_now;
                    timer_next = timer-1;        
                    
                    wl_pre_op_en = 1'b0;
                    wl_addr_op_en = 1'b0;                                                             
                end                                       
                digital_data = digital_data;           
            end
            WAIT_BLSL:begin//只等一个周期，无条件跳转
                state_next = ADDR_OP;
                timer_next = TIME_PULSE;
                
                wl_pre_op_en = 1'b0;
                wl_addr_op_en = 1'b0;
                
                digital_data = 8'b0000_0000;           
            end
            WAIT_OVER:begin
                if(last_cyc) begin
                    op_down = 1'b1;
                    
                    if(work_mode) begin
                        state_next = IDLE;
                        timer_next = 8'b0000_0000;
                    end
                    else begin
                        state_next = WAIT_READ;
                        timer_next = TIME_ADC;
                    end
                end else begin
                    op_down =1'b0;
                    
                    state_next = state_now;
                    timer_next = timer-1;                    
                end
                wl_pre_op_en = 1'b0;
                wl_addr_op_en = 1'b0;
                
                digital_data = 8'b0000_0000;                     
            end
            WAIT_READ:begin
                if(last_cyc) begin
                        state_next = IDLE;
                        timer_next = 8'b0000_0000;                
                        
                        read_down_en = 1'b1;
                end else begin
                        state_next = state_now;
                        timer_next = timer-1;                
                        
                        read_down_en = 1'b0;                                
                end
                op_down = 1'b0;                
            end
            default:begin
                state_next = IDLE;
                timer_next = 8'b0000_0000;
                
                digital_data = 8'b0000_0000;
                wl_addr_op_en = 1'b0;
                wl_pre_op_en = 1'b0;
                
                op_down = 1'b0;
            end
        endcase
    end        
//////////////////////////dac_lock、assert_en同步加载/////////////////////////////////////    
    always @(posedge sys_clk,negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            digital_data <= 8'b0000_0000;
            wl_digital_vol <= 8'b0000_0000;
            wl_dac_lock_en <= 1'b0;             
        end
        else begin 
            case(state_now)
                IDLE:begin
                    wl_addr <= wl_addr_in;
                    
                    wl_dac_lock_en <= 1'b1; 
                    wl_digital_vol <= digital_data;            
                end
                PRE_OP:begin
                    if(last_cyc) begin                        
                        wl_dac_lock_en <= 1'b1;
                        wl_digital_vol <= digital_data;
                    end
                    else begin                        
                        wl_dac_lock_en <= 1'b0;
                        wl_digital_vol <= wl_digital_vol;
                    end                    
                end
                ADDR_OP:begin
                    if(last_cyc && last_load) begin        
                        wl_dac_lock_en <= 1'b1;
                        wl_digital_vol <= digital_data;   
                    end 
                    else begin
                        wl_dac_lock_en <= 1'b0;
                        wl_digital_vol <= wl_digital_vol;                        
                    end
                    
                    wl_dac_lock_en <= 1'b0;
                    wl_digital_vol <= wl_digital_vol;                    
                end
                WAIT_BLSL:begin                    
                    wl_dac_lock_en <= 1'b1;
                    wl_digital_vol <= digital_data;                    
                end
                WAIT_OVER:begin
                    wl_dac_lock_en <= 1'b0;
                    wl_digital_vol <= wl_digital_vol;  
                end
                default:begin
                    digital_data <= 8'b0000_0000;
                    wl_digital_vol <= 8'b0000_0000;
                    wl_dac_lock_en <= 1'b0;
                end
            endcase
        end
    end    
    
endmodule
