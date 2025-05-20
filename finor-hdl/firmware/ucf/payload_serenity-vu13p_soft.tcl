#Area constraints for VU13P P2GT
set SLR_n2  SLR3
set SLR_n1  SLR2
set SLR_n0  SLR1
set SLR_out SLR0
set N_MONITOR_SLR 3

add_cells_to_pblock [get_pblock payload] payload

set_property USER_SLR_ASSIGNMENT $SLR_n0  [get_cells -hierarchical -filter {NAME =~ *SLRn0_module}]
set_property USER_SLR_ASSIGNMENT $SLR_out [get_cells payload/SLRout_FinalOR_or]
if {$N_MONITOR_SLR > 1} {
	set_property USER_SLR_ASSIGNMENT $SLR_n1  [get_cells -hierarchical -filter {NAME =~ *SLRn1_module}]
}
if {$N_MONITOR_SLR > 2} {
	set_property USER_SLR_ASSIGNMENT $SLR_n2  [get_cells -hierarchical -filter {NAME =~ *SLRn2_module}]
}

#Remove link mergers from payload pblock
remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn0_module/Left_merge}]
remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn0_module/Right_merge}]

if {$N_MONITOR_SLR > 1} {
	remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn1_module/Left_merge}]
	remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn1_module/Right_merge}]
}
if {$N_MONITOR_SLR > 2} {
	remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn2_module/Left_merge}]
	remove_cells_from_pblock [get_pblock payload] [get_cells -hierarchical -filter {NAME =~ *SLRn2_module/Right_merge}]
}

create_pblock link_merger_SLRn0_L
resize_pblock [get_pblocks link_merger_SLRn0_L] -add {SLICE_X17Y479:SLICE_X30Y240}
add_cells_to_pblock [get_pblock link_merger_SLRn0_L]  [get_cells -hierarchical -filter {NAME =~ *SLRn0_module/Left_merge}]

create_pblock link_merger_SLRn0_R
resize_pblock [get_pblocks link_merger_SLRn0_R] -add {SLICE_X202Y479:SLICE_X215Y240}
add_cells_to_pblock [get_pblock link_merger_SLRn0_R]  [get_cells -hierarchical -filter {NAME =~ *SLRn0_module/Right_merge}]

if {$N_MONITOR_SLR > 1} {
	create_pblock link_merger_SLRn1_L
	resize_pblock [get_pblocks link_merger_SLRn1_L] -add {SLICE_X17Y719:SLICE_X30Y480}
	add_cells_to_pblock [get_pblock link_merger_SLRn1_L]  [get_cells -hierarchical -filter {NAME =~ *SLRn1_module/Left_merge}]

	create_pblock link_merger_SLRn1_R
	resize_pblock [get_pblocks link_merger_SLRn1_R] -add {SLICE_X202Y719:SLICE_X215Y480}
	add_cells_to_pblock [get_pblock link_merger_SLRn1_R]  [get_cells -hierarchical -filter {NAME =~ *SLRn1_module/Right_merge}]
}

if {$N_MONITOR_SLR > 2} {
	create_pblock link_merger_SLRn2_L
	resize_pblock [get_pblocks link_merger_SLRn2_L] -add {SLICE_X17Y959:SLICE_X30Y720}
	add_cells_to_pblock [get_pblock link_merger_SLRn2_L]  [get_cells -hierarchical -filter {NAME =~ *SLRn2_module/Left_merge}]

	create_pblock link_merger_SLRn2_R
	resize_pblock [get_pblocks link_merger_SLRn2_R] -add {SLICE_X202Y959:SLICE_X215Y720}
	add_cells_to_pblock [get_pblock link_merger_SLRn2_R]  [get_cells -hierarchical -filter {NAME =~ *SLRn2_module/Right_merge}]
}
