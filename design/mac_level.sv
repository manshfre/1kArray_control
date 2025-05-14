`timescale 1ns / 1ps

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

//////////////////////////////////////////////////////////////////////////////////
module mac_level(

input logic sys_clk,
input logic sys_rst_n,
//工作相关输入
input logic work_en,
input op_mode,//1是set,0是reset
input work_mode,//1是write,0是read
//input awake,
//输入地址与目标电流
input logic [9:0] addr_in,
input logic [7:0] v_wl,
//从阵列读到的电流
output logic work_down,
output logic [7:0] i_read,
output real mem_out[1024]
    );
    
logic [7:0] wl_to_dac;
logic [7:0] bl_to_dac;
logic [7:0] sl_to_dac;

logic bl_dac_latch;
logic wl_dac_latch;    
logic sl_dac_latch;

logic [4:0] bl_addr;
logic [4:0] wl_addr;
logic [4:0] sl_addr;

logic bl_pre_op_ena,bl_addr_op_ena;
logic wl_pre_op_ena,wl_addr_op_ena;
logic sl_pre_op_ena,sl_addr_op_ena;

logic bl_assert_ena;
logic sl_assert_ena;
logic wl_assert_ena;

logic op_down;
logic pulse_down;
logic read_en;
logic read_mode;
logic read_down;
assign read_mode =!work_mode;
assign work_down = work_mode ? pulse_down: read_down;

real bl_dac_out[8];
real wl_dac_out[8];

real bl_interface_out[32];
real wl_interface_out[32];

inout_port8 bus_converter_bank();
inout_port8 bus_bank_converter();
inout_port32 bus_array_bank();
inout_port32 bus_bank_array();

mac_blcontrol u_mac_blcontrol(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.work_en(work_en),.work_mode(work_mode),.bl_addr_in(addr_in[9:5]),.op_mode(op_mode),.op_down(op_down),
.bl_digital_vol(bl_to_dac),.bl_dac_lock_en(bl_dac_latch),.bl_addr(bl_addr),.bl_pre_op_en(bl_pre_op_ena),.bl_addr_op_en(bl_addr_op_ena),
.bl_assert_en(bl_assert_ena));


mac_wlcontrol u_mac_wlcontrol(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.work_en(work_en),.work_mode(work_mode),.wl_addr_in(addr_in[4:0]),.wl_digital_vol_in(v_wl),
.wl_digital_vol(wl_to_dac),.wl_dac_lock_en(wl_dac_latch),.wl_addr(wl_addr),.wl_pre_op_en(wl_pre_op_ena),.wl_addr_op_en(wl_addr_op_ena),
.bl_over(bl_assert_ena),.sl_over(sl_assert_ena),.wl_assert_en(wl_assert_ena),.op_down_com(op_down),.pulse_down(pulse_down),.read_down(read_down));

mac_slcontrol u_mac_slcontrol(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.work_en(work_en),.work_mode(work_mode),.sl_addr_in(addr_in[4:0]),.op_mode(op_mode),.op_down(op_down),
.sl_digital_vol(sl_to_dac),.sl_dac_lock_en(sl_dac_latch),.sl_addr(sl_addr),.sl_pre_op_en(sl_pre_op_ena),.sl_addr_op_en(sl_addr_op_ena),
.sl_assert_en(sl_assert_ena));

macbl_dac_interface u_macbl_dac_interface(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
.dac_lock_en(bl_dac_latch),.digital_data(bl_to_dac),.analog_out(bl_dac_out));

macwl_dac_interface u_macwl_dac_interface(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
.dac_lock_en(wl_dac_latch),.digital_data(wl_to_dac),.analog_out(wl_dac_out));

macsl_converter_interface u_macsl_converter_interface(.sys_rst_n(sys_rst_n),.read_mode(read_mode),
.adc_lock_en(read_down),.dac_lock_en(sl_dac_latch),.digital_data(sl_to_dac),.addr(addr_in[2:0]),.
digital_read(i_read),.adc_lock_in(bus_bank_converter),.dac_out(bus_converter_bank));


bl_interface u_bl_interface(.clk(sys_clk),.rst_n(sys_rst_n),
.bl_addr_en(bl_addr_op_ena),.bl_pre_op_en(bl_pre_op_ena),.addr(bl_addr),.op_vol(bl_dac_out),.out_data(bl_interface_out));    

wl_interface u_wl_interface(.clk(sys_clk),.rst_n(sys_rst_n),
.wl_addr_en(wl_addr_op_ena),.wl_pre_op_en(wl_pre_op_ena),.addr(wl_addr),.op_vol(wl_dac_out),.out_data(wl_interface_out));    

sl_bank u_sl_bank(.clk(sys_clk),.rst_n(sys_rst_n),.
sl_addr_en(sl_addr_op_ena),.sl_pre_op_en(sl_pre_op_ena),.addr(sl_addr),.read_mode(read_mode),.//这里改了，之前是pulse_down
bus_dac(bus_converter_bank),.bus_adc(bus_bank_converter),.bus_arr_in(bus_array_bank),.bus_arr_out(bus_bank_array));


mem_array u_mem_array(.tran_en(pulse_down),.rst_n(sys_rst_n),.addr_tar(addr_in),.bl_assert_en(bl_assert_ena),.V_BL(bl_interface_out),
.wl_assert_en(wl_assert_ena),.V_WL(wl_interface_out),.sl_assert_en(sl_assert_ena),
.read_mode(read_mode),.SL_vol(bus_bank_array),.SL_current(bus_array_bank),.G_c_reg(mem_out));

    
endmodule
