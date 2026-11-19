# =============================================================================
# mainfun.jl — Legacy entry point (redirects to new run.jl)
#
# This file kept for backward compatibility.
# The recommended entry point is now `run.jl`.
# =============================================================================

println("="^60)
println("  NOTE: mainfun.jl is deprecated.")
println("  Please use the new entry point instead:")
println("    julia --project=. run.jl")
println("  or:")
println("    julia --project=.")
println("    julia> include(\"run.jl\")")
println("="^60)

include("run.jl")
