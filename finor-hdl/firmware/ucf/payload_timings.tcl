set DEBUG 1

set_multicycle_path 9 -setup -start -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]
set_multicycle_path 8 -hold -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]

if {DEBUG} {
	set mux_dest_SLRn0 [get_pins -of_objects [get_cells payload/*SLRn0_mux*/*input_reg_reg*] -filter {Name =~ */D}]
	set mux_clk_SLRn0 [get_pins -of_objects [get_cells payload/*SLRn1_mux*/*input_reg_reg*] -filter {Name =~ */C}]
	set mux_dest_SLRn1 [get_pins -of_objects [get_cells payload/*SLRn1_mux*/*input_reg_reg*] -filter {Name =~ */D}] 
	set mux_clk_SLRn1 [get_pins -of_objects [get_cells payload/*SLRn1_mux*/*input_reg_reg*] -filter {Name =~ */C}] 
    
    
    set_multicycle_path 9 -setup -from [get_pins $mux_clk_SLRn0] -to [get_pins $mux_dest_SLRn0]
    set_multicycle_path 8 -hold  -end  -from [get_pins $mux_clk_SLRn0] -to [get_pins $mux_dest_SLRn0 ]
    
	set_multicycle_path 9 -setup -from [get_pins $mux_clk_SLRn1] -to [get_pins $mux_dest_SLRn1]
    set_multicycle_path 8 -hold  -end  -from [get_pins $mux_clk_SLRn1] -to [get_pins $mux_dest_SLRn1 ]
    
}
