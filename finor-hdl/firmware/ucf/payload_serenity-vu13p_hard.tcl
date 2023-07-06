#Area constraints for VU13P P2GT
set SLR_n2  SLR3
set SLR_n1  SLR2
set SLR_n0  SLR0
set SLR_out SLR1

create_pblock pblock_SLR_n2
resize_pblock pblock_SLR_n2 -add $SLR_n2
create_pblock pblock_SLR_n1
resize_pblock pblock_SLR_n1 -add $SLR_n1
create_pblock pblock_SLR_n0
resize_pblock pblock_SLR_n0 -add $SLR_n0
create_pblock pblock_SLR_out
resize_pblock pblock_SLR_out -add $SLR_out


#add_cells_to_pblock [get_pblock payload] payload

add_cells_to_pblock [get_pblock pblock_SLR_n2]  [get_cells -hierarchical -filter {NAME =~ *payload/SLRn2*}]
add_cells_to_pblock [get_pblock pblock_SLR_n1]  [get_cells -hierarchical -filter {NAME =~ *payload/SLRn1*}]
add_cells_to_pblock [get_pblock pblock_SLR_n0]  [get_cells -hierarchical -filter {NAME =~ *payload/SLRn0*}]
add_cells_to_pblock [get_pblock pblock_SLR_out] [get_cells -hierarchical -filter {NAME =~ *payload/SLRout*}]

set_property keep_hierarchy no [get_cells -hierarchical -filter {NAME =~ *payload/SLRn0*/monitoring_module}]
set_property keep_hierarchy no [get_cells -hierarchical -filter {NAME =~ *payload/SLRn1*/monitoring_module}]
set_property keep_hierarchy no [get_cells -hierarchical -filter {NAME =~ *payload/SLRn2*/monitoring_module}]

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
