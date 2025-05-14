`timescale 1ns/1ps

interface inout_port8;
    real bus8[7:0];
    modport drive8 (output bus8);
    modport read8 (input bus8);
endinterface


module adc_sl #(
    parameter WIDTH = 8,
    parameter real VREF = 265.0
)(
    input real analog_in,
    output logic [WIDTH-1:0] digital_out
);

real val;

    always_comb begin
        val = analog_in;
        if (val < 0.0) val = 0.0;
        if (val > VREF) val = VREF;
        digital_out = $floor((val / VREF) * ((2**WIDTH) - 1));
    end

endmodule

module dac_sl #(
    parameter WIDTH = 8,
    parameter real VREF = 3.3
)(
    input logic [WIDTH-1:0] digital_in,
    output real analog_out
);

    real analog_val;

    always_comb begin
        analog_val = (VREF * digital_in) / (2.0**WIDTH - 1);
        
    end
    assign analog_out = analog_val;

endmodule


///////////////////////////////////////////////////////////////////////////////////
module macsl_converter_interface(

//input logic sys_clk,
input logic sys_rst_n,

input read_mode,//指示模块工作在读模式

input logic adc_lock_en,
inout_port8.read8 adc_lock_in,//adc锁存器输入

input logic dac_lock_en,
input logic [7:0] digital_data,
inout_port8.drive8 dac_out, 

input [2:0] addr,//指示选取adc读出字节中bit位
output logic [7:0] digital_read//adc读出bit数据
);
real adc_data[7:0];//adc输入
logic [7:0] digital_byte_read [7:0];//adc读出8bit数据

assign digital_read = digital_byte_read[addr];

logic [7:0] dac_data;//dac输入

real bus_inner[7:0];//内部连线
//
    always_latch begin
        if (!sys_rst_n)
            for (int i = 0; i < 8; i++) begin        
                adc_data[i] = 0.0;            
        end else if(adc_lock_en&&read_mode)
            for (int i = 0; i < 8; i++) begin        
                adc_data[i] = adc_lock_in.bus8[i];
        end 
//        else 
//            for (int i = 0; i < 8; i++) begin        
//                adc_data[i] = adc_data[i];
//        end 
    end
    
    always_latch begin
        if (!sys_rst_n)
            dac_data = 0.0;
        else if(dac_lock_en)
            dac_data = digital_data;
        else 
            dac_data = dac_data;
    end     
    
always_comb begin
  // 先把 bus 全部清 0.0（或 'hz'）
  for (int i=0; i<8; i++)
    dac_out.bus8[i] = 0.0;

  if (!read_mode) begin
    // 写模式：真正推送 bus_inner
    for (int i=0; i<8; i++)
      dac_out.bus8[i] = bus_inner[i];
  end
  // else read_mode: 保持 0.0 即可
end


    
    adc_sl u1_adc_sl(.analog_in(adc_data[0]),.digital_out(digital_byte_read[0]));
    adc_sl u2_adc_sl(.analog_in(adc_data[1]),.digital_out(digital_byte_read[1]));    
    adc_sl u3_adc_sl(.analog_in(adc_data[2]),.digital_out(digital_byte_read[2]));
    adc_sl u4_adc_sl(.analog_in(adc_data[3]),.digital_out(digital_byte_read[3]));
    adc_sl u5_adc_sl(.analog_in(adc_data[4]),.digital_out(digital_byte_read[4]));
    adc_sl u6_adc_sl(.analog_in(adc_data[5]),.digital_out(digital_byte_read[5]));
    adc_sl u7_adc_sl(.analog_in(adc_data[6]),.digital_out(digital_byte_read[6]));
    adc_sl u8_adc_sl(.analog_in(adc_data[7]),.digital_out(digital_byte_read[7]));
    
    dac_sl u1_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[0]));
    dac_sl u2_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[1]));    
    dac_sl u3_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[2]));
    dac_sl u4_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[3]));
    dac_sl u5_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[4]));
    dac_sl u6_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[5]));
    dac_sl u7_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[6]));
    dac_sl u8_dac_sl(.digital_in(dac_data),.analog_out(bus_inner[7]));
    
endmodule
