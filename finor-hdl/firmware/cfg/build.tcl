set lPostPlaceScriptPath [ file dirname [ file normalize [ info script ] ] ]
append lPostPlaceScriptPath "/post_place.tcl"
puts "lPostPlaceScriptPath=$lPostPlaceScriptPath"

set lPostRouteScriptPath [ file dirname [ file normalize [ info script ] ] ]
append lPostRouteScriptPath "/post_route.tcl"
puts "lPostRouteScriptPath=$lPostRouteScriptPath"

set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
#set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AlternateRoutability [get_runs synth_1]

#set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
#set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.POST $lPostPlaceScriptPath [get_runs impl_1]

#set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
#set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

#set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
#set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AlternateCLBRouting [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.POST $lPostRouteScriptPath [get_runs impl_1]

#set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
#set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
#set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.POST $lPostRouteScriptPath [get_runs impl_1]


