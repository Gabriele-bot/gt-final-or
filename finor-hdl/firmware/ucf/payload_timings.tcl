set N_MONITOR_SLR 1

set_multicycle_path 9 -setup -start -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]
set_multicycle_path 8 -hold -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]

set mux_dest_SLRn0 [get_pins -of_objects [get_cells payload/*SLRn0_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */D}]
set mux_clk_SLRn0 [get_pins -of_objects [get_cells payload/*SLRn0_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */C}]
    
set_multicycle_path 9 -setup -from [get_pins $mux_clk_SLRn0] -to [get_pins $mux_dest_SLRn0]
set_multicycle_path 8 -hold  -end  -from [get_pins $mux_clk_SLRn0] -to [get_pins $mux_dest_SLRn0]

if {$N_MONITOR_SLR > 1} {
	set mux_dest_SLRn1 [get_pins -of_objects [get_cells payload/*SLRn1_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */D}] 
	set mux_clk_SLRn1 [get_pins -of_objects [get_cells payload/*SLRn1_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */C}]

	set_multicycle_path 9 -setup -from [get_pins $mux_clk_SLRn1] -to [get_pins $mux_dest_SLRn1]
	set_multicycle_path 8 -hold  -end  -from [get_pins $mux_clk_SLRn1] -to [get_pins $mux_dest_SLRn1]
}

if {$N_MONITOR_SLR > 2} {
	set mux_dest_SLRn2 [get_pins -of_objects [get_cells payload/*SLRn2_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */D}] 
	set mux_clk_SLRn2 [get_pins -of_objects [get_cells payload/*SLRn2_module*/*output_links_data*/*mux*/*input_360_reg_reg*] -filter {Name =~ */C}]

	set_multicycle_path 9 -setup -from [get_pins $mux_clk_SLRn2] -to [get_pins $mux_dest_SLRn2]
	set_multicycle_path 8 -hold  -end  -from [get_pins $mux_clk_SLRn2] -to [get_pins $mux_dest_SLRn2 ]
}   

#TODO maybe add the valid bit too?
