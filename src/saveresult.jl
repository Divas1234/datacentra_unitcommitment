function save_UCresults(x₀, bench_x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻,
	bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻, NT, NG, ND, NW, units, winds)
	# filepath = pwd()
	return save("D:/ieee_tpws/code/littlecase//output/bench/" * "mydata_1.jld",
		"x₀", x₀,
		"p₀", p₀,
		"pᵨ", pᵨ,
		"pᵩ", pᵩ,
		"seq_sr⁺", seq_sr⁺,
		"seq_sr⁻", seq_sr⁻,
		"pss_charge_p⁺", pss_charge_p⁺,
		"pss_charge_p⁻", pss_charge_p⁻,
		"su_cost", su_cost,
		"sd_cost", sd_cost,
		"prod_cost", prod_cost,
		"cost_sr⁺", cost_sr⁺,
		"cost_sr⁻", cost_sr⁻,
		"NT", NT,
		"NG", NG,
		"ND", ND,
		"NW", NW,
		"winds", winds,
		"units", units,
		"bench_x₀", bench_x₀,
		"bench_p₀", bench_p₀,
		"bench_pᵨ", bench_pᵨ,
		"bench_pᵩ", bench_pᵩ,
		"bench_seq_sr⁺", bench_seq_sr⁺,
		"bench_seq_sr⁻", bench_seq_sr⁻,
		"bench_pss_charge_p⁺", bench_pss_charge_p⁺,
		"bench_pss_charge_p⁻", bench_pss_charge_p⁻,
		"bench_su_cost", bench_su_cost,
		"bench_sd_cost", bench_sd_cost,
		"bench_prod_cost", bench_prod_cost,
		"bench_cost_sr⁺", bench_cost_sr⁺,
		"bench_cost_sr⁻", bench_cost_sr⁻)
end

function read_UCresults()
	filepath = pwd()
	jldopen("D:/ieee_tpws/code/littlecase//output/pros/" * "mydata_1.jld", "w") do file
		write(file, "x₀", x₀)
		write(file, "bench_x₀", bench_x₀)
		write(file, "p₀", p₀)
		write(file, "pᵨ", pᵨ)
		write(file, "pᵩ", pᵩ)
		write(file, "seq_sr⁺", seq_sr⁺)
		write(file, "seq_sr⁻", seq_sr⁻)
		write(file, "pss_charge_p⁺", pss_charge_p⁺)
		write(file, "pss_charge_p⁻", pss_charge_p⁻)
		write(file, "su_cost", su_cost)
		write(file, "sd_cost", sd_cost)
		write(file, "prod_cost", prod_cost)
		write(file, "cost_sr⁺", cost_sr⁺)
		write(file, "cost_sr⁻", cost_sr⁻)
		write(file, "NT", NT)
		write(file, "NG", NG)
		write(file, "ND", ND)
		write(file, "NW", NW)
		write(file, "winds", winds)
		write(file, "units", units)
		write(file, "bench_p₀", bench_p₀)
		write(file, "bench_pᵨ", bench_pᵨ)
		write(file, "bench_pᵩ", bench_pᵩ)
		write(file, "bench_seq_sr⁺", bench_seq_sr⁺)
		write(file, "bench_seq_sr⁻", bench_seq_sr⁻)
		write(file, "bench_pss_charge_p⁺", bench_pss_charge_p⁺)
		write(file, "bench_pss_charge_p⁻", bench_pss_charge_p⁻)
		write(file, "bench_su_cost", bench_su_cost)
		write(file, "bench_sd_cost", bench_sd_cost)
		write(file, "bench_prod_cost", bench_prod_cost)
		write(file, "bench_cost_sr⁺", bench_cost_sr⁺)
		return write(file, "bench_cost_sr⁻", bench_cost_sr⁻)
	end
	return x₀, bench_x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺,
	bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻, NT, NG, ND, NW, units, winds
end

function savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, flag)
	# @show DataFrame(bench_p₀[1:3,:],:auto)
	thermalunits_output = zeros(24, 1)
	for i in 1:24
		thermalunits_output[i, 1] = sum(bench_p₀[1:3, i])
	end
	# Plots.plot(thermalunits_output)
	# @show DataFrame(bench_pᵩ[1:3,:],:auto)
	windunits_output = zeros(24, 1)
	for i in 1:24
		windunits_output[i, 1] = sum(winds.p_max) * winds.scenarios_curve[1, i] - sum(bench_pᵩ[1:2, i])
	end
	# Plots.plot(windunits_output)
	forceloadcurtailment = zeros(24, 1)
	for i in 1:24
		forceloadcurtailment[i, 1] = sum(bench_pᵨ[1:ND, i])
	end
	# Plots.plot(forceloadcurtailment)
	# @show bench_pss_charge_p⁺[1,:]
	BESScharging_output, BESSdischarging_output = zeros(24, 1), zeros(24, 1)
	for i in 1:24
		BESScharging_output[i, 1] = sum(bench_pss_charge_p⁺[1, i])
	end
	for i in 1:24
		BESSdischarging_output[i, 1] = sum(bench_pss_charge_p⁻[1, i])
	end
	# Plots.plot(-bench_pss_charge_p⁺[1,:])
	# Plots.plot!(bench_pss_charge_p⁻[1,:])

	filepath = pwd()
	if flag == 1
		filepath = "D:/GithubClonefiles/datacentre_unitcommitment/output/bench/"
	elseif flag == 2
		filepath = "D:/GithubClonefiles/datacentre_unitcommitment/output/"
	else
		flag == 3
		filepath = "D:/ieee_tpws/code/littlecase//output/enhance_pros/"
	end
	open(filepath * "res_thermalunits.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, thermalunits_output, '\t')
	end
	open(filepath * "res_windunits.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, windunits_output, '\t')
	end
	open(filepath * "res_forcedloadcurtailment.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, forceloadcurtailment, '\t')
	end
	open(filepath * "res_BESS_charging.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, BESScharging_output, '\t')
	end
	open(filepath * "res_BESS_discharging.txt", "w") do io
		# writedlm(io, [" "])
		writedlm(io, BESSdischarging_output, '\t')
	end
end
