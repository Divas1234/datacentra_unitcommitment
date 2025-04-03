using Pkg
Pkg.activate("./.pkg")
include("src/environment_config.jl")
include("src/formatteddata.jl")
include("src/renewableenergysimulation.jl")
include("src/showboundrycase.jl")
include("src/readdatafromexcel.jl")
include("src/SUCuccommitmentmodel.jl")
include("src/casesploting.jl")
include("src/saveresult.jl")
include("src/generatefittingparameters.jl")
include("src/draw_onlineactivepowerbalance.jl")
include("src/draw_addditionalpower.jl")

# Destructure directly from function call for clarity
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad = readxlssheet()
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData
)

winds, NW = genscenario(WindsFreqParam, 1)

boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges)

bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻ = SUC_scucmodel(
	NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)

savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)
