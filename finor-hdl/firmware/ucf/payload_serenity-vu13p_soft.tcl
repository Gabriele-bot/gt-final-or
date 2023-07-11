#Area constraints for VU13P P2GT
set SLR_n2  SLR3
set SLR_n1  SLR2
set SLR_n0  SLR0
set SLR_out SLR1

#add lower row to pblock
#TODO Modify this
#resize_pblock [get_pblocks payload] -add {CLOCKREGION_X0Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X1Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X2Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X3Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X4Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X5Y0}
resize_pblock [get_pblocks payload] -add {CLOCKREGION_X6Y0}

add_cells_to_pblock [get_pblock payload] payload

set_property USER_SLR_ASSIGNMENT $SLR_n0  [get_cells payload/SLRn0_module]
set_property USER_SLR_ASSIGNMENT $SLR_out [get_cells payload/SLRout_FinalOR_or]
set_property USER_SLR_ASSIGNMENT $SLR_n1  [get_cells payload/SLRn1_module]
set_property USER_SLR_ASSIGNMENT $SLR_n2  [get_cells payload/SLRn2_module]

create_pblock link_merger_SLRn0_L
resize_pblock [get_pblocks link_merger_SLRn0_L] -add {SLICE_X17Y239:SLICE_X30Y0}
add_cells_to_pblock [get_pblock link_merger_SLRn0_L]  [get_cells payload/SLRn0_module/Left_merge]

create_pblock link_merger_SLRn0_R
resize_pblock [get_pblocks link_merger_SLRn0_R] -add {SLICE_X202Y239:SLICE_X215Y0}
add_cells_to_pblock [get_pblock link_merger_SLRn0_R]  [get_cells payload/SLRn0_module/Right_merge]

create_pblock link_merger_SLRn1_L
resize_pblock [get_pblocks link_merger_SLRn1_L] -add {SLICE_X17Y719:SLICE_X30Y480}
add_cells_to_pblock [get_pblock link_merger_SLRn1_L]  [get_cells payload/SLRn1_module/Left_merge]

create_pblock link_merger_SLRn1_R
resize_pblock [get_pblocks link_merger_SLRn1_R] -add {SLICE_X202Y719:SLICE_X215Y480}
add_cells_to_pblock [get_pblock link_merger_SLRn1_R]  [get_cells payload/SLRn1_module/Right_merge]

create_pblock link_merger_SLRn2_L
resize_pblock [get_pblocks link_merger_SLRn2_L] -add {SLICE_X17Y959:SLICE_X30Y720}
add_cells_to_pblock [get_pblock link_merger_SLRn2_L]  [get_cells payload/SLRn2_module/Left_merge]

create_pblock link_merger_SLRn2_R
resize_pblock [get_pblocks link_merger_SLRn2_R] -add {SLICE_X202Y959:SLICE_X215Y720}
add_cells_to_pblock [get_pblock link_merger_SLRn2_R]  [get_cells payload/SLRn2_module/Right_merge]
