# =============================================================================
# show_boundary.jl — Display model boundary conditions
# =============================================================================

using Printf

"""
	display_boundary_conditions(NB, NL, NG, NT, ND, unit, load, lines, wind, storage)

Print a detailed summary of all model boundary conditions to the console.
"""
function display_boundary_conditions(NB, NL, NG, NT, ND,
                                      unit::Unit, load::Load,
                                      lines::TransmissionLine, wind::Wind,
                                      storage::Storage)
	NS = wind.num_scenarios
	NW = length(wind.index)

	println("\n" * "="^60)
	println("SYSTEM BOUNDARY CONDITIONS")
	println("="^60)
	println("  Buses (NB):        $NB")
	println("  Lines (NL):        $NL")
	println("  Generators (NG):   $NG")
	println("  Loads (ND):        $ND")
	println("  Time periods (NT): $NT")
	println("  Wind units (NW):   $NW")
	println("  Scenarios (NS):    $NS")
	println("-"^60)

	println("\n--- Thermal Units ---")
	for f in [:index, :locatebus, :p_max, :p_min, :ramp_up, :ramp_down,
	          :shut_up, :shut_down, :min_up_time, :min_down_time,
	          :x_0, :t_0, :p_0, :coeff_a, :coeff_b, :coeff_c,
	          :cold_start_cost, :cold_shutdown_cost]
		println("  $f: ", getfield(unit, f))
	end

	println("\n--- Loads ---")
	println("  index:     ", load.index)
	println("  locatebus: ", load.locatebus)
	println("  curve (ND×NT):")
	for i in 1:ND
		print("    Load $i: ")
		for j in 1:NT
			@printf("%8.3f ", load.curve[i, j])
		end
		println()
	end

	println("\n--- Lines ---")
	println("  from:   ", lines.from)
	println("  to:     ", lines.to)
	println("  x:      ", lines.x)
	println("  p_max:  ", lines.p_max)
	println("  p_min:  ", lines.p_min)

	println("\n--- Wind ---")
	println("  index:        ", wind.index)
	println("  p_max:        ", wind.p_max)
	println("  scenarios:    ", wind.num_scenarios)
	println("  probability:  ", wind.prob)

	println("\n--- Storage ---")
	println("  index:       ", storage.index)
	println("  locatebus:   ", storage.locatebus)
	println("  Q_max:       ", storage.Q_max)
	println("  Q_min:       ", storage.Q_min)
	println("  p_charge:    ", storage.p_charge)
	println("  p_discharge: ", storage.p_discharge)
	println("  η_charge:    ", storage.eta_charge)
	println("  η_discharge: ", storage.eta_discharge)
	println("="^60)
end
