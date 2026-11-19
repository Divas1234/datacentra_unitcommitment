# =============================================================================
# optimization.jl — Core SUC-SCUC MILP (thermal + ESS + optional DCC)
# =============================================================================
# Layout:
#   1. Variables & objective
#   2. Unit / reserve / balance / ramp / PWL / network / ESS constraints
#   3. Optional DCC block (→ dcc.jl)
#   4. Solve + extract results
# =============================================================================

using JuMP, Gurobi

# --- Small constraint helpers (readability; same math) -------------------------

function _add_unit_commitment_logic!(model, x, u, v, unit, NG, NT)
	onoffinit = Float64[(unit.x_0[i] > 0.5) ? 1.0 : 0.0 for i in 1:NG]
	Lupmin   = [min(NT, unit.min_up_time[i] * onoffinit[i]) for i in 1:NG]
	Ldownmin = [min(NT, unit.min_down_time[i] * (1 - onoffinit[i])) for i in 1:NG]

	for i in 1:NG
		for t in Int(max(1, Lupmin[i])):NT
			LB = Int(max(t - unit.min_up_time[i] + 1, 1))
			@constraint(model, sum(u[i, r] for r in LB:t) <= x[i, t])
		end
		for t in Int(max(1, Ldownmin[i])):NT
			LB = Int(max(t - unit.min_down_time[i] + 1, 1))
			@constraint(model, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]))
		end
	end

	@constraint(model, [i = 1:NG, t = 1:NT],
		u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? unit.x_0[i] : x[i, t - 1]))
	@constraint(model, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)
	return nothing
end

function _add_startup_shutdown_cost!(model, su0, sd0, x, u, v, unit, NT)
	@constraint(model, su0[:, 1] .>= unit.cold_start_cost .* (x[:, 1] - unit.x_0))
	@constraint(model, sd0[:, 1] .>= unit.cold_shutdown_cost .* (unit.x_0 - x[:, 1]))
	@constraint(model, [t = 2:NT], su0[:, t] .>= unit.cold_start_cost .* u[:, t])
	@constraint(model, [t = 2:NT], sd0[:, t] .>= unit.cold_shutdown_cost .* v[:, t])
	return nothing
end

