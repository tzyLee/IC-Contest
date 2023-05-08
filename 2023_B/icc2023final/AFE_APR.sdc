# operating conditions and boundary conditions #


create_clock -name clk  -period 10.0   [get_ports  clk]      ;#Modify period by yourself (but dont over 20)

set_clock_uncertainty  0.1  [all_clocks]
set_clock_latency      1.0  [all_clocks]


#Don't touch the basic env setting as below
set_input_delay  -max 1.0   -clock clk [remove_from_collection [all_inputs]  {clk}]  
set_input_delay  -min 0.0   -clock clk [remove_from_collection [all_inputs]  {clk}] 

set_output_delay -max 1.0   -clock clk [all_outputs]
set_output_delay -min 0.0   -clock clk [all_outputs] 


set_load         0.1   [all_outputs]
set_drive        0.1   [all_inputs]

set_operating_conditions -max_library slow -max slow  -min_library  slow  -min  slow

set_max_capacitance 0.1 [all_inputs]


