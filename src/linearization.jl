# =============================================================================
# linearization.jl — Fuel cost curve piecewise linearization
# =============================================================================

"""
	linearize_fuel_curve(unit, NG)

Compute the piecewise-linear approximation of the quadratic fuel cost curve.
Returns `(ref_cost, slopes)` where slopes is a 3×NG array of segment slopes.
"""
function linearize_fuel_curve(unit::Unit, NG::Int64)
	seg_size = (unit.p_max - unit.p_min) / 3.0
	cost = zeros(NG, 4)

	temp = unit.p_min
	cost[:, 1] = unit.coeff_a .* (unit.p_min .^ 2) +
	             unit.coeff_b .* unit.p_min +
	             unit.coeff_c
	for i in 2:4
		temp = temp + seg_size
		cost[:, i] = unit.coeff_a .* (temp .^ 2) +
		             unit.coeff_b .* temp +
		             unit.coeff_c
	end

	slopes = zeros(NG, 3)
	for i in 1:3
		slopes[:, i] = (cost[:, i+1] - cost[:, i]) ./ seg_size
	end

	return cost[:, 1], slopes'
end
