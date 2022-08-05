#Area constraints for VU13P P2GT

add_cells_to_pblock [get_pblock payload] payload

#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X0Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X1Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X2Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X3Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X4Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X5Y0}
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X6Y0}

set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -hierarchical -filter {NAME =~ payload/SLR0*}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -hierarchical -filter {NAME =~ payload/SLR1*}]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -hierarchical -filter {NAME =~ payload/SLR2*}]
