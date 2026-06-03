include("callback.jl")
include("src/environment_config.jl")

# ===== 段落1：环境与边界条件初始化 =====
# 读取系统规模、设备参数与配置项，作为后续模型求解的统一输入。
is_display_uc_boundarycondtion = false
# NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param = get_uc_boundaryconditions(is_display_uc_boundarycondtion);
NT, NB, NG, ND, NC, ND2, NM, units, loads, winds, lines, ess, DataCentras, config_param, data_centra_jobcurve, mg_bus_map, tie_lines = get_uc_boundaryconditions(is_display_uc_boundarycondtion);

@show Int64.(mg_bus_map)'
# @show tie_lines
index_microgrid_bus = Int64.(mg_bus_map)'

# ===== 段落2：工作负载包络图绘制 =====
# 先绘制数据中心工作负载分布，用于结果展示与后续子图拼接。
workload_dis = DataCentras.computational_power_tasks;
figure_type="evenvelope"
@show p = draw_workload_envelope(NT, ND2, workload_dis, figure_type);

index_microgrid_bus
# DEBUG - for each microgrid operations.
vec_tem = zeros(NM, NB)
for n in 1:NM
	filtered_index_each_mirocgrid = findall(x->x==n, index_microgrid_bus[n, :][1, :])
	vec_tem(n, filtered_index_each_mirocgrid) .== 1
end

index_microgrid_bus[2, :][:, 1]
vec_tem[1, findall(x->x == 1, index_microgrid_bus[2, :][:, 1])] .== 1

#  NOTE - MODEL 1
#! Run the SUC-SCUC model (considering data centra)
NM
# ===== 段落3：模型1（考虑数据中心）求解 =====
config_param.is_ConsiderDataCentra = 1
res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, NM, units, loads, winds, lines, ess, DataCentras, config_param, index_microgrid_bus)
# ===== 段落4：模型1关键变量导出（CSV） =====
# 导出 dc_fv² 与 dc_fv²λ，便于外部分析与复现实验。
#save results as csv files.
# save res["dc_fv²"] as CSV
filepath_dc_fv = "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\dc_fv.csv"
filepath_dc_fv²λ = "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\dc_fv_lambda.csv"
mkpath(dirname(filepath_dc_fv))
mkpath(dirname(filepath_dc_fv²λ))
try
	using DelimitedFiles
	dc_fv_data = res["dc_fv²"]
	dc_fv_lambda_data = res["dc_fv²λ"]
	# coerce to a plain matrix if possible
	mat = try
		Array(dc_fv_data)
	catch
		collect(dc_fv_data)
	end
	writedlm(filepath_dc_fv, mat, ',')

	mat = try
		Array(dc_fv_lambda_data)
	catch
		collect(dc_fv_lambda_data)
	end
	writedlm(filepath_dc_fv²λ, mat, ',')
catch err
	@warn "Failed to save res[\"dc_fv²\"] or res[\"dc_fv²λ\"] to CSV: $err"
end

# ===== 段落5：模型1结果可视化与子图拼接 =====
# 分别绘制功率、fv²、fv²λ，并按统一布局保存为 PDF。
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

# ===== 段落6：模型1性能统计与平衡结果保存 =====
# 统计运行时间/内存，并保存功率平衡相关结果。
rut = @timed res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)
@show "runtime = $(rut.time) s"
@show "CPU memory = $(rut.bytes / 1028 / 1028) MiB"
# @show "result = $(rut.value)"

res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, NW, units, loads, winds, lines, ess, DataCentras, config_param)
#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 2)

# NOTE - MODEL 2
#! Run the benchmark model (without considering data centra)
# ===== 段落7：模型2（不考虑数据中心）基准求解 =====
# 与模型1形成对照，用于性能与调度效果比较。
config_param.is_ConsiderDataCentra = 0
rut = @timed res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)
@show "runtime = $(rut.time) s"
@show "CPU memory = $(rut.bytes / 1028 / 1028) MiB"

res = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param)

#? Save the balance results
savebalance_result(res["p₀"], res["pᵨ"], res["pᵩ"], res["pss_charge_p⁺"], res["pss_charge_p⁻"], 1)

# ===== 段落8：历史可视化草稿（保留注释代码） =====
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

# ===== 段落9：调用 R 脚本进行最终可视化 =====
run_r_visualizations()
