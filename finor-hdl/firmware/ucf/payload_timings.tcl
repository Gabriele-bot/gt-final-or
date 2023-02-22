set DEBUG 1

set_multicycle_path 9 -setup -start -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]
set_multicycle_path 8 -hold -from [get_clocks -filter {NAME =~ clk_payload* }] -to [get_clocks -filter {NAME =~ clks_aux_u_2* }]

if {DEBUG} {
	set mux_input_reg [get_nets -of_objects [get_pins -of_objects [get_cells *payload/*mux*/input_reg*] -filter { DIRECTION == OUT }]]
	set mux_input_reg_pins [get_pins -leaf -filter {IS_ENABLE} -of $mux_input_reg]
	set mux_input_reg_cells [get_cells -of $mux_input_reg_pins]

	set_multicycle_path 9 -setup     -from [get_clocks -filter {NAME =~ clks_aux_u_2* }]-to $mux_input_reg_cells
	set_multicycle_path 8 -hold -end -from [get_clocks -filter {NAME =~ clks_aux_u_2* }]-to $mux_input_reg_cells
}
