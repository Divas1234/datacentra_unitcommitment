# =============================================================================
# dcc.jl — Data Center DVFS: boundaries, SOS1 linearization, JuMP constraints
# =============================================================================
# Power model:  P = idle + (sv/μ) · workload · (f·v²·λ)
# Product encoding uses x*y = ((x+y)/2)² − ((x−y)/2)² with SOS1 / convex weights.
#
# Env toggles:
#   DCC_SIMPLE=1              → skip SOS1; fix f·v²·λ ≡ 1
#   DCC_COUPLE_BAND=0.25      → relative band |fv2λ − fv2| / fv2
# =============================================================================

# --- Environment helpers -------------------------------------------------------

function _env_flag(name::AbstractString, default::Bool=false)::Bool
	v = get(ENV, name, nothing)
	v === nothing && return default
	s = lowercase(strip(v))
	return !(s in ("0", "false", "no", "off", ""))
end

function _env_float(name::AbstractString, default::Float64)::Float64
	v = get(ENV, name, nothing)
	v === nothing && return default
	x = tryparse(Float64, strip(v))
	return x === nothing ? default : x
end

_dcc_simple_mode() = _env_flag("DCC_SIMPLE", false)
_dcc_couple_band() = clamp(_env_float("DCC_COUPLE_BAND", 0.25), 0.0, 0.95)

# --- Boundary / discrete grid --------------------------------------------------

"""
	compute_dcc_boundaries(num_sos, ND2)

Discrete SOS1 / convex-combination breakpoints for `f·v²` and `f·v²·λ`.
Uses `x*y = ((x+y)/2)² − ((x−y)/2)²` with `minus ≥ 0`.
"""
function compute_dcc_boundaries(num_sos, ND2)
	f_lb  = ones(ND2) * 0.50
	f_ub  = ones(ND2) * 1.50
	v_lb  = ones(ND2) * 0.85
	v_ub  = ones(ND2) * 1.50
	v2_lb = v_lb .^ 2
	v2_ub = v_ub .^ 2

	fv2_plus_lb  = 0.5 .* (f_lb .+ v2_lb)
	fv2_plus_ub  = 0.5 .* (f_ub .+ v2_ub)
	fv2_minus_lb = zeros(ND2)
	fv2_minus_ub = 0.5 .* max.(abs.(f_lb .- v2_ub), abs.(f_ub .- v2_lb))
	fv2_lb = f_lb .* v2_lb
	fv2_ub = f_ub .* v2_ub

	λ_lb = ones(ND2) * 0.5
	λ_ub = ones(ND2) * 1.5

	fv2λ_plus_lb  = 0.5 .* (fv2_lb .+ λ_lb)
	fv2λ_plus_ub  = 0.5 .* (fv2_ub .+ λ_ub)
	fv2λ_minus_lb = zeros(ND2)
	fv2λ_minus_ub = 0.5 .* max.(abs.(fv2_lb .- λ_ub), abs.(fv2_ub .- λ_lb))
	fv2λ_lb = fv2_lb .* λ_lb
	fv2λ_ub = fv2_ub .* λ_ub

	n = num_sos
	fv2_plus_discrete   = collect(range(fv2_plus_lb[1],  fv2_plus_ub[1];  length=n))
	fv2_minus_discrete  = collect(range(fv2_minus_lb[1], fv2_minus_ub[1]; length=n))
	fv2λ_plus_discrete  = collect(range(fv2λ_plus_lb[1], fv2λ_plus_ub[1]; length=n))
	fv2λ_minus_discrete = collect(range(fv2λ_minus_lb[1], fv2λ_minus_ub[1]; length=n))

	return (;
		f_lb, f_ub, v_lb, v_ub, v2_lb, v2_ub,
		fv2_lb, fv2_ub, fv2λ_lb, fv2λ_ub,
		fv2_plus_ub, fv2_plus_lb, fv2_minus_ub, fv2_minus_lb,
		λ_ub, λ_lb,
		fv2λ_plus_ub, fv2λ_plus_lb, fv2λ_minus_ub, fv2λ_minus_lb,
		fv2_plus_discrete, fv2_minus_discrete,
		fv2λ_plus_discrete, fv2λ_minus_discrete,
		fv2_sq_plus_discrete  = fv2_plus_discrete .^ 2,
		fv2_sq_minus_discrete = fv2_minus_discrete .^ 2,
		fv2λ_sq_plus_discrete = fv2λ_plus_discrete .^ 2,
		fv2λ_sq_minus_discrete = fv2λ_minus_discrete .^ 2,
		num_sos,
	)
