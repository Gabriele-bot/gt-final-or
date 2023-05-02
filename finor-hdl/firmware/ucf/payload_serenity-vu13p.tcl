#Area constraints for VU13P P2GT
set SLR_n1  SLR2
set SLR_n0  SLR0
set SLR_out SLR1

add_cells_to_pblock [get_pblock payload] payload

#add lower row to pblock
#TODO Modify this
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X0Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X1Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X2Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X3Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X4Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X5Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X6Y0}

set_property USER_SLR_ASSIGNMENT $SLR_n0  [get_cells -hierarchical -filter {NAME =~ *payload/SLRn0*}]
set_property USER_SLR_ASSIGNMENT $SLR_out [get_cells -hierarchical -filter {NAME =~ *payload/SLRout*}]
set_property USER_SLR_ASSIGNMENT $SLR_n1  [get_cells -hierarchical -filter {NAME =~ *payload/SLRn1*}]

#MUX
set_property USER_SLR_ASSIGNMENT $SLR_n0 [get_cells -hierarchical -filter {NAME =~ *SLRn0_mux*}]
set_property USER_SLR_ASSIGNMENT $SLR_n1 [get_cells -hierarchical -filter {NAME =~ *SLRn1_mux*}]
