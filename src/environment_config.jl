# =============================================================================
# environment_config.jl — Compatibility wrapper
#
# This file is kept for backward compatibility.
# The recommended entry point is now `run.jl` or using the DataCentraUC module.
# =============================================================================

println("NOTE: environment_config.jl is a compatibility wrapper.")
println("      Please use `julia --project=. run.jl` instead.")
println("      Loading DataCentraUC module...\n")

include("src/DataCentraUC.jl")
using .DataCentraUC