end

"""
	validate_dcc_boundaries(b, ND2)

Broadcast scalar / length-1 boundary fields to length `ND2`.
"""
function validate_dcc_boundaries(b, ND2)
	_ensure_len(x, n) = isa(x, AbstractVector) ? collect(x) : fill(x, n)
	return (
		f_lb  = _ensure_len(b.f_lb, ND2),
		f_ub  = _ensure_len(b.f_ub, ND2),
		v_lb  = _ensure_len(b.v_lb, ND2),
		v_ub  = _ensure_len(b.v_ub, ND2),
		v2_lb = _ensure_len(b.v2_lb, ND2),
		v2_ub = _ensure_len(b.v2_ub, ND2),
		fv2_lb = _ensure_len(b.fv2_lb, ND2),
		fv2_ub = _ensure_len(b.fv2_ub, ND2),
		fv2λ_lb = _ensure_len(b.fv2λ_lb, ND2),
		fv2λ_ub = _ensure_len(b.fv2λ_ub, ND2),
		fv2_plus_ub  = _ensure_len(b.fv2_plus_ub, ND2),
		fv2_plus_lb  = _ensure_len(b.fv2_plus_lb, ND2),
		fv2_minus_ub = _ensure_len(b.fv2_minus_ub, ND2),
		fv2_minus_lb = _ensure_len(b.fv2_minus_lb, ND2),
		λ_ub = _ensure_len(b.λ_ub, ND2),
		λ_lb = _ensure_len(b.λ_lb, ND2),
		fv2λ_plus_ub  = _ensure_len(b.fv2λ_plus_ub, ND2),
		fv2λ_plus_lb  = _ensure_len(b.fv2λ_plus_lb, ND2),
		fv2λ_minus_ub = _ensure_len(b.fv2λ_minus_ub, ND2),
		fv2λ_minus_lb = _ensure_len(b.fv2λ_minus_lb, ND2),
		fv2_plus_discrete     = collect(b.fv2_plus_discrete),
		fv2_minus_discrete    = collect(b.fv2_minus_discrete),
		fv2λ_plus_discrete    = collect(b.fv2λ_plus_discrete),
		fv2λ_minus_discrete   = collect(b.fv2λ_minus_discrete),
		fv2_sq_plus_discrete  = collect(b.fv2_sq_plus_discrete),
		fv2_sq_minus_discrete = collect(b.fv2_sq_minus_discrete),
		fv2λ_sq_plus_discrete = collect(b.fv2λ_sq_plus_discrete),
		fv2λ_sq_minus_discrete = collect(b.fv2λ_sq_minus_discrete),
		num_sos = b.num_sos,
	)
end

# --- Effective power envelope --------------------------------------------------

"""
	_effective_power_bounds(idle, coef, p_min, p_max, workload, λ_lb, λ_ub)

Precompute ND2×NT reachable power bounds so declared `p_min` never forces
infeasibility when `idle + coef·w·λ_ub < p_min`.
"""
function _effective_power_bounds(idle, coef, p_min, p_max, workload, λ_lb, λ_ub)
	ND2, NT = size(workload)
	p_min_eff = Matrix{Float64}(undef, ND2, NT)
	p_max_eff = Matrix{Float64}(undef, ND2, NT)
	@inbounds for t in 1:NT
		w = @view workload[:, t]
		p_at_hi = idle .+ coef .* w .* λ_ub
		p_at_lo = idle .+ coef .* w .* λ_lb
		for d in 1:ND2
			lo = min(p_min[d], p_at_hi[d])
			hi = max(min(p_max[d], max(p_at_hi[d], p_at_lo[d])), lo)
			p_min_eff[d, t] = lo
			p_max_eff[d, t] = hi
		end
	end
	return p_min_eff, p_max_eff
end

