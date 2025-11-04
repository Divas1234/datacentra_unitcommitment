include("callback.jl")
include("src/environment_config.jl")

is_display_uc_boundarycondtion = false
NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param = get_uc_boundaryconditions(is_display_uc_boundarycondtion);

workload_dis = DataCentras.computational_power_tasks;
figure_type="evenvelope"
@show p = draw_workload_envelope(NT, ND2, workload_dis, figure_type);

#  NOTE - MODEL 1
#! Run the SUC-SCUC model (considering data centra)
config_param.is_ConsiderDataCentra = 1
res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)

dc_p_p1, dc_p_p2, dc_p_p3, dc_p_p4, dc_p_p5,
dc_fv²_p1, dc_fv²_p2, dc_fv²_p3, dc_fv²_p4, dc_fv²_p5,
dc_fv²λ_p1, dc_fv²λ_p2, dc_fv²λ_p3, dc_fv²λ_p4, dc_fv²λ_p5 = draw_dcc_power_dvfs_subfigures(res)

# prepare lists (pad where needed). keep consistent layout (3 x 2)
plots_power = [p, dc_p_p1, dc_p_p2, dc_p_p3, dc_p_p4, dc_p_p5]
plots_fv2   = [dc_fv²_p1, dc_fv²_p2, dc_fv²_p3, dc_fv²_p4, dc_fv²_p5]       # will be padded by helper
plots_fv2λ = [dc_fv²λ_p1, dc_fv²λ_p2, dc_fv²λ_p3, dc_fv²λ_p4, dc_fv²λ_p5]

# save with clear filenames and larger size for readability
y1 = combine_and_save(plots_power, "./fig/res_dcc_power_plots.pdf"; layout = (3, 2), size = (800, 800))
y2 = combine_and_save(plots_fv2, "./fig/res_dcc_fv2_plots.pdf"; layout = (3, 2), size = (1000, 1000))
y3 = combine_and_save(plots_fv2λ, "./fig/res_dcc_fv2lambda_plots.pdf"; layout = (3, 2), size = (1000, 1000))
@info "Saved DCC power and DVFS plots to ./fig/"

rut = @timed res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)
@show "runtime = $(rut.time) s"
@show "CPU memory = $(rut.bytes / 1028 / 1028) MiB"
# @show "result = $(rut.value)"

res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)
#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 2)

# NOTE - MODEL 2
#! Run the benchmark model (without considering data centra)
config_param.is_ConsiderDataCentra = 0
rut = @timed res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)
@show "runtime = $(rut.time) s"
@show "CPU memory = $(rut.bytes / 1028 / 1028) MiB"

res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)

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

