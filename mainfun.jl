using Pkg

using BenchmarkTools

# @benchmark sort(data) setup=(data=rand(10))

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

#? Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data, data_centra_jobcurve = readxlssheet()

#? Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2,DataCentras = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data, data_centra_jobcurve)

#? Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 2)

output_dir = pwd()
filepath = joinpath(output_dir, "output\\bench", "windsimulation_curve.csv")
try
    CSV.write(filepath, DataFrame(winds.scenarios_curve, :auto))
    println("Successfully wrote to $filepath")
catch e
    @error "Failed to write to $filepath" exception = (e, catch_backtrace())
end

@assert config_param.is_ConsiderDataCentra == 1

#? Apply boundary conditions
boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges)

#! Run the SUC-SCUC model (considering data centra)
@benchmark res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param)

#! Run the benchmark model (without considering data centra)
config_param.is_ConsiderDataCentra = 0
@benchmark res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param)

#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 1)

# using Plots, PlotThemes
# p1 = Plots.plot(LoadCurve[:, 2]; label = "Load", legend = :topleft)
# Plots.savefig(p1, "./fig/load.pdf")

# # export_data(LoadCurve, 1)
# function export_data(LoadCurve, flag)
# 	if flag == 1
# 		filepath = "D:/GithubClonefiles/datacentra_unitcommitment/output/bench/"
# 	elseif flag == 2
# 		filepath = "D:/GithubClonefiles/datacentre_unitcommitment/output/"
# 	else
# 		flag == 3
# 		filepath = "D:/ieee_tpws/code/littlecase//output/enhance_pros/"
# 	end

# 	open(filepath * "LoadCurve.txt", "w") do io
# 		# writedlm(io, [" "])
# 		return writedlm(io, LoadCurve, '\t')
# 	end
# end

run_r_visualizations()
