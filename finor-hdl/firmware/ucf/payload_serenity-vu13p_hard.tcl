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
