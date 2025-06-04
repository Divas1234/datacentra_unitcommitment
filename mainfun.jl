using Pkg

# Activate the project environment
Pkg.activate("./.pkg")
# Include necessary modules
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
include("callback.jl")

# Destructure directly from function call for clarity
# Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

# Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data
)

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1)

# Apply boundary conditions
boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges)

# Run the SUC-SCUC model
bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺,
bench_cost_sr⁻, dc_p, dc_f, dc_v², dc_λ, dc_Δu1, dc_Δu2 = SUC_scucmodel(
	NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param)

# Save the balance results
savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)

# NOTE - data valiation.

using Plots, PlotThemes
p1 = Plots.plot(LoadCurve[:, 2], label = "Load", legend = :topleft)
Plots.savefig(p1, "./fig/load.pdf")

# export_data(LoadCurve, 1)
function export_data(LoadCurve, flag)
	if flag == 1
		filepath = "D:/GithubClonefiles/datacentra_unitcommitment/output/bench/"
	elseif flag == 2
		filepath = "D:/GithubClonefiles/datacentre_unitcommitment/output/"
	else
		flag == 3
		filepath = "D:/ieee_tpws/code/littlecase//output/enhance_pros/"
	end

	open(filepath * "LoadCurve.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, LoadCurve, '\t')
	end
end

run_r_visualizations()