# --- SOS1 product helper -------------------------------------------------------

"""
	_add_sos1_square_diff!(model, z, z_plus, z_minus, z_sq_plus, z_sq_minus,
	                       w_plus, w_minus, plus_disc, minus_disc,
	                       sq_plus_disc, sq_minus_disc, NS, NT, ND2, num_sos)

Encode `z ≈ plus² − minus²` via convex combination over discrete breakpoints.
"""
function _add_sos1_square_diff!(
	model,
	z_var, z_plus, z_minus, z_sq_plus, z_sq_minus,
	w_plus, w_minus,
	plus_disc, minus_disc, sq_plus_disc, sq_minus_disc,
	NS::Int, NT::Int, ND2::Int, num_sos::Int,
)
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		z_var[sc_offset(s, ND2) + d, t] ==
		z_sq_plus[sc_offset(s, ND2) + d, t] - z_sq_minus[sc_offset(s, ND2) + d, t])
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		z_plus[sc_offset(s, ND2) + d, t] ==
		sum(plus_disc[k] * w_plus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos))
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		z_sq_plus[sc_offset(s, ND2) + d, t] ==
		sum(sq_plus_disc[k] * w_plus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos))
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		z_minus[sc_offset(s, ND2) + d, t] ==
		sum(minus_disc[k] * w_minus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos))
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		z_sq_minus[sc_offset(s, ND2) + d, t] ==
		sum(sq_minus_disc[k] * w_minus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos))
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		sum(w_plus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos) == 1)
	@constraint(model, [s = 1:NS, t = 1:NT, d = 1:ND2],
		sum(w_minus[sc_offset(s, ND2) + d, t, k] for k in 1:num_sos) == 1)
	return nothing
end

# --- Main constraint block -----------------------------------------------------