function _add_storage_constraints!(model, kappa_plus, kappa_minus, pc_plus, pc_minus,
                                   qc, alpha, beta, storage, NS, NC, NT)
	@constraint(model, [s = 1:NS, t = 1:NT],
		pc_plus[sc_range(s, NC), t] .<= storage.p_charge .* kappa_plus[sc_range(s, NC), t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		pc_minus[sc_range(s, NC), t] .<= storage.p_discharge .* kappa_minus[sc_range(s, NC), t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		pc_plus[sc_range(s, NC), t] -
		((t == 1) ? zeros(NC) : pc_plus[sc_range(s, NC), t - 1]) .<= storage.gamma_charge)
	@constraint(model, [s = 1:NS, t = 1:NT],
		((t == 1) ? zeros(NC) : pc_plus[sc_range(s, NC), t - 1]) -
		pc_plus[sc_range(s, NC), t] .<= storage.gamma_discharge)
	@constraint(model, [s = 1:NS, t = 1:NT, c = 1:NC],
		kappa_plus[sc_offset(s, NC) + c, t] + kappa_minus[sc_offset(s, NC) + c, t] <= 1)
	@constraint(model, [s = 1:NS, t = 1:NT],
		qc[sc_range(s, NC), t] .<= storage.Q_max)
	@constraint(model, [s = 1:NS, t = 1:NT],
		qc[sc_range(s, NC), t] .>= storage.Q_min)
	@constraint(model, [s = 1:NS, t = 1:NT],
		qc[sc_range(s, NC), t] .==
		((t == 1) ? storage.P_init : qc[sc_range(s, NC), t - 1]) +
		storage.eta_charge .* pc_plus[sc_range(s, NC), t] -
		(ones(NC) ./ storage.eta_discharge) .* pc_minus[sc_range(s, NC), t])
	@constraint(model, [s = 1:NS],
		0.95 * storage.P_init .<= qc[sc_range(s, NC), NT] .<= 1.1 * storage.P_init)
	@constraint(model, [s = 1:NS, c = 1:NC, t = 1:NT],
		alpha[sc_offset(s, NC) + c, t] >=
		kappa_plus[sc_offset(s, NC) + c, t] -
		((t == 1) ? 0 : kappa_plus[sc_offset(s, NC) + c, t - 1]))
	@constraint(model, [s = 1:NS, c = 1:NC, t = 1:NT],
		beta[sc_offset(s, NC) + c, t] >=
		((t == 1) ? 0 : kappa_plus[sc_offset(s, NC) + c, t - 1]) -
		kappa_plus[sc_offset(s, NC) + c, t])
	@constraint(model, [s = 1:NS, c = 1:NC],
		sum(alpha[sc_offset(s, NC) + c, t] for t in 1:NT) <= 2)
	@constraint(model, [s = 1:NS, c = 1:NC],
		sum(beta[sc_offset(s, NC) + c, t] for t in 1:NT) <= 2)
	return nothing
end

# --- Main entry ----------------------------------------------------------------

"""
	run_scuc_model(NT, NB, NG, ND, NC, ND2, unit, load, wind, lines, storage, dc, config)

Stochastic Unit Commitment (SUC) with optional Data Center (SCUC) constraints.
Returns a Dict of dispatch / cost / (optional) DCC results.
"""
function run_scuc_model(NT, NB, NG, ND, NC, ND2,
                        unit::Unit, load::Load, wind::Wind,
                        lines::TransmissionLine, storage::Storage,
                        dc::DataCenter, config::Config)
	NL = length(lines.index)
	step("Creating dispatch model")

	# Network matrices (only if enabled)
	GSDF = nothing
	if config.is_NetWorkCon == 1
		_, _, GSDF = compute_linear_powerflow(unit, lines, load, NG, NB, ND, NL)
	end

	NS = wind.num_scenarios
	NW = length(wind.index)
	p_s = wind.prob

	model = Model(Gurobi.Optimizer)
	configure_gurobi!(model)

	# --- Binary commitment -----------------------------------------------------
	@variable(model, x[1:NG, 1:NT], Bin)   # on/off
	@variable(model, u[1:NG, 1:NT], Bin)   # startup
	@variable(model, v[1:NG, 1:NT], Bin)   # shutdown

	# --- Continuous generation / curtailment -----------------------------------
	@variable(model, pg0[1:(NG * NS), 1:NT] >= 0)
	@variable(model, pgk[1:(NG * NS), 1:NT, 1:3] >= 0)
	@variable(model, su0[1:NG, 1:NT] >= 0)
	@variable(model, sd0[1:NG, 1:NT] >= 0)
	@variable(model, sr_plus[1:(NG * NS), 1:NT] >= 0)
	@variable(model, sr_minus[1:(NG * NS), 1:NT] >= 0)
	@variable(model, Dpd[1:(ND * NS), 1:NT] >= 0)
	@variable(model, Dpw[1:(NW * NS), 1:NT] >= 0)

	# --- Storage ---------------------------------------------------------------
	@variable(model, kappa_plus[1:(NC * NS), 1:NT], Bin)
	@variable(model, kappa_minus[1:(NC * NS), 1:NT], Bin)
	@variable(model, pc_plus[1:(NC * NS), 1:NT] >= 0)
	@variable(model, pc_minus[1:(NC * NS), 1:NT] >= 0)
	@variable(model, qc[1:(NC * NS), 1:NT] >= 0)
	@variable(model, alpha[1:(NS * NC), 1:NT], Bin)
	@variable(model, beta[1:(NS * NC), 1:NT], Bin)

	# --- Data center (optional) ------------------------------------------------
	num_sos = 5
	if config.is_ConsiderDataCentra == 1
		@variable(model, dc_p[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_lambda[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_sq_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_sq_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_lambda_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_lambda_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_lambda_sq_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(model, dc_fv2_lambda_sq_minus[1:(ND2 * NS), 1:NT] >= 0)
		# Continuous SOS weights (convex combination over breakpoints)
		@variable(model, w_plus_fv2[1:(ND2 * NS), 1:NT, 1:num_sos] >= 0)
		@variable(model, w_minus_fv2[1:(ND2 * NS), 1:NT, 1:num_sos] >= 0)
		@variable(model, w_plus_fv2l[1:(ND2 * NS), 1:NT, 1:num_sos] >= 0)
		@variable(model, w_minus_fv2l[1:(ND2 * NS), 1:NT, 1:num_sos] >= 0)
	end

	# --- Objective -------------------------------------------------------------
	c0 = config.is_CoalPrice
	rho_plus  = c0 * 2
	rho_minus = c0 * 2
	# Softened from 1e10 → 1e6 for numeric conditioning (still ≫ fuel costs)
	load_penalty = config.is_LoadsCuttingCoefficient * 1e6
	wind_penalty = config.is_WindsCuttingCoefficient * 1e0
	ref_cost, each_slope = linearize_fuel_curve(unit, NG)

	step("Building objective")
	@objective(model, Min,
		100 * sum(su0[i, t] + sd0[i, t] for i in 1:NG, t in 1:NT) +
		p_s * c0 * (
			sum(pgk[i + (s - 1) * NG, t, k] * each_slope[k, i]
			    for i in 1:NG, t in 1:NT, s in 1:NS, k in 1:3) +
			sum(x[i, t] * ref_cost[i] for i in 1:NG, t in 1:NT, s in 1:NS) +
			sum(rho_plus * sr_plus[i + (s - 1) * NG, t] +
			    rho_minus * sr_minus[i + (s - 1) * NG, t]
			    for i in 1:NG, t in 1:NT, s in 1:NS)
		) +
		p_s * load_penalty * sum(Dpd[d + (s - 1) * ND, t] for d in 1:ND, t in 1:NT, s in 1:NS) +
		p_s * wind_penalty * sum(Dpw[w + (s - 1) * NW, t] for w in 1:NW, t in 1:NT, s in 1:NS)
	)

	# --- Constraints -----------------------------------------------------------
	step("Adding unit / reserve / balance constraints")
	_add_unit_commitment_logic!(model, x, u, v, unit, NG, NT)
	_add_startup_shutdown_cost!(model, su0, sd0, x, u, v, unit, NT)
	println("\t 1-3) unit logic / startup-shutdown\t done")

	@constraint(model, [s = 1:NS, t = 1:NT],
		Dpw[sc_range(s, NW), t] .<= wind.curve[s, t] * wind.p_max)
	@constraint(model, [s = 1:NS, t = 1:NT],
		Dpd[sc_range(s, ND), t] .<= load.curve[:, t])
	println("\t 4) curtailment limits\t\t\t done")

	@constraint(model, [s = 1:NS, t = 1:NT],
		pg0[sc_range(s, NG), t] + sr_plus[sc_range(s, NG), t] .<= unit.p_max .* x[:, t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		pg0[sc_range(s, NG), t] - sr_minus[sc_range(s, NG), t] .>= unit.p_min .* x[:, t])
	println("\t 5) generator power limits\t\t done")

	forcast_error = 0.05
	forcast_reserve = wind.curve * sum(wind.p_max) * forcast_error
	@constraint(model, [s = 1:NS, t = 1:NT, i = 1:NG],
		sum(sr_plus[sc_range(s, NG), t]) + sum(pc_minus[sc_range(s, NC), t]) >=
		0.5 * unit.p_max[i] * x[i, t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		sum(sr_minus[sc_range(s, NG), t]) + sum(pc_plus[sc_range(s, NC), t]) >=
		1.0 * (config.is_Alpha * forcast_reserve[s, t] +
		       config.is_Belta * sum(load.curve[:, t])))
	println("\t 6) system reserves\t\t\t done")

	if config.is_ConsiderDataCentra == 0
		@constraint(model, [s = 1:NS, t = 1:NT],
			sum(pg0[sc_range(s, NG), t]) +
			sum(wind.curve[s, t] * wind.p_max - Dpw[sc_range(s, NW), t]) -
			sum(load.curve[:, t] - Dpd[sc_range(s, ND), t]) +
			sum(pc_minus[sc_range(s, NC), t]) - sum(pc_plus[sc_range(s, NC), t]) .== 0)
	else
		@constraint(model, [s = 1:NS, t = 1:NT],
			sum(pg0[sc_range(s, NG), t]) +
			sum(wind.curve[s, t] * wind.p_max - Dpw[sc_range(s, NW), t]) -
			sum(load.curve[:, t] - Dpd[sc_range(s, ND), t]) +
			sum(pc_minus[sc_range(s, NC), t]) - sum(pc_plus[sc_range(s, NC), t]) -
			sum(dc_p[sc_range(s, ND2), t]) .== 0)
	end
	println("\t 7) power balance\t\t\t done")

	@constraint(model, [s = 1:NS, t = 1:NT],
		pg0[sc_range(s, NG), t] -
		((t == 1) ? unit.p_0 : pg0[sc_range(s, NG), t - 1]) .<=
		unit.ramp_up .* ((t == 1) ? unit.x_0 : x[:, t - 1]) +
		unit.shut_up .* ((t == 1) ? ones(NG) : u[:, t - 1]) +
		unit.p_max .* (ones(NG) - ((t == 1) ? unit.x_0 : x[:, t - 1])))
	@constraint(model, [s = 1:NS, t = 1:NT],
		((t == 1) ? unit.p_0 : pg0[sc_range(s, NG), t - 1]) -
		pg0[sc_range(s, NG), t] .<=
		unit.ramp_down .* x[:, t] + unit.shut_down .* v[:, t] + unit.p_max .* x[:, t])
	println("\t 8) ramp up/down\t\t\t done")

	seg = (unit.p_max - unit.p_min) / 3
	@constraint(model, [s = 1:NS, t = 1:NT, i = 1:NG],
		pg0[i + (s - 1) * NG, t] == unit.p_min[i] * x[i, t] + sum(pgk[i + (s - 1) * NG, t, :]))
	@constraint(model, [s = 1:NS, t = 1:NT, i = 1:NG, k = 1:3],
		pgk[i + (s - 1) * NG, t, k] <= seg[i] * x[i, t])
	println("\t 9) piecewise linear segments\t\t done")

	if config.is_NetWorkCon == 1 && GSDF !== nothing
		for l in 1:NL
			sub_G   = GSDF[l, unit.locatebus]
			sub_W   = GSDF[l, wind.index]
			sub_L   = GSDF[l, load.locatebus]
			sub_ESS = GSDF[l, storage.locatebus]
			sub_DC  = GSDF[l, dc.locatebus]
			@constraint(model, [s = 1:NS, t = 1:NT],
				sum(sub_G[i] * pg0[i + (s - 1) * NG, t] for i in 1:NG) +
				sum(sub_W[w] * (wind.curve[s, t] * wind.p_max[w] - Dpw[(s - 1) * NW + w, t]) for w in 1:NW) -
				sum(sub_L[d] * (load.curve[d, t] - Dpd[(s - 1) * ND + d, t]) for d in 1:ND) +
				sum(sub_ESS[c] * (pc_minus[(s - 1) * NC + c, t] - pc_plus[(s - 1) * NC + c, t]) for c in 1:NC) -
				(config.is_ConsiderDataCentra == 0 ? 0.0 :
				 sum(sub_DC[i] * dc_p[(s - 1) * ND2 + i, t] for i in 1:ND2)) <= lines.p_max[l])
			@constraint(model, [s = 1:NS, t = 1:NT],
				sum(sub_G[i] * pg0[i + (s - 1) * NG, t] for i in 1:NG) +
				sum(sub_W[w] * (wind.curve[s, t] * wind.p_max[w] - Dpw[(s - 1) * NW + w, t]) for w in 1:NW) -
				sum(sub_L[d] * (load.curve[d, t] - Dpd[(s - 1) * ND + d, t]) for d in 1:ND) +
				sum(sub_ESS[c] * (pc_minus[(s - 1) * NC + c, t] - pc_plus[(s - 1) * NC + c, t]) for c in 1:NC) -
				(config.is_ConsiderDataCentra == 0 ? 0.0 :
				 sum(sub_DC[i] * dc_p[(s - 1) * ND2 + i, t] for i in 1:ND2)) >= lines.p_min[l])
		end
		println("\t 10) transmission line limits\t\t done")
	end

	_add_storage_constraints!(model, kappa_plus, kappa_minus, pc_plus, pc_minus,
	                          qc, alpha, beta, storage, NS, NC, NT)
	println("\t 11) storage system\t\t\t done")

	if config.is_ConsiderDataCentra == 1
		dc_vars = (;
			dc_p, dc_fv2, dc_fv2_lambda,
			dc_fv2_plus, dc_fv2_minus, dc_fv2_sq_plus, dc_fv2_sq_minus,
			dc_fv2_lambda_plus, dc_fv2_lambda_minus,
			dc_fv2_lambda_sq_plus, dc_fv2_lambda_sq_minus,
			w_plus_fv2, w_minus_fv2, w_plus_fv2l, w_minus_fv2l,
		)
		add_dcc_constraints!(model, dc, config, NS, NT, ND2, num_sos, dc_vars)
	end

	# --- Solve -----------------------------------------------------------------
	step("Solving MILP")
	JuMP.optimize!(model)

	term = JuMP.termination_status(model)
	prim = JuMP.primal_status(model)
	if term == MOI.OPTIMAL && prim == MOI.FEASIBLE_POINT
		println("Solve OK: termination=$term, primal=$prim")
	elseif prim == MOI.FEASIBLE_POINT
		@warn "Solver finished with non-optimal status=$term; using feasible primal"
	else
		error("Solve failed: termination=$term, primal=$prim")
	end

	# --- Extract ---------------------------------------------------------------
	step("Extracting results")
	x_val  = JuMP.value.(x)
	p0_val = JuMP.value.(pg0)
	pk_val = JuMP.value.(pgk)
	su_val = JuMP.value.(su0)
	sd_val = JuMP.value.(sd0)
	rp_val = JuMP.value.(sr_plus)
	rm_val = JuMP.value.(sr_minus)
	pd_val = JuMP.value.(Dpd)
	pw_val = JuMP.value.(Dpw)
	ks_plus  = JuMP.value.(kappa_plus)
	ks_minus = JuMP.value.(kappa_minus)
	pcp_val  = JuMP.value.(pc_plus)
	pcm_val  = JuMP.value.(pc_minus)
	qc_val   = JuMP.value.(qc)

	su_cost = sum(su_val)
	sd_cost = sum(sd_val)
	prod_cost = p_s * c0 * (
		sum(pk_val[i + (s - 1) * NG, t, k] * each_slope[k, i]
		    for i in 1:NG, t in 1:NT, s in 1:NS, k in 1:3) +
		sum(x_val[i, t] * ref_cost[i] for i in 1:NG, t in 1:NT, s in 1:NS)
	)
	cr_plus  = p_s * c0 * sum(rho_plus * rp_val[i + (s - 1) * NG, t] for i in 1:NG, t in 1:NT, s in 1:NS)
	cr_minus = p_s * c0 * sum(rho_minus * rm_val[i + (s - 1) * NG, t] for i in 1:NG, t in 1:NT, s in 1:NS)
	seq_sr_plus  = p_s * c0 * [sum(rho_plus * rp_val[i, t] for i in 1:NG) for t in 1:NT]
	seq_sr_minus = p_s * c0 * [sum(rho_minus * rm_val[i, t] for i in 1:NG) for t in 1:NT]
	cost_pd = p_s * sum(pd_val[d + (s - 1) * ND, t] for d in 1:ND, t in 1:NT, s in 1:NS)
	cost_pw = p_s * sum(pw_val[w + (s - 1) * NW, t] for w in 1:NW, t in 1:NT, s in 1:NS)

	result = Dict(
		"x" => x_val, "p0" => p0_val, "pd" => pd_val, "pw" => pw_val,
		"seq_sr_plus" => seq_sr_plus, "seq_sr_minus" => seq_sr_minus,
		"pss_charge_p_plus" => pcp_val, "pss_charge_p_minus" => pcm_val,
		"su_cost" => su_cost, "sd_cost" => sd_cost, "prod_cost" => prod_cost,
		"cr_plus" => cr_plus, "cr_minus" => cr_minus,
	)

	_save_optimization_results(output_dir(), model, x_val, p0_val, pd_val, pw_val,
	                           rp_val, rm_val, ks_plus, ks_minus, pcp_val, pcm_val, qc_val,
	                           su_cost, sd_cost, prod_cost, cr_plus, cr_minus,
	                           cost_pd, cost_pw, NG, ND, NW, NC, NT, p_s, c0)

	if config.is_ConsiderDataCentra == 1
		merge!(result, Dict(
			"dc_p" => JuMP.value.(dc_p),
			"dc_fv2" => JuMP.value.(dc_fv2),
			"dc_fv2_lambda" => JuMP.value.(dc_fv2_lambda),
			"dc_fv2_plus" => JuMP.value.(dc_fv2_plus),
			"dc_fv2_minus" => JuMP.value.(dc_fv2_minus),
			"dc_fv2_2_plus" => JuMP.value.(dc_fv2_sq_plus),
			"dc_fv2_2_minus" => JuMP.value.(dc_fv2_sq_minus),
			"dc_fv2_lambda_plus" => JuMP.value.(dc_fv2_lambda_plus),
			"dc_fv2_lambda_minus" => JuMP.value.(dc_fv2_lambda_minus),
			"dc_fv2_lambda_2_plus" => JuMP.value.(dc_fv2_lambda_sq_plus),
			"dc_fv2_lambda_2_minus" => JuMP.value.(dc_fv2_lambda_sq_minus),
			"weight_fv2_minus" => JuMP.value.(w_minus_fv2),
			"weight_fv2_plus" => JuMP.value.(w_plus_fv2),
			"weight_fv2l_minus" => JuMP.value.(w_minus_fv2l),
			"weight_fv2l_plus" => JuMP.value.(w_plus_fv2l),
		))
		save_data_center_csv(result, joinpath(output_dir(), "data_centra"), ND2, NT, num_sos)
	end

	return result
end

"""
	_save_optimization_results(...) — write plain-text result dump
"""
function _save_optimization_results(out_dir, model, x_val, p0_val, pd_val, pw_val,
                                    rp_val, rm_val, kp_val, km_val, pcp_val, pcm_val, qc_val,
                                    su_cost, sd_cost, prod_cost, cr_plus, cr_minus,
                                    cost_pd, cost_pw, NG, ND, NW, NC, NT, p_s, c0)
	try
		mkpath(out_dir)
		str_row = zeros(1, 7)
		str_row[1, 1] = su_cost * 10
		str_row[1, 2] = sd_cost * 10
		str_row[1, 3] = prod_cost
		str_row[1, 4] = cr_plus
		str_row[1, 5] = cr_minus
		str_row[1, 6] = cost_pd
		str_row[1, 7] = cost_pw

		output_file = joinpath(out_dir, "calculation_result.txt")
		open(output_file, "w") do io
			writedlm(io, [" "])
			writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr_plus" "cr_minus" "cost_pd" "cost_pw"], '\t')
			writedlm(io, str_row, '\t')
			writedlm(io, [" "])
			writedlm(io, ["Unit startup/shutdown states"]); writedlm(io, x_val, '\t')
			writedlm(io, [" "])
			writedlm(io, ["Unit dispatch power (scenario 1)"]); writedlm(io, p0_val[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["Wind curtailment"]); writedlm(io, pw_val[1:NW, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["Load curtailment"]); writedlm(io, pd_val[1:ND, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["ESS charge state"]); writedlm(io, kp_val[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["ESS discharge state"]); writedlm(io, km_val[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["ESS charge power"]); writedlm(io, pcp_val[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["ESS discharge power"]); writedlm(io, pcm_val[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["ESS stored energy"]); writedlm(io, qc_val[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["Reserve up (sr_plus)"]); writedlm(io, rp_val[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["Reserve down (sr_minus)"]); writedlm(io, rm_val[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["alpha (charge transition)"]); writedlm(io, JuMP.value.(model[:alpha])[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["beta (discharge transition)"]); writedlm(io, JuMP.value.(model[:beta])[1:NC, 1:NT], '\t')
		end
		println("Results saved to: $output_file")
	catch e
		@warn "Failed to save results: $e"
	end
end
