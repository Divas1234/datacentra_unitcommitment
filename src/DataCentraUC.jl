module DataCentraUC

# =============================================================================
# DataCentraUC.jl — Stochastic UC with Data-Center DVFS workloads
#
# Module layout (include order):
#   utils → types → io → wind → linearization → powerflow → dcc
#        → fitting → show_boundary → visualization → output → r_runner
#        → optimization
#
# Usage:
#   using DataCentraUC
#   result_dc, result_bench = run_unit_commitment()
# =============================================================================

using JuMP, Gurobi, DelimitedFiles
using DataFrames, CSV, XLSX
using Distributions
using Printf, Random

# Plotting: load Plots stack once; PlotlyJS remains opt-in (needs Blink)
using Plots, LaTeXStrings, StatsPlots, PlotThemes
const HAS_PLOTLYJS = Ref(false)
if get(ENV, "USE_PLOTLYJS", "0") == "1"
	try
		Base.require(Base.PkgId(Base.UUID("f0f68f2c-4968-5e81-91da-67840de0976a"), "PlotlyJS"))
		HAS_PLOTLYJS[] = true
	catch e
		@warn "PlotlyJS unavailable; continuing without it" exception=e
	end
end

# JLD only when save_uc_jld is called (avoids loading on every run)
function _ensure_jld!()
	@isdefined(JLD) || (@eval using JLD)
	return nothing
end

# Public API
export Config, Unit, TransmissionLine, Load, Storage, Wind, DataCenter
export run_unit_commitment, read_excel_sheets, format_input_data
export draw_workload_envelope, combine_and_save, save_balance_result
export run_r_scripts

# --- Submodules (dependency order) --------------------------------------------
include("utils.jl")             # indexing, paths, Gurobi config, banners
include("types.jl")             # Config / Unit / Load / Storage / Wind / DataCenter
include("io.jl")                # Excel → typed inputs
include("wind.jl")              # wind scenario generation
include("linearization.jl")     # fuel-cost PWL
include("powerflow.jl")         # DC GSDF
include("dcc.jl")               # DCC DVFS + SOS1
include("fitting.jl")           # frequency-response fitting (optional path)
include("show_boundary.jl")     # boundary dump
include("visualization.jl")     # Plots helpers
include("output.jl")            # CSV / balance writers
include("r_runner.jl")          # optional R figures
include("optimization.jl")      # SUC-SCUC MILP

# --- Workflow ------------------------------------------------------------------

"""
	run_unit_commitment(; data_path=nothing, display_boundary=false, out_path=nothing,
	                      run_benchmark=true, run_r=true, make_plots=true)

Full pipeline:
  1. Read Excel  2. Format  3. Wind scenarios
  4. Solve SUC-SCUC with DCC
  5. (optional) plots / balance CSV
  6. (optional) benchmark without DCC
  7. (optional) R visualizations
"""
function run_unit_commitment(; data_path=nothing, display_boundary=false,
                              out_path=nothing,
                              run_benchmark::Bool=true,
                              run_r::Bool=true,
                              make_plots::Bool=true)

	root = project_root()
	fig_out = something(out_path, fig_dir())
	mkpath(fig_out)
	mkpath(output_dir())

	section("DataCentra Unit Commitment — SUC-SCUC")

	# 1–2. Data
	step("Reading Excel inputs")
	path = something(data_path, default_data_path())
	units_freq, winds_freq, storage_data, gen_data, gen_cost,
		branch_data, load_curve, load_data, dc_data, dc_job_curve = read_excel_sheets(path)

	step("Formatting typed inputs")
	config, unit, line, load, storage, NB, NG, NL, ND, NT, NC, ND2, dc =
		format_input_data(gen_data, branch_data, load_data, load_curve,
		                 gen_cost, units_freq, storage_data, dc_data, dc_job_curve)

	# 3. Wind
	step("Generating wind scenarios")
	wind, NW = generate_wind_scenarios(winds_freq, 2)
	wind_path = joinpath(output_dir(), "bench", "windsimulation_curve.csv")
	mkpath(dirname(wind_path))
	try
		CSV.write(wind_path, DataFrame(wind.curve, :auto))
		println("  Wind curve → $wind_path")
	catch e
		@warn "Failed to write wind curve: $e"
	end

	display_boundary && display_boundary_conditions(
		NB, NL, NG, NT, ND, unit, load, line, wind, storage)

	# 4. Main model (with DCC)
	section("MODEL 1: SUC-SCUC with Data Center DVFS")
	config.is_ConsiderDataCentra = 1
	result_dc = run_scuc_model(NT, NB, NG, ND, NC, ND2,
	                           unit, load, wind, line, storage, dc, config)

	dc_csv_dir = joinpath(output_dir(), "data_centra")
	mkpath(dc_csv_dir)
	save_data_center_csv(result_dc, dc_csv_dir, ND2, NT, 5)

	if make_plots
		step("Saving DCC plots")
		p1, p2, p3, p4, p5, fv2_p1, fv2_p2, fv2_p3, fv2_p4, fv2_p5,
			fv2l_p1, fv2l_p2, fv2l_p3, fv2l_p4, fv2l_p5 = draw_dcc_subfigures(result_dc)
		combine_and_save([p1, p2, p3, p4, p5, plot()],
		                 joinpath(fig_out, "res_dcc_power_plots.pdf");
		                 layout=(3, 2), size=(800, 800))
		combine_and_save([fv2_p1, fv2_p2, fv2_p3, fv2_p4, fv2_p5, plot()],
		                 joinpath(fig_out, "res_dcc_fv2_plots.pdf");
		                 layout=(3, 2), size=(1000, 1000))
		combine_and_save([fv2l_p1, fv2l_p2, fv2l_p3, fv2l_p4, fv2l_p5, plot()],
		                 joinpath(fig_out, "res_dcc_fv2lambda_plots.pdf");
		                 layout=(3, 2), size=(1000, 1000))
		@info "DCC plots → $fig_out"
	end

	save_balance_result(result_dc["p0"], result_dc["pd"], result_dc["pw"],
	                    result_dc["pss_charge_p_plus"], result_dc["pss_charge_p_minus"],
	                    wind, NG, NW, NC, 2)

	# 5. Benchmark (no DCC)
	result_bench = nothing
	if run_benchmark
		section("MODEL 2: Benchmark (without Data Centers)")
		config.is_ConsiderDataCentra = 0
		result_bench = run_scuc_model(NT, NB, NG, ND, NC, ND2,
		                              unit, load, wind, line, storage, dc, config)
		save_balance_result(result_bench["p0"], result_bench["pd"], result_bench["pw"],
		                    result_bench["pss_charge_p_plus"], result_bench["pss_charge_p_minus"],
		                    wind, NG, NW, NC, 1)
	end

	# 6. R figures
	if run_r
		section("R visualization scripts")
		run_r_scripts(root)
	end

	section("Workflow complete")
	return result_dc, result_bench
end

end # module
