using JuMP, Gurobi, Test, DelimitedFiles
# Dependencies for optimization and file operations

include("linearization.jl")
include("powerflowcalculation.jl")

"""
	SUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)

Stochastic Unit Commitment (SUC) model for power system optimization.

# Arguments
- `NT::Int64`: Number of time periods
- `NB::Int64`: Number of buses
- `NG::Int64`: Number of generators
- `ND::Int64`: Number of demands/loads
- `NC::Int64`: Number of energy storage units
- `units::unit`: Generator unit data
- `loads::load`: Load data
- `winds::wind`: Wind generation data
- `lines::transmissionline`: Transmission line data
- `config_param::config`: Configuration parameters

# Returns
- Tuple containing optimization results:
  - `x₀`: Unit commitment states
  - `p₀`: Power dispatch
  - `pᵨ`: Load curtailment
  - `pᵩ`: Wind curtailment
  - `seq_sr⁺`: Up reserve sequence
  - `seq_sr⁻`: Down reserve sequence
  - `pss_charge_p⁺`: Storage charging power
  - `pss_charge_p⁻`: Storage discharging power
  - `su_cost`: Startup cost
  - `sd_cost`: Shutdown cost
  - `prod_cost`: Production cost
  - `cr⁺`: Up reserve cost
  - `cr⁻`: Down reserve cost
"""
function SUC_scucmodel(NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64,
					   units::unit, loads::load, winds::wind, lines::transmissionline,
					   DataCentras::data_centra, config_param::config)
	println("Step-3: Creating dispatching model")

	if config_param.is_NetWorkCon == 1
		Adjacmatrix_BtoG, Adjacmatrix_B2D,
		Gsdf = linearpowerflow(units, lines, loads, NG, NB, ND, NL)
		Adjacmatrix_BtoW = zeros(NB, length(winds.index))
		for i in 1:length(winds.index)
			Adjacmatrix_BtoW[winds.index[i, 1], i] = 1
		end
	end

	NS = winds.scenarios_nums
	NW = length(winds.index)

	# creat scucsimulation_model
	# scuc = Model(CPLEX.Optimizer)
	scuc = Model(Gurobi.Optimizer)

	# NS = 1 # for test

	# binary variables
	@variable(scuc, x[1:NG, 1:NT], Bin)
	@variable(scuc, u[1:NG, 1:NT], Bin)
	@variable(scuc, v[1:NG, 1:NT], Bin)

	# continuous variables
	@variable(scuc, pg₀[1:(NG * NS), 1:NT]>=0)
	@variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3]>=0)
	@variable(scuc, su₀[1:NG, 1:NT]>=0)
	@variable(scuc, sd₀[1:NG, 1:NT]>=0)
	@variable(scuc, sr⁺[1:(NG * NS), 1:NT]>=0)
	@variable(scuc, sr⁻[1:(NG * NS), 1:NT]>=0)
	@variable(scuc, Δpd[1:(ND * NS), 1:NT]>=0)
	@variable(scuc, Δpw[1:(NW * NS), 1:NT]>=0)

	# pss variables
	@variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
	@variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
	@variable(scuc, pc⁺[1:(NC * NS), 1:NT]>=0)# charge power
	@variable(scuc, pc⁻[1:(NC * NS), 1:NT]>=0)# discharge power
	@variable(scuc, qc[1:(NC * NS), 1:NT]>=0) # cumsum power
	# @variable(scuc, pss_sumchargeenergy[1:NC * NS, 1] >= 0)

	# defination charging and discharging of BESS
	@variable(scuc, α[1:(NS * NC), 1:NT], Bin)
	@variable(scuc, β[1:(NS * NC), 1:NT], Bin)

	# Linearize the fuel cost curve for the generators
	refcost, eachslope = linearizationfuelcurve(units, NG)

	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal
	pₛ = scenarios_prob  # Probability of scenarios

	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	if config_param.is_ConsiderDataCentra == 1
		num_sos = 5
		@variable(scuc, dc_p[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²λ[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²_2_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²_2_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²λ_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²λ_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²λ_2_plus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_fv²λ_2_minus[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, weight_fv²_minus[1:(ND2 * NS), 1:NT, 1:num_sos], Bin)
		@variable(scuc, weight_fv²_plus[1:(ND2 * NS), 1:NT, 1:num_sos], Bin)
		@variable(scuc, weight_fv²λ_minus[1:(ND2 * NS), 1:NT, 1:num_sos], Bin)
		@variable(scuc, weight_fv²λ_plus[1:(ND2 * NS), 1:NT, 1:num_sos], Bin)
	end

	ρ⁺ = c₀ * 2
	ρ⁻ = c₀ * 2

	println("start...")
	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

	# model-1: MIQP with quartic fuel equation
	# @objective(scuc, Min, sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)+
	#     pₛ*c₀/100*(sum(sum(sum(sum(units.coffi_a[i,1] * (pg₀[i + (s - 1) * NG,t]^2) + units.coffi_b[i,1] * pg₀[i + (s - 1) * NG,t] + units.coffi_c[i,1] for t in 1:NT)) for s in 1:NS) for i in 1:NG))+
	#     pₛ*plentycoffi_1*sum(sum(sum(Δpd[1+(s-1)*ND : s*ND, t]) for t in 1:NT) for s in 1:NS)+
	#     pₛ*plentycoffi_2*sum(sum(sum(Δpw[1+(s-1)*NW : s*NW, t]) for t in 1:NT) for s in 1:NS))

	# model-2:MILP with piece linearization equation of nonliear equation
	@objective(scuc,
			   Min,
			   100*sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)+
			   pₛ *
			   c₀ *
			   (sum(sum(sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
						for s in 1:NS) for i in 1:NG) +
				sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS) +
				sum(sum(sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
							for i in 1:NG) for t in 1:NT) for s in 1:NS))+
			   pₛ *
			   load_curtailment_penalty *
			   sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)+
			   pₛ *
			   wind_curtailment_penalty *
			   sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS))

	#
	# for test
	# @objective(scuc, Min, 0)
	println("objective_function")
	println("\t MILP_type objective_function \t\t\t\t\t\t done")

	println("subject to.")

	# Initialize minimum startup and shutdown duration limits
	onoffinit = zeros(NG, 1)  # Initial on/off status of units
	Lupmin = zeros(NG, 1)     # Minimum startup time
	Ldownmin = zeros(NG, 1)   # Minimum shutdown time

	# Calculate minimum up/down time based on initial conditions
	for i in 1:NG
		# Uncomment if initial status is provided
		# onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)

		# Calculate minimum up/down time limits
		Lupmin[i] = min(NT, units.min_shutup_time[i] * onoffinit[i])
		Ldownmin[i] = min(NT, (units.min_shutdown_time[i, 1]) * (1 - onoffinit[i]))
	end

	# @constraint(
	#     scuc,
	#     [i = 1:NG, t = 1:Int64((Lupmin[i] + Ldownmin[i]))],
	#     x[i, t] == onoffinit[i]
	# )

	for i in 1:NG
		for t in Int64(max(1, Lupmin[i])):NT
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			@constraint(scuc, sum(u[i, r] for r in LB:t)<=x[i, t])
		end
		for t in Int64(max(1, Ldownmin[i])):NT
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			@constraint(scuc, sum(v[i, r] for r in LB:t)<=(1 - x[i, t]))
		end
	end
	println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

	# binary variable logic
	@constraint(scuc,
				[i = 1:NG, t = 1:NT],
				u[i, t] - v[i, t]==x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))
	@constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t]<=1)
	println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

	# shutup/shutdown cost
	shutupcost = units.coffi_cold_shutup_1
	shutdowncost = units.coffi_cold_shutdown_1
	# @constraint(scuc, [t = 1], su₀[:, t] .>= shutupcost .* (x[:, t] - onoffinit[:, 1]))
	# @constraint(scuc, [t = 1], sd₀[:, t] .>= shutdowncost .* (onoffinit[:, 1] - x[:, t]))

	@constraint(scuc, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
	@constraint(scuc, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))

	@constraint(scuc, [t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
	@constraint(scuc, [t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])
	println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")

	# loadcurtailments and spoliedwinds limits
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				Δpw[(1 + (s - 1) * NW):(s * NW), t] .<=
				winds.scenarios_curve[s, t] * winds.p_max[:, 1])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				Δpd[(1 + (s - 1) * ND):(s * ND), t] .<= loads.load_curve[:, t])
	# @constraint(scuc, [s=1:NS, t = 1:NT], Δpw[1+(s-1)*NW:s*NW, t] .== zeros(NW,1))
	# @constraint(scuc, [s=1:NS, t = 1:NT], Δpd[1+(s-1)*ND:s*ND, t] .== zeros(ND,1))
	println("\t constraints: 4) loadcurtailments and spoliedwinds\t\t\t done")

	# generatos power limits
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pg₀[(1 + (s - 1) * NG):(s * NG), t] + sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<=
				units.p_max[:, 1] .* x[:, t])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pg₀[(1 + (s - 1) * NG):(s * NG), t] - sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>=
				units.p_min[:, 1] .* x[:, t])
	println("\t constraints: 5) generatos power limits\t\t\t\t\t done")

	# system reserves
	# forcast_error = 0.05
	# forcast_reserve = winds.scenarios_curve * sum(winds.p_max[:,1]) * forcast_error
	# @constraint(scuc,[s = 1:NS, t = 1:NT, i = 1:NG], sum(sr⁺[1 + (s - 1) * NG:s * NG, t]) >= 0.05 * units.p_max[i,1] * x[i,t])
	# @constraint(scuc,[s = 1:NS, t = 1:NT], sum(sr⁻[1 + (s - 1) * NG:s * NG, t]) >= config_param.is_Alpha * forcast_reserve[s,t] + config_param.is_Belta * sum(loads.load_curve[:,t]))

	forcast_error = 0.05
	forcast_reserve = winds.scenarios_curve * sum(winds.p_max[:, 1]) * forcast_error
	@constraint(scuc,
				[s = 1:NS, t = 1:NT, i = 1:NG],
				sum(sr⁺[(1 + (s - 1) * NG):(s * NG), t]) +
				sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t])>=0.5 * units.p_max[i, 1] * x[i, t])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				sum(sr⁻[(1 + (s - 1) * NG):(s * NG), t]) +
				sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t])>=
				1.0 * (config_param.is_Alpha * forcast_reserve[s, t] +
					   config_param.is_Belta * sum(loads.load_curve[:, t])))
	println("\t constraints: 6) system reserves limits\t\t\t\t\t done")

	# power balance constraints

	# @constraint(scuc,[s = 1:NS,t = 1:NT],sum(pg₀[1 + (s - 1) * NG:s * NG,t]) + sum(winds.scenarios_curve[s,t] .* winds.p_max[:,1] - Δpw[1 + (s - 1) * NW:s * NW,t]) - sum(loads.load_curve[:,t] - Δpd[1 + (s - 1) * ND:s * ND,t]) .== 0)

	if config_param.is_ConsiderDataCentra == 0
		@constraint(scuc,
					[s = 1:NS, t = 1:NT],
					sum(pg₀[(1 + (s - 1) * NG):(s * NG), t]) +
					sum(winds.scenarios_curve[s, t] * winds.p_max[:, 1] -
						Δpw[(1 + (s - 1) * NW):(s * NW), t]) -
					sum(loads.load_curve[:, t] - Δpd[(1 + (s - 1) * ND):(s * ND), t]) +
					sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) -
					sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) .== 0)
	else
		@constraint(scuc,
					[s = 1:NS, t = 1:NT],
					sum(pg₀[(1 + (s - 1) * NG):(s * NG), t]) +
					sum(winds.scenarios_curve[s, t] * winds.p_max[:, 1] -
						Δpw[(1 + (s - 1) * NW):(s * NW), t]) -
					sum(loads.load_curve[:, t] - Δpd[(1 + (s - 1) * ND):(s * ND), t]) +
					sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) -
					sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) -
					sum(dc_p[(ND2 * (s - 1) + 1):(s * ND2), t])  #TODO -add datacentra
					.==
					0)
	end
	println("\t constraints: 7) power balance constraints\t\t\t\t done")

	# ramp-up and ramp-down constraints
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pg₀[(1 + (s - 1) * NG):(s * NG), t] -
				((t == 1) ? units.p_0[:, 1] :
				 pg₀[(1 + (s - 1) * NG):(s * NG),
					 t - 1]) .<=
				units.ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
				units.shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
				units.p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1])))

	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) -
				pg₀[(1 + (s - 1) * NG):(s * NG), t] .<=
				units.ramp_down[:, 1] .* x[:, t] +
				units.shut_down[:, 1] .* v[:, t] +
				units.p_max[:, 1] .* (x[:, t]))
	println("\t constraints: 8) ramp-up/ramp-down constraints\t\t\t\t done")

	# PWL constraints
	eachseqment = (units.p_max - units.p_min) / 3
	@constraint(scuc,
				[s = 1:NS, t = 1:NT, i = 1:NG],
				pg₀[i + (s - 1) * NG, t] .==
				units.p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, :]))
	@constraint(scuc,
				[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:3],
				pgₖ[i + (s - 1) * NG, t, k]<=eachseqment[i, 1] * x[i, t])
	println("\t constraints: 9) piece linearization constraints\t\t\t done")

	# transmissionline power limits for basline states
	if config_param.is_NetWorkCon == 1
		for l in 1:NL
			subGsdf_units = Gsdf[l, units.locatebus]
			subGsdf_winds = Gsdf[l, winds.index]
			subGsdf_loads = Gsdf[l, loads.locatebus]
			subGsdf_psses = Gsdf[1, stroges.locatebus]
			subGsdf_dcces = Gsdf[1, data_centra.locatebus]

			@constraint(scuc,
						[s = 1:NS, t = 1:NT],
						sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
						sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] -
												Δpw[(s - 1) * NW + w, t]) for w in 1:NW) -
						sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t])
							for d in 1:ND) + sum(subGsdf_psses[c] *
							(pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) for c in 1:NC) -
						(config_param.is_ConsiderDataCentra == 0 ? 0 :
						 (sum(subGsdf_dcces[i] * (dc_p[(s - 1) * ND2 + i, t]) for i in 1:ND2)))
						<=
						lines.p_max[l, 1])
			@constraint(scuc,
						[s = 1:NS, t = 1:NT],
						sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
						sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] -
												Δpw[(s - 1) * NW + w, t]) for w in 1:NW) -
						sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t])
							for d in 1:ND) + sum(subGsdf_psses[c] *
							(pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) for c in 1:NC) -
						(config_param.is_ConsiderDataCentra == 0 ? 0 :
						 (sum(subGsdf_dcces[i] * (dc_p[(s - 1) * ND2 + i, t]) for i in 1:ND2)))>=lines.p_min[l,
																											 1])
		end
		println("\t constraints: 10) transmissionline limits for basline\t\t\t done")
	end

	# stroges system constraints
	# REVIEW - discharge/charge limits
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pc⁺[((s - 1) * NC + 1):(s * NC), t] .<=
				stroges.p⁺[:, 1] .* κ⁺[((s - 1) * NC + 1):(s * NC), t]) # charge power
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pc⁻[((s - 1) * NC + 1):(s * NC), t] .<=
				stroges.p⁻[:, 1] .* κ⁻[((s - 1) * NC + 1):(s * NC), t]) # discharge power

	# coupling limits for adjacent discharge/charge constraints
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				pc⁺[((s - 1) * NC + 1):(s * NC), t] -
				((t == 1) ? stroges.P₀[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) .<=
				stroges.γ⁺[:, 1])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				((t == 1) ? stroges.P₀[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) -
				pc⁺[((s - 1) * NC + 1):(s * NC), t] .<= stroges.γ⁻[:, 1])

	# Mutual exclusion constraints in charge and discharge states
	@constraint(scuc,
				[s = 1:NS, t = 1:NT, c = 1:NC],
				κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t]<=1)

	# Energy storage constraint
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				qc[((s - 1) * NC + 1):(s * NC), t] .<= stroges.Q_max[:, 1])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				qc[((s - 1) * NC + 1):(s * NC), t] .>= stroges.Q_min[:, 1])
	@constraint(scuc,
				[s = 1:NS, t = 1:NT],
				qc[((s - 1) * NC + 1):(s * NC),
				   t] .==
				((t == 1) ? stroges.P₀[:, 1] : qc[((s - 1) * NC + 1):(s * NC), t - 1]) +
				stroges.η⁺[:, 1] .* pc⁺[((s - 1) * NC + 1):(s * NC), t] -
				(ones(NC, 1) ./ stroges.η⁻[:, 1]) .* pc⁻[((s - 1) * NC + 1):(s * NC), t])

	# inital-time and end-time equaltimes
	@constraint(scuc,
				[s = 1:NS],
				0.95*stroges.P₀[:, 1] .<=
				qc[((s - 1) * NC + 1):(s * NC), NT] .<=
				1.1*stroges.P₀[:, 1])
	@constraint(scuc,
				[s = 1:NS, c = 1:NC, t = 1:NT],
				α[(s - 1) * NC + c,
				  t]>=κ⁺[(s - 1) * NC + 1, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + 1, t - 1]))
	@constraint(scuc,
				[s = 1:NS, c = 1:NC, t = 1:NT],
				β[(s - 1) * NC + c,
				  t]>=((t == 1) ? 0 : κ⁺[(s - 1) * NC + 1, t - 1]) - κ⁺[(s - 1) * NC + 1, t])

	@constraint(scuc,
				[s = 1:NS, c = 1:NC],
				sum(α[(s - 1) * NC + c, t] for t in 1:NT)<=2)

	@constraint(scuc,
				[s = 1:NS, c = 1:NC],
				sum(β[(s - 1) * NC + c, t] for t in 1:NT)<=2)

	# # magic constraint
	# least_operatime = 0.0
	# @constraint(scuc, [s = 1:NS], pss_sumchargeenergy[(s - 1) * NC + 1:s * NC,1] .== sum(pc⁺[(s - 1) * NC + 1:s * NC,t] for t in 1:NT))
	# @constraint(scuc, [s = 1:NS], pss_sumchargeenergy[(s - 1) * NC + 1:s * NC,1] .>= least_operatime * NT * storges.p_max[:,1])
	println("\t constraints: 11) stroges system constraints limits\t\t\t done")

	# NOTE - data centra constraints
	if config_param.is_ConsiderDataCentra == 1
		enable_active_response_flag = 0
		if enable_active_response_flag == 0
			workload_multijob = DataCentras.computational_power_tasks' * 10
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .==
						DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .*
											 workload_multijob[:, t])
		else
			dcc_boundries_conditions = get_dcc_boundaries_conditions(num_sos, ND2)

			dcc_f_lb          = dcc_boundries_conditions["dcc_f_lb"]
			dcc_f_ub          = dcc_boundries_conditions["dcc_f_ub"]
			dcc_v_lb          = dcc_boundries_conditions["dcc_v_lb"]
			dcc_v_ub          = dcc_boundries_conditions["dcc_v_ub"]
			dcc_v²_lb        = dcc_boundries_conditions["dcc_v²_lb"]
			dcc_v²_ub        = dcc_boundries_conditions["dcc_v²_ub"]
			dcc_fv²_plus_ub  = dcc_boundries_conditions["dcc_fv²_plus_ub"]
			dcc_fv²_minus_ub = dcc_boundries_conditions["dcc_fv²_minus_ub"]
			dcc_fv²_plus_lb  = dcc_boundries_conditions["dcc_fv²_plus_lb"]
			dcc_fv²_minus_lb = dcc_boundries_conditions["dcc_fv²_minus_lb"]

			dc_λ_ub            = dcc_boundries_conditions["dc_λ_ub"]
			dc_λ_lb            = dcc_boundries_conditions["dc_λ_lb"]
			dcc_fv²λ_plus_ub  = dcc_boundries_conditions["dcc_fv²λ_plus_ub"]
			dcc_fv²λ_minus_ub = dcc_boundries_conditions["dcc_fv²λ_minus_ub"]
			dcc_fv²λ_plus_lb  = dcc_boundries_conditions["dcc_fv²λ_plus_lb"]
			dcc_fv²λ_minus_lb = dcc_boundries_conditions["dcc_fv²λ_minus_lb"]

			dcc_fv²_plus_discrete      = dcc_boundries_conditions["dcc_fv²_plus_discrete"]
			dcc_fv²_minus_discrete     = dcc_boundries_conditions["dcc_fv²_minus_discrete"]
			dcc_fv²λ_plus_discrete    = dcc_boundries_conditions["dcc_fv²λ_plus_discrete"]
			dcc_fv²λ_minus_discrete   = dcc_boundries_conditions["dcc_fv²λ_minus_discrete"]
			dcc_fv²_2_plus_discrete    = dcc_boundries_conditions["dcc_fv²_2_plus_discrete"]
			dcc_fv²_2_minus_discrete   = dcc_boundries_conditions["dcc_fv²_2_minus_discrete"]
			dcc_fv²λ_2_plus_discrete  = dcc_boundries_conditions["dcc_fv²λ_2_plus_discrete"]
			dcc_fv²λ_2_minus_discrete = dcc_boundries_conditions["dcc_fv²λ_2_minus_discrete"]
			num_sos                     = dcc_boundries_conditions["num_sos"]

			# TODO data centra primal workload consumputions have not been considered...
			workload_multijob = DataCentras.computational_power_tasks' * 10

			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .<= DataCentras.p_max .* 10)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .>= DataCentras.p_min .* 0)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .==
						DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .*
											 workload_multijob[:, t] .* dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t])

			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²_plus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv²_plus_ub)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²_plus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv²_plus_lb)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²_minus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv²_minus_ub)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²_minus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv²_minus_lb)

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²_plus[(s - 1) * ND2 + i, t] ==
						sum(dcc_fv²_plus_discrete[z] * weight_fv²_plus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²_2_plus[(s - 1) * ND2 + i, t] ==
						sum(dcc_fv²_2_plus_discrete[z] * weight_fv²_plus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²_minus[(s - 1) * ND2 + i, t] ==
						sum(dcc_fv²_minus_discrete[z] * weight_fv²_minus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²_2_minus[(s - 1) * ND2 + i, t] ==
						sum(dcc_fv²_2_minus_discrete[z] * weight_fv²_minus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos))

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²[(s - 1) * ND2 + i, t] == dc_fv²_2_plus[(s - 1) * ND2 + i, t] - dc_fv²_2_minus[(s - 1) * ND2 + i, t])

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						sum(weight_fv²_plus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos) == 1)
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						sum(weight_fv²_minus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos) == 1)

			# ----

			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ_plus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv²λ_plus_ub)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ_plus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv²λ_plus_lb)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ_minus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv²λ_minus_ub)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ_minus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv²λ_minus_lb)

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²λ_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv²λ_plus_discrete[z] *
																  weight_fv²λ_plus[((s - 1) * ND2 + i), t, z] for z in 1:(num_sos)))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²λ_2_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv²λ_2_plus_discrete[z] *
																	weight_fv²λ_plus[((s - 1) * ND2 + i), t, z] for z in 1:(num_sos)))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²λ_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv²λ_minus_discrete[z] *
																   weight_fv²λ_minus[((s - 1) * ND2 + i), t, z] for z in 1:(num_sos)))
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²λ_2_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv²λ_2_minus_discrete[z] *
																	 weight_fv²λ_minus[((s - 1) * ND2 + i), t, z] for z in 1:(num_sos)))

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
						dc_fv²λ[(s - 1) * ND2 + i, t] == dc_fv²λ_2_plus[(s - 1) * ND2 + i, t] - dc_fv²λ_2_minus[(s - 1) * ND2 + i, t])

			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²λ_plus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos) == 1)
			@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²λ_minus[((s - 1) * ND2 + i), t, z] for z in 1:num_sos) == 1)

			# NEWADDED
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1) * 1.5)
			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1) * 1.5)

			#NOTE - verison 1: using conventional constinuous constraints

			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .<= DataCentras.p_max)
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .>= DataCentras.p_min)
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .== DataCentras.idale .+ DataCentras.sv_constant .* dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] ./ DataCentras.μ)

			# # workload balancing constraints amoung multiple dccs.
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t])
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_λ[((s - 1) * ND2 + 1):(s * ND2), t])
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] .>= dc_λ[((s - 1) * ND2 + 1):(s * ND2), t] .+ dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] - ones(ND2, 1))

			# # nvfs techinques for dccs.
			# # TODO - 当两个连续变量不再满足0-1这个限制，所提松弛重构方法没有效果
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_v²[((s - 1) * ND2 + 1):(s * ND2), t])
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_f[((s - 1) * ND2 + 1):(s * ND2), t])
			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .>= dc_v²[((s - 1) * ND2 + 1):(s * ND2), t] .+ dc_f[((s - 1) * ND2 + 1):(s * ND2), t] - ones(ND2, 1))

			# @constraint(scuc, [s = 1:NS, t = 1:NT], dc_λ[((s - 1) * ND2 + 1):(s * ND2), t] .<= 1.0 * ones(ND2, 1))
			# @constraint(scuc, [s = 1:NS, t = 1:NT], 0.6 * ones(ND2, 1) .<= dc_f[((s - 1) * ND2 + 1):(s * ND2), t] .<= 1.5 * ones(ND2, 1))
			# @constraint(scuc, [s = 1:NS, t = 1:NT], 0.8 * ones(ND2, 1) .<= dc_v²[((s - 1) * ND2 + 1):(s * ND2), t] .<= 1.25 * ones(ND2, 1))

			iter_num = 6
			coeff = 0.05

			@constraint(scuc, [s = 1:NS, t = 1:NT],
						dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t] .<=
						dc_fv²[((s - 1) * ND2 + 1):(s * ND2), t] * (1 + 0.5))

			iter_block = Int64(round(NT / iter_num))
			@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
						sum(dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)]) .<=
						sum(dc_fv²[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)]) * (1 + coeff))

			@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
						sum(dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)]) .>=
						sum(dc_fv²[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)]) * (1 - coeff))
		end

		println("\t constraints: 12) data centra constraints\t\t\t\t done")
	end

	# println("\n")
	println("Model has been loaded")
	println("Step-4: calculation...")
	JuMP.optimize!(scuc)

	println("callback gurobisolver\t\t\t\t\t\t\t done")
	@test JuMP.termination_status(scuc) == MOI.OPTIMAL
	@test JuMP.primal_status(scuc) == MOI.FEASIBLE_POINT
	println("#TEST: termination_status\t\t\t\t\t\t pass")

	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
	# println("pg₀>>\n", JuMP.value.(pg₀[1:NG,1:NT]))
	# println("x>>  \n", JuMP.value.(x))
	# println("Δpd>>\n", JuMP.value.(Δpd[1:ND,1:NT]))
	# println("Δpw>>\n", JuMP.value.(Δpw[1:NW,1:NT]))
	su_cost = sum(JuMP.value.(su₀))
	sd_cost = sum(JuMP.value.(sd₀))
	pᵪ = JuMP.value.(pgₖ)
	p₀ = JuMP.value.(pg₀)
	x₀ = JuMP.value.(x)
	r⁺ = JuMP.value.(sr⁺)
	r⁻ = JuMP.value.(sr⁻)
	pᵨ = JuMP.value.(Δpd)
	pᵩ = JuMP.value.(Δpw)

	pss_charge_state⁺ = JuMP.value.(κ⁺)
	pss_charge_state⁻ = JuMP.value.(κ⁻)
	pss_charge_p⁺ = JuMP.value.(pc⁺)
	pss_charge_p⁻ = JuMP.value.(pc⁻)
	pss_charge_q = JuMP.value.(qc)
	# pss_sumchargeenergy = JuMP.value.(pss_sumchargeenergy)

	prod_cost = pₛ *
				c₀ *
				(sum(sum(sum(sum(pᵪ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
						 for s in 1:NS) for i in 1:NG) +
				 sum(sum(sum(x₀[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS))
	cr⁺ = pₛ *
		  c₀ *
		  sum(sum(sum(ρ⁺ * r⁺[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
			  for s in 1:NS)
	cr⁻ = pₛ *
		  c₀ *
		  sum(sum(sum(ρ⁺ * r⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
			  for s in 1:NS)
	seq_sr⁺ = pₛ * c₀ * sum(ρ⁺ * r⁺[i, :] for i in 1:NG)
	seq_sr⁻ = pₛ * c₀ * sum(ρ⁺ * r⁻[i, :] for i in 1:NG)
	𝜟pd = pₛ * sum(sum(sum(pᵨ[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)
	𝜟pw = pₛ * sum(sum(sum(pᵩ[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
	str = zeros(1, 7)
	str[1, 1] = su_cost * 10
	str[1, 2] = sd_cost * 10
	str[1, 3] = prod_cost
	str[1, 4] = cr⁺
	str[1, 5] = cr⁻
	str[1, 6] = 𝜟pd
	str[1, 7] = 𝜟pw

	# Set output directory for results
	output_dir = joinpath(pwd(), "output")

	# Create directory if it doesn't exist
	try
		if !isdir(output_dir)
			mkdir(output_dir)
		end

		# Open output file for writing results
		output_file = joinpath(output_dir, "Bench_calculation_result.txt")
		open(output_file, "w") do io
			writedlm(io, [" "])
			writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr⁺" "cr⁻" "𝜟pd" "𝜟pw"], '\t')
			writedlm(io, str, '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 1: units stutup/down states"])
			writedlm(io, JuMP.value.(x), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 2: units dispatching power in scenario NO.1"])
			writedlm(io, JuMP.value.(pg₀[1:NG, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 3: spolied wind power"])
			writedlm(io, JuMP.value.(Δpw[1:NW, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 4: forced load curtailments"])
			writedlm(io, JuMP.value.(Δpd[1:ND, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 5: pss charge state"])
			writedlm(io, pss_charge_state⁺[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 6: pss discharge state"])
			writedlm(io, pss_charge_state⁻[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 7: pss charge power"])
			writedlm(io, pss_charge_p⁺[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 8: pss discharge power"])
			writedlm(io, pss_charge_p⁻[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 9: pss strored energy"])
			writedlm(io, pss_charge_q[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 10: sr⁺"])
			writedlm(io, r⁺[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 11: sr⁻"])
			writedlm(io, r⁻[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 12: α"])
			writedlm(io, JuMP.value.(α[1:NC, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 13: β"])
			return writedlm(io, JuMP.value.(β[1:NC, 1:NT]), '\t')
		end
		println("The calculation result has been saved to: $output_file")
		println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

		# Open output file for writing results
		output_file = joinpath(output_dir, "Bench_datacentra_result.txt")
		open(output_file, "w") do io
			writedlm(io, [" "])
			writedlm(io, ["list 1: dc_p"], '\t')
			writedlm(io, JuMP.value.(dc_p)[1:(ND2 * 1), 1:NT]', '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 2: dc_fv²"])
			writedlm(io, JuMP.value.(dc_fv²)[1:(ND2 * 1), 1:NT]', '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 3: dc_fv²λ"])
			writedlm(io, JuMP.value.(dc_fv²λ)[1:(ND2 * 1), 1:NT]', '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 4: dc_fv²λ"])
			writedlm(io,
					 (JuMP.value.(dc_fv²λ)[1:(ND2 * 1), 1:NT] ./
					  JuMP.value.(dc_fv²)[1:((ND2 * 1)'), 1:NT])', 't')
			writedlm(io, [" "])
			writedlm(io, ["list 5: dc_fv²λ_minus"])
			writedlm(io, (JuMP.value.(dc_fv²λ_minus)[1:(ND2 * 1), 1:NT])', '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 6: dc_fv²λ_plus"])
			writedlm(io, (JuMP.value.(dc_fv²λ_plus)[1:(ND2 * 1), 1:NT])', '\t')
		end
		println("The calculation result has been saved to: $output_file")
		println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

		# Open output file for csv writing results
		output_dir = "D:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/"

		s = 1

	catch e
		println("Error writing results to file: $e")
	end

	result = Dict("x₀" => x₀,
				  "p₀" => p₀,
				  "pᵨ" => pᵨ,
				  "pᵩ" => pᵩ,
				  "seq_sr⁺" => seq_sr⁺,
				  "seq_sr⁻" => seq_sr⁻,
				  "pss_charge_p⁺" => pss_charge_p⁺,
				  "pss_charge_p⁻" => pss_charge_p⁻,
				  # "pss_charge_q⁺" => pss_charge_q⁺,
				  "su_cost" => su_cost,
				  "sd_cost" => sd_cost,
				  "prod_cost" => prod_cost,
				  "cr⁺" => cr⁺,
				  "cr⁻" => cr⁻, "dc_p" => JuMP.value.(dc_p[1:(ND2 * NS), 1:NT]),
				  "dc_fv²" => JuMP.value.(dc_fv²[1:(ND2 * NS), 1:NT]),
				  "dc_fv²λ" => JuMP.value.(dc_fv²λ[1:(ND2 * NS), 1:NT]),
				  "dc_fv²_plus" => JuMP.value.(dc_fv²_plus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²_minus" => JuMP.value.(dc_fv²_minus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²_2_plus" => JuMP.value.(dc_fv²_2_plus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²_2_minus" => JuMP.value.(dc_fv²_2_minus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²λ_plus" => JuMP.value.(dc_fv²λ_plus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²λ_minus" => JuMP.value.(dc_fv²λ_minus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²λ_2_plus" => JuMP.value.(dc_fv²λ_2_plus[1:(ND2 * NS), 1:NT]),
				  "dc_fv²λ_2_minus" => JuMP.value.(dc_fv²λ_2_minus[1:(ND2 * NS), 1:NT]),
				  "weight_fv²_minus" => JuMP.value.(weight_fv²_minus[1:(ND2 * NS), 1:NT, 1:num_sos]),
				  "weight_fv²_plus" => JuMP.value.(weight_fv²_plus[1:(ND2 * NS), 1:NT, 1:num_sos]),
				  "weight_fv²λ_minus" => JuMP.value.(weight_fv²λ_minus[1:(ND2 * NS), 1:NT, 1:num_sos]),
				  "weight_fv²λ_plus" => JuMP.value.(weight_fv²λ_plus[1:(ND2 * NS), 1:NT, 1:num_sos]))

	if config_param.is_ConsiderDataCentra == 1
		save_data_centra(result, num_sos, output_dir)
	end

	return result
end

function save_data_centra(res, num_sos, output_dir)
	data_to_write = [("dc_p.csv", (res["dc_p"][1:(ND2), 1:NT])),
		("dc_fv².csv", (res["dc_fv²"][1:(ND2), 1:NT])),
		("dc_fv²λ.csv", (res["dc_fv²λ"][1:(ND2), 1:NT])),
		("dc_fv²_plus.csv", (res["dc_fv²_plus"][1:(ND2), 1:NT])),
		("dc_λ.csv", (res["dc_fv²λ"][1:(ND2), 1:NT] ./ res["dc_fv²"][1:(ND2), 1:NT])),
		("dc_fv²_minus.csv", (res["dc_fv²_minus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²λ_plus.csv", (res["dc_fv²λ_plus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²λ_minus.csv", (res["dc_fv²λ_minus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²_2_plus.csv", (res["dc_fv²_2_plus"][1:(ND2), 1:NT])),
		("dc_fv²_2_minus.csv", (res["dc_fv²_2_minus"][1:(ND2), 1:NT])),
		("dc_fv²λ_2_plus.csv", (res["dc_fv²λ_2_plus"][1:(ND2), 1:NT])),
		("dc_fv²λ_2_minus.csv", (res["dc_fv²λ_2_minus"][1:(ND2), 1:NT]))
		# ("weight_fv²_minus.csv", (res["weight_fv²_minus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²_plus.csv", (res["weight_fv²_plus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²λ_minus.csv", (res["weight_fv²λ_minus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²λ_plus.csv", (res["weight_fv²λ_plus"][1:(ND2), 1:NT, 1:num_sos]))
	]

	for (filename, data) in data_to_write
		filepath = joinpath(output_dir, filename)
		try
			CSV.write(filepath, DataFrame(data, :auto))
			println("Successfully wrote to $filepath")
		catch e
			@error "Failed to write to $filepath" exception=(e, catch_backtrace())
		end
	end
end

function get_dcc_boundaries_conditions(num_sos, ND2)
	dcc_f_lb                    = ones(ND2, 1) * 0.50
	dcc_f_ub                    = ones(ND2, 1) * 1.50
	dcc_v_lb                    = ones(ND2, 1) * 0.85
	dcc_v_ub                    = ones(ND2, 1) * 1.50
	dcc_v²_lb                  = dcc_v_lb .^ 2
	dcc_v²_ub                  = dcc_v_ub .^ 2
	dcc_fv²_plus_ub            = (0.50 * (dcc_f_ub + dcc_v²_ub))[:, 1]
	dcc_fv²_plus_lb            = (0.50 * (dcc_f_lb + dcc_v²_lb))[:, 1]
	dcc_fv²_minus_ub           = (0.50 * abs.(dcc_f_ub - dcc_v²_ub))[:, 1]
	dcc_fv²_minus_lb           = (0.50 * abs.(dcc_f_lb - dcc_v²_lb))[:, 1]
	dcc_fv²_plus_discrete      = collect(range(dcc_fv²_plus_lb[1], dcc_fv²_plus_ub[1]; length = num_sos))
	dcc_fv²_minus_discrete     = collect(range(dcc_fv²_minus_lb[1], dcc_fv²_minus_ub[1]; length = num_sos))
	dcc_fv²_2_plus_discrete    = [t^2 for t in dcc_fv²_plus_discrete]
	dcc_fv²_2_minus_discrete   = [t^2 for t in dcc_fv²_minus_discrete]
	dc_λ_lb                    = ones(ND2, 1) * 0.5
	dc_λ_ub                    = ones(ND2, 1) * 1.5
	dcc_fv²λ_plus_ub          = (0.50 * (dcc_fv²_plus_ub + dc_λ_ub))[:, 1]
	dcc_fv²λ_plus_lb          = (0.50 * (dcc_fv²_plus_lb + dc_λ_lb))[:, 1]
	dcc_fv²λ_minus_ub         = (0.50 * abs.(dcc_fv²_minus_ub - dc_λ_ub))[:, 1]
	dcc_fv²λ_minus_lb         = (0.50 * abs.(dcc_fv²_minus_lb - dc_λ_lb))[:, 1]
	dcc_fv²λ_plus_discrete    = collect(range(dcc_fv²λ_plus_lb[1], dcc_fv²λ_plus_ub[1]; length = num_sos))
	dcc_fv²λ_minus_discrete   = collect(range(dcc_fv²λ_minus_lb[1], dcc_fv²λ_minus_ub[1]; length = num_sos))
	dcc_fv²λ_2_plus_discrete  = [t^2 for t in dcc_fv²λ_plus_discrete]
	dcc_fv²λ_2_minus_discrete = [t^2 for t in dcc_fv²λ_minus_discrete]

	dcc_boundries_conditions = Dict("dcc_f_lb" => dcc_f_lb,
									"dcc_f_ub" => dcc_f_ub,
									"dcc_v_lb" => dcc_v_lb,
									"dcc_v_ub" => dcc_v_ub,
									"dcc_v²_lb" => dcc_v²_lb,
									"dcc_v²_ub" => dcc_v²_ub,
									"dcc_fv²_plus_ub" => dcc_fv²_plus_ub,
									"dcc_fv²_minus_ub" => dcc_fv²_minus_ub,
									"dcc_fv²_plus_lb" => dcc_fv²_plus_lb,
									"dcc_fv²_minus_lb" => dcc_fv²_minus_lb,
									"dc_λ_ub" => dc_λ_ub,
									"dc_λ_lb" => dc_λ_lb,
									"dcc_fv²λ_plus_ub" => dcc_fv²λ_plus_ub,
									"dcc_fv²λ_minus_ub" => dcc_fv²λ_minus_ub,
									"dcc_fv²λ_plus_lb" => dcc_fv²λ_plus_lb,
									"dcc_fv²λ_minus_lb" => dcc_fv²λ_minus_lb,
									"dcc_fv²_plus_discrete" => dcc_fv²_plus_discrete,
									"dcc_fv²_minus_discrete" => dcc_fv²_minus_discrete,
									"dcc_fv²λ_plus_discrete" => dcc_fv²λ_plus_discrete,
									"dcc_fv²λ_minus_discrete" => dcc_fv²λ_minus_discrete,
									"dcc_fv²_2_plus_discrete" => dcc_fv²_2_plus_discrete,
									"dcc_fv²_2_minus_discrete" => dcc_fv²_2_minus_discrete,
									"dcc_fv²λ_2_plus_discrete" => dcc_fv²λ_2_plus_discrete,
									"dcc_fv²λ_2_minus_discrete" => dcc_fv²λ_2_minus_discrete,
									"num_sos" => num_sos)
	return dcc_boundries_conditions
end
