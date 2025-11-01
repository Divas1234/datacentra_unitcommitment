function get_uc_boundaryconditions(is_display_uc_boundarycondtion)

	#? Read data from Excel sheet
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data, data_centra_jobcurve = readxlssheet()

	#? Form input data for the model
	config_param, units, lines, loads, ess, NB, NG, NL, ND, NT, NC, ND2,
	DataCentras = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data, data_centra_jobcurve)

	#? Generate wind scenarios
	winds, NW = genscenario(WindsFreqParam, 2)

	output_dir = pwd()
	filepath   = joinpath(output_dir, "output/bench", "windsimulation_curve.csv")
	try
		if !isdir(dirname(filepath))
			mkdir(dirname(filepath))
		end
		CSV.write(filepath, DataFrame(winds.scenarios_curve, :auto))
		println("Successfully wrote to $filepath")
	catch e
		@error "Failed to write to $filepath" exception = (e, catch_backtrace())
	end
	@assert config_param.is_ConsiderDataCentra == 1

	#? Apply boundary conditions
	if is_display_uc_boundarycondtion
		boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, ess)
	end

	return NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, ess, DataCentras, config_param
end

