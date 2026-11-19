# =============================================================================
# run.jl — Entry point for the DataCentra Unit Commitment model
#
# Usage:
#   julia --project=. run.jl
# =============================================================================

using Pkg
# Instantiate only when Manifest looks incomplete (skips ~seconds on warm runs)
const _manifest = joinpath(@__DIR__, "Manifest.toml")
if !isfile(_manifest) || get(ENV, "DCC_FORCE_INSTANTIATE", "0") == "1"
	Pkg.instantiate()
else
	try
		Pkg.instantiate(; verbose=false)
	catch
		Pkg.instantiate()
	end
end

include("src/DataCentraUC.jl")
using .DataCentraUC

println("="^70)
println("  DataCentra Unit Commitment — SUC-SCUC Model")
println("="^70)

# Smoke-friendly defaults: skip R scripts unless DCC_RUN_R=1
result_dc, result_bench = run_unit_commitment(
	display_boundary = false,
	run_r = get(ENV, "DCC_RUN_R", "0") == "1",
	make_plots = get(ENV, "DCC_SKIP_PLOTS", "0") != "1",
)

println("\nDone.")
println("  Results → output/")
println("  Plots   → fig/")
if result_dc !== nothing
	println("  DC prod_cost    ≈ ", round(result_dc["prod_cost"]; digits=2))
end
if result_bench !== nothing
	println("  Bench prod_cost ≈ ", round(result_bench["prod_cost"]; digits=2))
end
