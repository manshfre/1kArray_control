`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////////
module dac_forge #(
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
module macwl_dac_interface(

input logic sys_clk,
input logic sys_rst_n,

input logic dac_lock_en,
input logic [7:0] digital_data,

output real analog_out[8]
);

logic [7:0] dac_data;

    always_latch begin
        if (!sys_rst_n)
            dac_data = 8'b0;
        else if(dac_lock_en)
            dac_data = digital_data;
        else 
            dac_data = dac_data;
    end 
    
    dac_forge u1_dac_forge(.digital_in(dac_data),.analog_out(analog_out[0]));
    dac_forge u2_dac_forge(.digital_in(dac_data),.analog_out(analog_out[1]));    
    dac_forge u3_dac_forge(.digital_in(dac_data),.analog_out(analog_out[2]));
    dac_forge u4_dac_forge(.digital_in(dac_data),.analog_out(analog_out[3]));
    dac_forge u5_dac_forge(.digital_in(dac_data),.analog_out(analog_out[4]));
    dac_forge u6_dac_forge(.digital_in(dac_data),.analog_out(analog_out[5]));
    dac_forge u7_dac_forge(.digital_in(dac_data),.analog_out(analog_out[6]));
    dac_forge u8_dac_forge(.digital_in(dac_data),.analog_out(analog_out[7]));
    
    
endmodule