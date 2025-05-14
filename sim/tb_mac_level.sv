`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////


module tb_mac_level(

    );
logic sys_clk;
logic sys_rst_n;

logic work_en;
logic op_mode;
logic work_mode;
logic work_down;

logic [9:0] addr_in;
logic [7:0] v_wl;
logic [7:0] i_read;
    
real outbuffer[1024];

mac_level u_mac_level(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.i_read(i_read),.v_wl(v_wl),.mem_out(outbuffer),.addr_in(addr_in),
.work_down(work_down),.work_en(work_en),.op_mode(op_mode),.work_mode(work_mode));
    
initial begin
sys_clk=0;
sys_rst_n=1;
work_en=0;
op_mode=1;//进行set操作
work_mode=0;//write模式
#3
sys_rst_n=0;
#3 
sys_rst_n=1;
addr_in=10'b00000_00110;
v_wl = 8'b10000001;
#2
work_en=1;
end

initial 
#430 work_en = 1'b0;

always #5 sys_clk=~sys_clk;

endmodule
