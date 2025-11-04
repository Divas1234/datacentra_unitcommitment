# module DCCConstraints

# export add_dcc_constraints!

"""
	add_dcc_constraints!(scuc, DataCentras, config_param, NS, NT, ND2, num_sos, vars::NamedTuple)

Add Data-Centra related constraints to `scuc`. `vars` is a NamedTuple that must contain:
  dc_p, dc_fv², dc_fv²λ, dc_fv²_plus, dc_fv²_minus,
  dc_fv²_2_plus, dc_fv²_2_minus, dc_fv²λ_plus, dc_fv²λ_minus,
  dc_fv²λ_2_plus, dc_fv²λ_2_minus,
  weight_fv²_plus, weight_fv²_minus, weight_fv²λ_plus, weight_fv²λ_minus

Returns possibly-updated num_sos.


"""
function add_dcc_constraints!(scuc, DataCentras, config_param, NS::Int, NT::Int, ND2::Int, num_sos::Int, dc_p,
							  dc_fv², dc_fv²λ, dc_fv²_plus, dc_fv²_minus, dc_fv²_2_plus, dc_fv²_2_minus, dc_fv²λ_plus, dc_fv²λ_minus, dc_fv²λ_2_plus, dc_fv²λ_2_minus, weight_fv²_minus,
							  weight_fv²_plus, weight_fv²λ_minus, weight_fv²λ_plus)
	if config_param.is_ConsiderDataCentra != 1
		return num_sos
	end

	test_dcc_configuations(DataCentras, NT, ND2)

	enable_active_response_flag = 1
	if enable_active_response_flag == 0
		workload_multijob = DataCentras.computational_power_tasks' * 10
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .== DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .* workload_multijob[:, t])
	else
		dcc_boundries_conditions = get_dcc_boundaries_conditions(num_sos, ND2)

		dcc_f_lb, dcc_f_ub, dcc_v_lb, dcc_v_ub, dcc_v2_lb, dcc_v2_ub,
		dcc_fv2_plus_ub, dcc_fv2_minus_ub, dcc_fv2_plus_lb, dcc_fv2_minus_lb,
		dc_lambda_ub, dc_lambda_lb,
		dcc_fv2lambda_plus_ub, dcc_fv2lambda_minus_ub, dcc_fv2lambda_plus_lb, dcc_fv2lambda_minus_lb,
		dcc_fv2_plus_discrete, dcc_fv2_minus_discrete,
		dcc_fv2lambda_plus_discrete, dcc_fv2lambda_minus_discrete,
		dcc_fv2_2_plus_discrete, dcc_fv2_2_minus_discrete,
		dcc_fv2lambda_2_plus_discrete, dcc_fv2lambda_2_minus_discrete,
		num_sos = get_dcc_adjusted_boundaries_conditions(dcc_boundries_conditions, num_sos, ND2)

		workload_multijob = DataCentras.computational_power_tasks' * 10

		# bounds and basic relationship
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .<= DataCentras.p_max .* 1)
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .>= DataCentras.p_min .* 0)
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .== DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .* workload_multijob[:, t] .* dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t])

		# fv^2 plus/minus bounds
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²_plus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv2_plus_ub)
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²_plus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv2_plus_lb)
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²_minus[((s - 1) * ND2 + 1):(s * ND2), t] .<= dcc_fv2_minus_ub)
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²_minus[((s - 1) * ND2 + 1):(s * ND2), t] .>= dcc_fv2_minus_lb)

		# SOS1 linear combinations (reformulated as convex combinations over discrete points)
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²[(s - 1) * ND2 + i, t] == dc_fv²_2_plus[(s - 1) * ND2 + i, t] - dc_fv²_2_minus[(s - 1) * ND2 + i, t])
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv2_plus_discrete[z] * weight_fv²_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²_2_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv2_2_plus_discrete[z] * weight_fv²_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv2_minus_discrete[z] * weight_fv²_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²_2_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv2_2_minus_discrete[z] * weight_fv²_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))

		# @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²[(s - 1) * ND2 + i, t] == dc_fv²_2_plus[(s - 1) * ND2 + i, t] - dc_fv²_2_minus[(s - 1) * ND2 + i, t])

		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos) == 1)
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos) == 1)

		# lambda SOS1 and relations
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1) * 1.5)
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1) * 1.5)

		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²λ[(s - 1) * ND2 + i, t] == dc_fv²λ_2_plus[(s - 1) * ND2 + i, t] - dc_fv²λ_2_minus[(s - 1) * ND2 + i, t])
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²λ_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv2lambda_plus_discrete[z] * weight_fv²λ_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²λ_2_plus[(s - 1) * ND2 + i, t] == sum(dcc_fv2lambda_2_plus_discrete[z] * weight_fv²λ_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], dc_fv²λ_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv2lambda_minus_discrete[z] * weight_fv²λ_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2],
					dc_fv²λ_2_minus[(s - 1) * ND2 + i, t] == sum(dcc_fv2lambda_2_minus_discrete[z] * weight_fv²λ_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos))

		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²λ_plus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos) == 1)
		@constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:ND2], sum(weight_fv²λ_minus[(s - 1) * ND2 + i, t, z] for z in 1:num_sos) == 1)

		# time-block aggregate constraints
		iter_num = 6
		coeff = 0.05
		@constraint(scuc, [s = 1:NS, t = 1:NT], dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_fv²[((s - 1) * ND2 + 1):(s * ND2), t] * (1 + 0.05))

		iter_block = Int(max(1, round(NT / iter_num)))
		@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
					sum(dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(min(iter * iter_block, NT))]) .<=
					sum(dc_fv²[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(min(iter * iter_block, NT))]) * (1 + coeff))

		@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
					sum(dc_fv²λ[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(min(iter * iter_block, NT))]) .>=
					sum(dc_fv²[((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(min(iter * iter_block, NT))]) * (1 - coeff))
	end

	println("\t constraints: 12) data centra constraints\t\t\t\t done")
	# return num_sos
end

# end # module
function test_dcc_configuations(DataCentras, NT, ND2)

	workload_multijob = DataCentras.computational_power_tasks' * 10



	dcc_workload_consumption = zeros(ND2, NT)
	for t in 1:NT
		dcc_workload_consumption[:, t] = DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .* workload_multijob[:, t]
	end

	# convert matrix (ND2 x NT) into DataFrame where each column is a time step (t1..tNT)
	df_dcc_workload_consumption = DataFrame(dcc_workload_consumption, :auto)
	# row-wise maxima (one value per task / row)
	row_max_dcc = vec(maximum(dcc_workload_consumption, dims = 2))
	rename!(df_dcc_workload_consumption, Symbol.("t" .* string.(1:size(dcc_workload_consumption, 2))))
	# add a task_id column for row identification
	insertcols!(df_dcc_workload_consumption, 1, :task_id => collect(1:size(dcc_workload_consumption, 1)))

	@info "test dcc dcc_boundary_configurations"
	if all(DataCentras.p_max .>= row_max_dcc)
		@info "test passed: all DataCentras.p_max >= row_max_dcc"
	else
		@warn "test failed: some DataCentras.p_max < row_max_dcc"
	end
end
