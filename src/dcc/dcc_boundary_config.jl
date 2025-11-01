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

function get_dcc_adjusted_boundaries_conditions(dcc_boundries_conditions::Dict, num_sos::Int, ND2::Int)
	# Robust extraction and validation of data-centra boundary conditions
	# Ensure all expected keys are present, convert types and validate sizes.
	expected_keys = [
		"dcc_f_lb", "dcc_f_ub", "dcc_v_lb", "dcc_v_ub",
		"dcc_v²_lb", "dcc_v²_ub",
		"dcc_fv²_plus_ub", "dcc_fv²_minus_ub",
		"dcc_fv²_plus_lb", "dcc_fv²_minus_lb",
		"dc_λ_ub", "dc_λ_lb",
		"dcc_fv²λ_plus_ub", "dcc_fv²λ_minus_ub",
		"dcc_fv²λ_plus_lb", "dcc_fv²λ_minus_lb",
		"dcc_fv²_plus_discrete", "dcc_fv²_minus_discrete",
		"dcc_fv²λ_plus_discrete", "dcc_fv²λ_minus_discrete",
		"dcc_fv²_2_plus_discrete", "dcc_fv²_2_minus_discrete",
		"dcc_fv²λ_2_plus_discrete", "dcc_fv²λ_2_minus_discrete",
		"num_sos"
	]

	for k in expected_keys
		if !haskey(dcc_boundries_conditions, k)
			error("SUC_scucmodel: missing key in dcc_boundries_conditions -> $k")
		end
	end

	# Extract scalar/array bounds and ensure they are concrete Arrays (not views)
	dcc_f_lb = copy(dcc_boundries_conditions["dcc_f_lb"])
	dcc_f_ub = copy(dcc_boundries_conditions["dcc_f_ub"])
	dcc_v_lb = copy(dcc_boundries_conditions["dcc_v_lb"])
	dcc_v_ub = copy(dcc_boundries_conditions["dcc_v_ub"])
	dcc_v²_lb = copy(dcc_boundries_conditions["dcc_v²_lb"])
	dcc_v²_ub = copy(dcc_boundries_conditions["dcc_v²_ub"])

	dcc_fv²_plus_ub  = copy(dcc_boundries_conditions["dcc_fv²_plus_ub"])
	dcc_fv²_minus_ub = copy(dcc_boundries_conditions["dcc_fv²_minus_ub"])
	dcc_fv²_plus_lb  = copy(dcc_boundries_conditions["dcc_fv²_plus_lb"])
	dcc_fv²_minus_lb = copy(dcc_boundries_conditions["dcc_fv²_minus_lb"])

	dc_λ_ub = copy(dcc_boundries_conditions["dc_λ_ub"])
	dc_λ_lb = copy(dcc_boundries_conditions["dc_λ_lb"])

	dcc_fv²λ_plus_ub  = copy(dcc_boundries_conditions["dcc_fv²λ_plus_ub"])
	dcc_fv²λ_minus_ub = copy(dcc_boundries_conditions["dcc_fv²λ_minus_ub"])
	dcc_fv²λ_plus_lb  = copy(dcc_boundries_conditions["dcc_fv²λ_plus_lb"])
	dcc_fv²λ_minus_lb = copy(dcc_boundries_conditions["dcc_fv²λ_minus_lb"])

	# Discrete values for SOS/pwl reconstruction (should be 1D arrays or vectors)
	dcc_fv²_plus_discrete      = collect(dcc_boundries_conditions["dcc_fv²_plus_discrete"])
	dcc_fv²_minus_discrete     = collect(dcc_boundries_conditions["dcc_fv²_minus_discrete"])
	dcc_fv²λ_plus_discrete    = collect(dcc_boundries_conditions["dcc_fv²λ_plus_discrete"])
	dcc_fv²λ_minus_discrete   = collect(dcc_boundries_conditions["dcc_fv²λ_minus_discrete"])
	dcc_fv²_2_plus_discrete    = collect(dcc_boundries_conditions["dcc_fv²_2_plus_discrete"])
	dcc_fv²_2_minus_discrete   = collect(dcc_boundries_conditions["dcc_fv²_2_minus_discrete"])
	dcc_fv²λ_2_plus_discrete  = collect(dcc_boundries_conditions["dcc_fv²λ_2_plus_discrete"])
	dcc_fv²λ_2_minus_discrete = collect(dcc_boundries_conditions["dcc_fv²λ_2_minus_discrete"])

	# num_sos must be an integer > 0
	num_sos = Int(round(dcc_boundries_conditions["num_sos"]))
	if num_sos <= 0
		error("SUC_scucmodel: num_sos must be a positive integer")
	end

	# Validate discrete arrays length against num_sos
	discrete_sets = [
		(:dcc_fv²_plus_discrete, dcc_fv²_plus_discrete),
		(:dcc_fv²_minus_discrete, dcc_fv²_minus_discrete),
		(:dcc_fv²λ_plus_discrete, dcc_fv²λ_plus_discrete),
		(:dcc_fv²λ_minus_discrete, dcc_fv²λ_minus_discrete),
		(:dcc_fv²_2_plus_discrete, dcc_fv²_2_plus_discrete),
		(:dcc_fv²_2_minus_discrete, dcc_fv²_2_minus_discrete),
		(:dcc_fv²λ_2_plus_discrete, dcc_fv²λ_2_plus_discrete),
		(:dcc_fv²λ_2_minus_discrete, dcc_fv²λ_2_minus_discrete)
	]
	for (name, arr) in discrete_sets
		if length(arr) != num_sos
			error("SUC_scucmodel: length($name) == $(length(arr)) does not match num_sos == $num_sos")
		end
	end

	# Optional: ensure bound arrays are compatible with ND2 (if ND2 is defined)
	try
		if ND2 > 0
			# Convert scalar bounds to vectors if necessary
			function ensure_len(x, n)
				isa(x, AbstractVector) ? collect(x) : fill(x, n)
			end
			dcc_f_lb            = ensure_len(dcc_f_lb, ND2)
			dcc_f_ub            = ensure_len(dcc_f_ub, ND2)
			dcc_v_lb            = ensure_len(dcc_v_lb, ND2)
			dcc_v_ub            = ensure_len(dcc_v_ub, ND2)
			dcc_v²_lb          = ensure_len(dcc_v²_lb, ND2)
			dcc_v²_ub          = ensure_len(dcc_v²_ub, ND2)
			dcc_fv²_plus_ub    = ensure_len(dcc_fv²_plus_ub, ND2)
			dcc_fv²_minus_ub   = ensure_len(dcc_fv²_minus_ub, ND2)
			dcc_fv²_plus_lb    = ensure_len(dcc_fv²_plus_lb, ND2)
			dcc_fv²_minus_lb   = ensure_len(dcc_fv²_minus_lb, ND2)
			dc_λ_ub            = ensure_len(dc_λ_ub, ND2)
			dc_λ_lb            = ensure_len(dc_λ_lb, ND2)
			dcc_fv²λ_plus_ub  = ensure_len(dcc_fv²λ_plus_ub, ND2)
			dcc_fv²λ_minus_ub = ensure_len(dcc_fv²λ_minus_ub, ND2)
			dcc_fv²λ_plus_lb  = ensure_len(dcc_fv²λ_plus_lb, ND2)
			dcc_fv²λ_minus_lb = ensure_len(dcc_fv²λ_minus_lb, ND2)
		end
	catch _e
		# If ND2 is not defined or check failed, proceed silently (compatibility best-effort)
	end

	return dcc_f_lb, dcc_f_ub, dcc_v_lb, dcc_v_ub, dcc_v²_lb, dcc_v²_ub,
		   dcc_fv²_plus_ub, dcc_fv²_minus_ub, dcc_fv²_plus_lb, dcc_fv²_minus_lb,
		   dc_λ_ub, dc_λ_lb,
		   dcc_fv²λ_plus_ub, dcc_fv²λ_minus_ub, dcc_fv²λ_plus_lb, dcc_fv²λ_minus_lb,
		   dcc_fv²_plus_discrete, dcc_fv²_minus_discrete,
		   dcc_fv²λ_plus_discrete, dcc_fv²λ_minus_discrete,
		   dcc_fv²_2_plus_discrete, dcc_fv²_2_minus_discrete,
		   dcc_fv²λ_2_plus_discrete, dcc_fv²λ_2_minus_discrete,
		   num_sos
end
