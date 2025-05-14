# 1kArray_control
This project achieves the function to select a targeted memristor in an 1k bit crossbar and execute RESET/SET/READ operations to it

Adopting System verilog to describe the behaviour of analog circuits,utilizing "interface modport" syntax to fulfill inout port

The flaw of the project can be divided into two aspects:For the READ operation,due to the design shortage,the module can't assert 0
voltage on Sl bus through its corresponding DAC;for the project itself,it is accomplished purely on digital level,which should have been designed
via anolog-digital hybrid simulation
