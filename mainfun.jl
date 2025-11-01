include("callback.jl")
include("src/environment_config.jl")

is_display_uc_boundarycondtion = false
NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param = get_uc_boundaryconditions(is_display_uc_boundarycondtion);

DataCentras.computational_power_tasks



# NOTE - MODEL 1
#! Run the SUC-SCUC model (considering data centra)
config_param.is_ConsiderDataCentra = 1
@benchmark res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)

#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 2)

# tem = res["dc_fv²"]
# Plots.plot(tem[:, 5]; label = "DC FV²", legend = nothing)
# tem = res["dc_p"]
# Plots.plot(tem[5, :]; label = "DC P", legend = nothing)

# NOTE - MODEL 2
#! Run the benchmark model (without considering data centra)
config_param.is_ConsiderDataCentra = 0
@benchmark res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)

#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 1)

#NOTE - data visualization
# using Plots, PlotThemes
# p1 = Plots.plot(LoadCurve[:, 2]; label = "Load", legend = :topleft)
# Plots.savefig(p1, "./fig/load.pdf")

# # export_data(LoadCurve, 1)
# function export_data(LoadCurve, flag)
# 	if flag == 1j
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