"""
	add_dcc_constraints!(model, dc, config, NS, NT, ND2, num_sos, vars)

Add data-center DVFS constraints. `vars` is a NamedTuple of JuMP variables.
Set `ENV["DCC_SIMPLE"]=1` to skip SOS1 and use fixed workload (λ≡1).
"""
function add_dcc_constraints!(model, dc::DataCenter, config::Config,
                              NS, NT, ND2, num_sos, vars)
	config.is_ConsiderDataCentra != 1 && return num_sos

	_test_dcc_config(dc, NT, ND2)

	simple = _dcc_simple_mode()
	tasks = dc.computational_power_tasks
	size(tasks) == (ND2, NT) || error("DC workload size $(size(tasks)) != ($ND2, $NT)")
	workload = tasks .* 10
	coef = dc.sv_constant ./ dc.mu
	idle = dc.idle_power

	if simple
		@constraint(model, [s = 1:NS, t = 1:NT],
			vars.dc_p[sc_range(s, ND2), t] .== idle .+ coef .* workload[:, t])
		println("\t constraints: DC) simple fixed workload (DCC_SIMPLE=1)\t done")
		return num_sos
	end

	b = validate_dcc_boundaries(compute_dcc_boundaries(num_sos, ND2), ND2)
	band = _dcc_couple_band()

	# Precompute effective power envelope once (ND2 × NT)
	p_min_eff, p_max_eff = _effective_power_bounds(
		idle, coef, dc.p_min, dc.p_max, workload, b.λ_lb, b.λ_ub)

	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_p[sc_range(s, ND2), t] .<= p_max_eff[:, t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_p[sc_range(s, ND2), t] .>= p_min_eff[:, t])
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_p[sc_range(s, ND2), t] .==
		idle .+ coef .* workload[:, t] .* vars.dc_fv2_lambda[sc_range(s, ND2), t])

	# Variable box bounds
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_plus[sc_range(s, ND2), t] .<= b.fv2_plus_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_plus[sc_range(s, ND2), t] .>= b.fv2_plus_lb)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_minus[sc_range(s, ND2), t] .<= b.fv2_minus_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_minus[sc_range(s, ND2), t] .>= b.fv2_minus_lb)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2[sc_range(s, ND2), t] .<= b.fv2_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2[sc_range(s, ND2), t] .>= b.fv2_lb)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda[sc_range(s, ND2), t] .<= b.fv2λ_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda[sc_range(s, ND2), t] .>= b.fv2λ_lb)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda_plus[sc_range(s, ND2), t] .<= b.fv2λ_plus_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda_plus[sc_range(s, ND2), t] .>= b.fv2λ_plus_lb)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda_minus[sc_range(s, ND2), t] .<= b.fv2λ_minus_ub)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda_minus[sc_range(s, ND2), t] .>= b.fv2λ_minus_lb)

	# SOS1 / convex encoding: f·v² and f·v²·λ
	_add_sos1_square_diff!(
		model,
		vars.dc_fv2, vars.dc_fv2_plus, vars.dc_fv2_minus,
		vars.dc_fv2_sq_plus, vars.dc_fv2_sq_minus,
		vars.w_plus_fv2, vars.w_minus_fv2,
		b.fv2_plus_discrete, b.fv2_minus_discrete,
		b.fv2_sq_plus_discrete, b.fv2_sq_minus_discrete,
		NS, NT, ND2, num_sos,
	)
	_add_sos1_square_diff!(
		model,
		vars.dc_fv2_lambda, vars.dc_fv2_lambda_plus, vars.dc_fv2_lambda_minus,
		vars.dc_fv2_lambda_sq_plus, vars.dc_fv2_lambda_sq_minus,
		vars.w_plus_fv2l, vars.w_minus_fv2l,
		b.fv2λ_plus_discrete, b.fv2λ_minus_discrete,
		b.fv2λ_sq_plus_discrete, b.fv2λ_sq_minus_discrete,
		NS, NT, ND2, num_sos,
	)

	# Soft coupling: fv2λ ≈ fv2 within ±band (and block-wise aggregates)
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda[sc_range(s, ND2), t] .<=
		vars.dc_fv2[sc_range(s, ND2), t] .* (1 + band))
	@constraint(model, [s = 1:NS, t = 1:NT],
		vars.dc_fv2_lambda[sc_range(s, ND2), t] .>=
		vars.dc_fv2[sc_range(s, ND2), t] .* (1 - band))

	iter_num = 6
	blk = Int(max(1, round(NT / iter_num)))
	@constraint(model, [s = 1:NS, k = 1:iter_num],
		sum(vars.dc_fv2_lambda[sc_range(s, ND2), ((k - 1) * blk + 1):min(k * blk, NT)]) .<=
		sum(vars.dc_fv2[sc_range(s, ND2), ((k - 1) * blk + 1):min(k * blk, NT)]) .* (1 + band))
	@constraint(model, [s = 1:NS, k = 1:iter_num],
		sum(vars.dc_fv2_lambda[sc_range(s, ND2), ((k - 1) * blk + 1):min(k * blk, NT)]) .>=
		sum(vars.dc_fv2[sc_range(s, ND2), ((k - 1) * blk + 1):min(k * blk, NT)]) .* (1 - band))

	println("\t constraints: DC) DVFS / SOS1 (band=$(band))\t\t done")
	return num_sos
end

"""
	_test_dcc_config(dc, NT, ND2)

Validate workload shape and warn about unreachable `p_min` under λ≤1.5.
"""
function _test_dcc_config(dc::DataCenter, NT::Int64, ND2::Int64)
	tasks = dc.computational_power_tasks
	size(tasks) == (ND2, NT) || error("DC workload size $(size(tasks)) != ($ND2, $NT)")
	workload = tasks .* 10
	coef = dc.sv_constant ./ dc.mu
	consumption = [dc.idle_power[d] + coef[d] * workload[d, t] for d in 1:ND2, t in 1:NT]
	row_max = vec(maximum(consumption; dims=2))
	if all(dc.p_max .>= row_max)
		@info "DCC config check passed: capacity sufficient for workloads"
	else
		@warn "DCC config check FAILED: some p_max < max workload consumption"
	end

	λ_ub = 1.5
	unreachable = count(
		dc.idle_power[d] + coef[d] * workload[d, t] * λ_ub + 1e-9 < dc.p_min[d]
		for d in 1:ND2, t in 1:NT)
	if unreachable > 0
		@warn "DCC p_min unreachable for $unreachable (dc,t) slots at λ≤$λ_ub; using effective bounds"
	end
end
