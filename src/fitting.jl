# =============================================================================
# fitting.jl — Frequency response fitting parameter generation
# =============================================================================

using Clustering, MultivariateStats

"""
	generate_frequency_fitting_params(units, winds, NG, NW, NN, method, μ, σ)

Generate fitting parameters for frequency response analysis using
Monte Carlo sampling and k-means clustering.
"""
function generate_frequency_fitting_params(units::Unit, winds::Wind,
                                            NG, NW, NN, method, μ, σ)
	noise = rand(Normal(μ, σ), NN)
	prob  = cdf.(Normal(μ, σ), noise)
	params = zeros(NN, 4)

	for n in 1:NN
		params[n, :] = _create_fitting_function(units, winds, NG, NW, method, noise[n])
	end
	return params, noise, prob
end

"""
	create_fitting_parameters(units, winds, NG, NW, method, noise)

Generate fitting parameters via Monte Carlo + k-means + LP regression.
"""
function create_fitting_parameters(units::Unit, winds::Wind,
                                   NG, NW, method, noise)
	f_nadir, H, δp, Dg, Fg, Kg, Rg, status = _monte_carlo_simulation(
		units, winds, NG, NW, method, noise)

	res = hcat(H, Fg ./ Rg, 1 ./ Rg, f_nadir)
	res = sortslices(res; dims=1, lt=(x,y)->isless(x[1], y[1]))

	R = kmeans(transpose(res), 10; maxiter=200, display=:iter)
	centers = transpose(R.centers)
	n_centers = size(centers, 1)

	model = Model(Gurobi.Optimizer)
	set_silent(model)
	@variable(model, coeff[1:4])
	@variable(model, slack[1:n_centers] >= 0)
	@objective(model, Min, 1e3 * sum(slack))
	@constraint(model, [i=1:n_centers],
		slack[i] >= centers[i, 4] - sum(coeff[1:3] .* centers[i, 1:3]) - coeff[4])
	optimize!(model)

	return value.(coeff)
end

# Placeholder — implement with actual frequency response simulation
function _create_fitting_function(units, winds, NG, NW, method, noise)
	return zeros(4)
end

function _monte_carlo_simulation(units, winds, NG, NW, method, noise)
	return zeros(1201), 0, 0, 0, 0, 0, 0, 0, [1,1,0]
end
