# =============================================================================
# output.jl — Result saving utilities
# =============================================================================

"""
	save_balance_result(p₀, pᵨ, pᵩ, pc⁺, pc⁻, wind, NG, NW, NC, flag)

Compute and save thermal/wind/load/BESS balance results to text files.
Uses scenario-1 blocks. `flag=1` → bench/, `flag=2` → pros/, `flag=3` → output/.
"""
function save_balance_result(p₀, pᵨ, pᵩ, pc⁺, pc⁻, wind::Wind, NG, NW, NC, flag)
	NT = size(p₀, 2)

	# Scenario-1 slices
	thermal = [sum(p₀[1:NG, i]) for i in 1:NT]
	wind_total = [sum(wind.p_max) * wind.curve[1, i] - sum(pᵩ[1:NW, i]) for i in 1:NT]
	load_curt = [sum(pᵨ[:, i]) for i in 1:NT]
	bess_ch = [sum(pc⁺[1:NC, i]) for i in 1:NT]
	bess_dis = [sum(pc⁻[1:NC, i]) for i in 1:NT]

	dir_map = Dict(
		1 => joinpath(output_dir(), "bench"),
		2 => joinpath(output_dir(), "pros"),
		3 => output_dir()
	)
	base_dir = get(dir_map, flag, output_dir())

	out = [
		("res_thermalunits.txt", thermal),
		("res_windunits.txt", wind_total),
		("res_forcedloadcurtailment.txt", load_curt),
		("res_BESS_charging.txt", bess_ch),
		("res_BESS_discharging.txt", bess_dis),
	]
	for (fname, data) in out
		fpath = joinpath(base_dir, fname)
		mkpath(dirname(fpath))
		open(fpath, "w") do io
			writedlm(io, data, '\t')
		end
	end
	println("Balance results saved to: $base_dir")
end

"""
	save_data_center_csv(results, out_dir, ND2, NT, num_sos)

Save data-center-specific results (dc_p, dc_fv², dc_λ, etc.) as CSV files.
"""
function save_data_center_csv(results, out_dir, ND2, NT, num_sos)
	pairs = [
		("dc_p.csv",              results["dc_p"][1:ND2, 1:NT]),
		("dc_fv².csv",            results["dc_fv2"][1:ND2, 1:NT]),
		("dc_fv²λ.csv",           results["dc_fv2_lambda"][1:ND2, 1:NT]),
		("dc_λ.csv",              results["dc_fv2_lambda"][1:ND2, 1:NT] ./ results["dc_fv2"][1:ND2, 1:NT]),
		("dc_fv²_plus.csv",       results["dc_fv2_plus"][1:ND2, 1:NT]),
		("dc_fv²_minus.csv",      results["dc_fv2_minus"][1:ND2, 1:NT]),
		("dc_fv²λ_plus.csv",      results["dc_fv2_lambda_plus"][1:ND2, 1:NT]),
		("dc_fv²λ_minus.csv",     results["dc_fv2_lambda_minus"][1:ND2, 1:NT]),
		("dc_fv²_2_plus.csv",     results["dc_fv2_2_plus"][1:ND2, 1:NT]),
		("dc_fv²_2_minus.csv",    results["dc_fv2_2_minus"][1:ND2, 1:NT]),
		("dc_fv²λ_2_plus.csv",    results["dc_fv2_lambda_2_plus"][1:ND2, 1:NT]),
		("dc_fv²λ_2_minus.csv",   results["dc_fv2_lambda_2_minus"][1:ND2, 1:NT]),
	]
	for (fname, data) in pairs
		fpath = joinpath(out_dir, fname)
		mkpath(dirname(fpath))
		try
			CSV.write(fpath, DataFrame(data, :auto))
			println("  → wrote $fpath")
		catch e
			@error "Failed to write $fpath" exception=(e, catch_backtrace())
		end
	end
end

"""
	save_uc_jld(...) — Save full UC results to JLD (deprecated, kept for compat)
"""
function save_uc_jld(x₀, bench_x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻,
                     pc⁺, pc⁻, su_cost, sd_cost, prod_cost, cr⁺, cr⁻,
                     bench_p₀, bench_pᵨ, bench_pᵩ, bench_sr⁺, bench_sr⁻,
                     bench_pc⁺, bench_pc⁻, bench_su, bench_sd, bench_prod,
                     bench_cr⁺, bench_cr⁻, NT, NG, ND, NW, unit, wind)
	_ensure_jld!()
	save(joinpath(output_dir(), "mydata.jld"),
		"x₀", x₀, "p₀", p₀, "pᵨ", pᵨ, "pᵩ", pᵩ,
		"seq_sr⁺", seq_sr⁺, "seq_sr⁻", seq_sr⁻,
		"pss_charge_p⁺", pc⁺, "pss_charge_p⁻", pc⁻,
		"su_cost", su_cost, "sd_cost", sd_cost,
		"prod_cost", prod_cost, "cost_sr⁺", cr⁺, "cost_sr⁻", cr⁻,
		"NT", NT, "NG", NG, "ND", ND, "NW", NW,
		"winds", wind, "units", unit,
		"bench_x₀", bench_x₀, "bench_p₀", bench_p₀,
		"bench_pᵨ", bench_pᵨ, "bench_pᵩ", bench_pᵩ,
		"bench_seq_sr⁺", bench_sr⁺, "bench_seq_sr⁻", bench_sr⁻,
		"bench_pss_charge_p⁺", bench_pc⁺, "bench_pss_charge_p⁻", bench_pc⁻,
		"bench_su_cost", bench_su, "bench_sd_cost", bench_sd,
		"bench_prod_cost", bench_prod, "bench_cost_sr⁺", bench_cr⁺,
		"bench_cost_sr⁻", bench_cr⁻)
end
