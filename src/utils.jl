# =============================================================================
# utils.jl — Shared helpers (indexing, logging, solver config)
# =============================================================================

"""
	sc_range(s, n)

Scenario block index range for flattened scenario×unit arrays.
Scenario `s` occupies rows `((s-1)*n + 1):(s*n)`.
"""
@inline sc_range(s::Integer, n::Integer) = ((s - 1) * n + 1):(s * n)

"""
	sc_offset(s, n)

First row index of scenario `s` in a flattened scenario×unit array.
"""
@inline sc_offset(s::Integer, n::Integer) = (s - 1) * n

"""
	project_root()

Absolute path to the package / project root (parent of `src/`).
"""
project_root() = normpath(joinpath(@__DIR__, ".."))

"""
	output_dir()

Canonical output directory (`<project>/output`).
"""
output_dir() = joinpath(project_root(), "output")

"""
	fig_dir()

Canonical figure directory (`<project>/fig`).
"""
fig_dir() = joinpath(project_root(), "fig")

"""
	configure_gurobi!(model; time_limit=nothing, silent=false)

Apply practical Gurobi settings for this UC MILP.
"""
function configure_gurobi!(model; time_limit::Union{Nothing,Real}=nothing, silent::Bool=false)
	set_optimizer_attribute(model, "OutputFlag", silent ? 0 : 1)
	set_optimizer_attribute(model, "Threads", max(1, Sys.CPU_THREADS ÷ 2))
	set_optimizer_attribute(model, "MIPFocus", 1)       # emphasize feasible → improve
	set_optimizer_attribute(model, "NumericFocus", 1)   # large penalty coeffs
	set_optimizer_attribute(model, "Presolve", 2)       # aggressive
	set_optimizer_attribute(model, "Cuts", 2)
	set_optimizer_attribute(model, "MIPGap", 1e-4)
	if time_limit !== nothing
		set_optimizer_attribute(model, "TimeLimit", Float64(time_limit))
	end
	return model
end

"""
	section(title)

Print a visual section banner.
"""
function section(title::AbstractString)
	println("\n", "="^70)
	println("  ", title)
	println("="^70)
end

"""
	step(msg)

Print a progress step line.
"""
step(msg::AbstractString) = println("→ ", msg)
