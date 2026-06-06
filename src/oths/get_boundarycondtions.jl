function get_uc_boundaryconditions(is_display_uc_boundarycondtion)

	# 从 Excel 中读取建模所需的原始参数与时序数据
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data, data_centra_jobcurve, mg_bus_map, tie_lines = readxlssheet()

	# 将原始数据整理为统一的模型输入结构与维度信息
	forminput_args = (DataGen, DataBranch, DataLoad, LoadCurve, GenCost,
		UnitsFreqParam, StrogeData, datacentra_Data,
		data_centra_jobcurve, mg_bus_map, tie_lines,)
	config_param, units, lines, loads, ess, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(forminput_args...)

	NM = Int(maximum(mg_bus_map[:, 2]))

	# 生成风电场景（第二个参数通常表示场景级别/模式）
	winds, NW = genscenario(WindsFreqParam, 2)

	# 将风电场景曲线导出到 output/bench 目录，便于调试和结果复现
	output_dir = pwd()
	filepath   = joinpath(output_dir, "output/bench", "windsimulation_curve.csv")
	try
		# 如果目标目录不存在则先创建目录
		if !isdir(dirname(filepath))
			mkdir(dirname(filepath))
		end
		# 以自动列名写出场景曲线数据
		CSV.write(filepath, DataFrame(winds.scenarios_curve, :auto))
		println("Successfully wrote to $filepath")
	catch e
		# 写文件失败时记录异常及堆栈，便于定位问题
		@error "Failed to write to $filepath" exception = (e, catch_backtrace())
	end

	# 当前流程要求开启数据中心模型；否则直接触发断言提醒
	@assert config_param.is_ConsiderDataCentra == 1

	# 根据开关决定是否显示/执行 UC 边界条件处理
	if is_display_uc_boundarycondtion
		boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, ess)
	end

	# 返回模型求解所需的主要对象与维度参数
	return NT, NB, NG, ND, NC, ND2, NM, units, loads, winds, lines, ess, DataCentras, config_param, data_centra_jobcurve, mg_bus_map, tie_lines
end

