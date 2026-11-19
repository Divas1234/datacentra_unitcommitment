# =============================================================================
# visualization.jl — Plotting functions
# =============================================================================

using Plots, LaTeXStrings, StatsPlots, PlotThemes

"""
	draw_workload_envelope(NT, ND2, workload, fig_type)

Plot workload curves with envelope shading.
Supported `fig_type`: "envelope", "simple_fv²", "simple_fv²λ"
"""
function draw_workload_envelope(NT, ND2, workload, fig_type)
	theme(:vibrant)
	t = 1:NT

	if fig_type == "envelope"
		p = plot(t, workload[:, 1];
			xlims=(0,25), ylims=(0,0.25), legend=:topright,
			xlabel=L"t\ (h)", ylabel=L"p (p.u.)", label="DCC 1",
			grid=:y, framestyle=:box, alpha=1.0, lw=3,
			legend_background_alpha=0.0)
		for i in 2:ND2
			plot!(t, workload[:, i]; label="DCC $i", alpha=1.0, lw=3)
		end

		# Envelope for Type 1 (cols 2,5,8,...)
		sel_cols = collect(2:3:size(workload,2))
		if !isempty(sel_cols)
			sel = workload[:, sel_cols]
			env_max, env_min = vec(maximum(sel, dims=2)), vec(minimum(sel, dims=2))
			plot!(t, env_max; fillrange=env_min, color=:green, fillalpha=0.25, label="Type 1", lw=0)
			plot!(t, env_max; color=:blue, lw=1, marker=:circle, markersize=4, label="")
			plot!(t, env_min; color=:blue, lw=1, marker=:circle, markersize=4, label="")
		end

		# Envelope for remaining cols
		not_sel = setdiff(collect(1:size(workload,2)), sel_cols)
		if !isempty(not_sel)
			sel = workload[:, not_sel]
			env_max, env_min = vec(maximum(sel, dims=2)), vec(minimum(sel, dims=2))
			plot!(t, env_max; fillrange=env_min, color=:red, fillalpha=0.15, label="Type 2", lw=0)
			plot!(t, env_max; color=:blue, lw=1, marker=:circle, markersize=4, label="")
			plot!(t, env_min; color=:blue, lw=1, marker=:circle, markersize=4, label="")
		end
	elseif fig_type == "simple_fv²"
		markers = [:circle,:square,:diamond,:star5,:utriangle,:dtriangle,:cross,:xcross,:hexagon,:pentagon]
		colors  = [:blue,:red,:green,:orange,:purple,:brown,:pink,:gray,:cyan,:magenta]

		p = plot(t, workload[:, 1];
			seriestype=:line, ylims=(0.23,0.28), xlims=(0,25),
			legend=:topright, xlabel=L"t\ (h)", ylabel=L"fv^{2} (p.u.)",
			label="DCC 1", color=colors[1], marker=markers[1],
			markersize=6, markerstrokecolor=:black, markerstrokewidth=0.6,
			lw=2.5, grid=:y, framestyle=:box, background_color=:white,
			legend_background_alpha=0.0, legendfontsize=9,
			tickfontsize=8, guidefontsize=10)
		for i in 2:ND2
			idx = mod1(i-1, length(markers)) + 1
			plot!(t, workload[:, i];
				seriestype=:line, label="DCC $i", color=colors[idx],
				marker=markers[idx], markersize=6, markerstrokecolor=:black,
				markerstrokewidth=0.6, lw=2.0, alpha=0.95)
		end
	elseif fig_type == "simple_fv²λ"
		p = plot(t, workload[:, 1];
			seriestype=:line, xlims=(0,25), legend=:topright,
			xlabel=L"t\ (h)", ylabel=L"fv^{2} \times \lambda (p.u.)",
			label="DCC 1", grid=:y, framestyle=:box, alpha=0.95, lw=3,
			legend_background_alpha=0.0)
		for i in 2:ND2
			plot!(t, workload[:, i];
				seriestype=:line, label="DCC $i", alpha=0.95, lw=3)
		end
	else
		p = plot(title="Unknown figure type: $fig_type")
	end
	return p
end

"""
	draw_dcc_subfigures(res)

Split DCC result columns into chunks for subplotting.
Returns (p1..p5, fv2_p1..fv2_p5, fv2λ_p1..fv2λ_p5)
"""
function draw_dcc_subfigures(res; chunk=8, maxplots=5)
	function _chunk_plots(data, fig_type="envelope")
		ncols = size(data, 2)
		plots = Vector{Any}(undef, maxplots)
		for i in 1:maxplots
			s = (i-1)*chunk + 1
			e = min(i*chunk, ncols)
			if s <= ncols
				plots[i] = draw_workload_envelope(size(data,1), 0, data[:, s:e], fig_type)
			else
				plots[i] = plot()
			end
		end
		return plots
	end

	dc_p = try
		transpose(res["dc_p"])
	catch; error("dc_p missing"); end

	dc_fv² = try
		transpose(res["dc_fv2"])
	catch; error("dc_fv² missing"); end

	dc_fv²λ = try
		transpose(res["dc_fv2_lambda"])
	catch; error("dc_fv²λ missing"); end

	p_plots   = _chunk_plots(dc_p, "envelope")
	fv2_plots = _chunk_plots(dc_fv², "simple_fv²")
	fv2λ_plots = _chunk_plots(dc_fv²λ, "simple_fv²λ")

	return (p_plots..., fv2_plots..., fv2λ_plots...)
end

"""
	combine_and_save(plots, filename; layout, size)

Combine multiple plots into one figure and save to file.
"""
function combine_and_save(plots::AbstractVector, filename::AbstractString;
                          layout=(3,2), size=(900,1200))
	mkpath(dirname(filename))
	nslots = prod(layout)
	objs = copy(plots)
	while length(objs) < nslots
		push!(objs, plot())
	end
	combined = plot(objs...; layout=layout, size=size)
	try
		savefig(combined, filename)
	catch e
		@warn "Failed to save plot: $filename — $e"
	end
	return combined
end

"""
	draw_power_balance(x₀, p₀, pᵨ, pᵩ, sr⁺, sr⁻, pc⁺, pc⁻, wind, load,
	                   NG, ND, NW, NC, NT, scenario)

Plot the power balance stacking chart for a given scenario.
"""
function draw_power_balance(p₀, pᵨ, pᵩ, pc⁺, pc⁻, wind::Wind, load::Load,
                            NG, ND, NW, NC, NT, scenario)
	sel = (idx) -> (s) -> idx[(s-1)*scenario .+ (1:scenario), :]

	gen_out   = p₀[(NG*(scenario-1)+1):(NG*scenario), :]
	wind_mppt = zeros(NW, NT)
	for w in 1:NW
		wind_mppt[w, :] = wind.curve[w, :] * wind.p_max[w]
	end
	wind_out  = wind_mppt .- pᵩ[(NW*(scenario-1)+1):(NW*scenario), :]
	load_curt = pᵨ[(ND*(scenario-1)+1):(ND*scenario), :]
	bess_dis  = pc⁻[(NC*(scenario-1)+1):(NC*scenario), :]
	bess_ch   = pc⁺[(NC*(scenario-1)+1):(NC*scenario), :]

	sum_gen  = vec(sum(gen_out, dims=1))
	sum_wind = vec(sum(wind_out, dims=1))
	sum_curt = vec(sum(load_curt, dims=1))
	sum_bdis = vec(sum(bess_dis, dims=1))
	sum_bch  = vec(sum(bess_ch, dims=1))

	x = 1:NT
	zero_line = zeros(NT)

	p = plot(x, zero_line;
		fillrange=sum_gen, size=(250,280),
		xlabel=L"t / h", ylabel=L"Output (p.u.)",
		framestyle=:box, foreground_color_grid=:grey,
		background_color_inside=:transparent, grid=:true,
		lw=0.5, lc=:red, ls=:dash, xlims=(0,25), ylims=(-1,6.6),
		legend=:topright,
		c=RGB(159/255,66/255,64/255), label=L"Conventional units")

	plot!(x, sum_gen;
		fillrange=sum_gen .+ sum_wind, fillalpha=0.95, lw=0.5, ls=:dash,
		lc=:blue, c=RGB(94/255,133/255,149/255), label=L"Wind farms")
	plot!(x, sum_gen .+ sum_wind;
		fillrange=sum_gen .+ sum_wind .+ sum_bdis, fillalpha=0.95,
		lc=:blue, ls=:dash, lw=0.5,
		c=RGB(137/255,176/255,81/255), label=L"BESS (discharge)")
	plot!(x, sum_gen .+ sum_wind .+ sum_bdis .+ sum_curt;
		fillrange=sum_gen .+ sum_wind .+ sum_bdis .+ sum_curt, fillalpha=0.95,
		ls=:dash, lw=0.5, lc=:blue,
		c=RGB(251/255,234/255,90/255), label=L"Load shedding")
	plot!(x, zero_line;
		fillrange=-sum_bch, fillalpha=0.95,
		c=RGB(49/255,163/255,84/255), label=L"BESS (charge)")
	plot!(x, -sum_bch; ls=:dash, lw=0.5, lc=:blue, label="")

	return p
end

"""
	plot_case_studies(p₀, pᵨ, pᵩ, sr⁺, sr⁻, su_cost, sd_cost,
	                  prod_cost, cr⁺, cr⁻, NT, NG, ND, NW, NC)

Generate PlotlyJS case study figures: power balance, cost bar, reserve lines.
"""
function plot_case_studies(p₀, pᵨ, pᵩ, sr⁺, sr⁻, su_cost, sd_cost,
                           prod_cost, cr⁺, cr⁻, NT, NG, ND, NW, NC, wind::Wind)
	HAS_PLOTLYJS[] || error("PlotlyJS is not available; install Blink/Electron or skip plot_case_studies")
	fig1 = _area_plot(p₀, pᵨ, pᵩ, NT, NG, ND, NW, NC, wind)
	fig2 = _cost_bar(su_cost, sd_cost, prod_cost, cr⁺, cr⁻)
	fig3 = _reserve_line(sr⁺, "sr⁺", NT)
	fig4 = _reserve_line(sr⁻, "sr⁻", NT)
	return [fig1 fig2; fig3 fig4]
end

function _area_plot(p₀, pᵨ, pᵩ, NT, NG, ND, NW, NC, wind::Wind)
	y1 = sum(p₀[1:NG, :], dims=1)[:]
	# wind.curve is NS × NT; use scenario 1 capacity factor for each farm
	y2 = zeros(NW, NT)
	for i in 1:NW
		y2[i, :] = wind.curve[1, 1:NT] .* wind.p_max[i] .- pᵩ[i, 1:NT]
	end
	y2 = sum(y2, dims=1)[:]
	y6 = sum(pᵨ[1:ND, :], dims=1)[:]

	s0 = -y6
	s3 = y1
	s4 = s3 + y2

	t1 = PlotlyJS.scatter(; x=1:NT, y=s0, fill="tozeroy", mode="none")
	t4 = PlotlyJS.scatter(; x=1:NT, y=s3, fill="tonextx", mode="none")
	t5 = PlotlyJS.scatter(; x=1:NT, y=s4, fill="tonexty", mode="none")
	return PlotlyJS.plot([t1, t4, t5], PlotlyJS.Layout(title="Power Balance"))
end

function _cost_bar(su_cost, sd_cost, prod_cost, cr⁺, cr⁻)
	labels = ["su_cost", "sd_cost", "prod_cost", "sr_cost_+", "sr_cost_-"]
	values = [su_cost, sd_cost, prod_cost/10, cr⁺*10, cr⁻*10]
	bar = PlotlyJS.bar(; x=labels, y=values)
	return PlotlyJS.plot(bar, PlotlyJS.Layout(title="Cost Summary"))
end

function _reserve_line(sr, label, NT)
	trace = PlotlyJS.scatter(; x=1:NT, y=vec(sum(sr, dims=1)), mode="lines+markers")
	return PlotlyJS.plot([trace], PlotlyJS.Layout(title=label))
end

"""
	draw_additional_power(units, winds, sampling, bess, δf)

Calculate additional power from frequency response and plot.
"""
function draw_additional_power(units::Unit, winds::Wind, sampling, bess, δf)
	Kg, Rg, Kw, Rw, Dw = _calc_dynamic_params(units, winds, sampling, 1)
	Rc = 0.5

	total_conv = sum(units.p_max)
	total_wind = sum(winds.p_max)
	r1 = total_conv / (total_conv + total_wind)
	r2 = total_wind / (total_conv + total_wind)

	N = length(δf)
	conv_power = zeros(N)
	wind_power = zeros(N)
	bess_power = zeros(N)

	for t in 1:N
		conv_power[t] = 0.5 * Kg / Rg * δf[t] * r1 / 100 * 2
		wind_power[t] = Kw / Rw * δf[t] * r2 / 100 * 2
		bess_power[t] = 0.5 * 1 / Rc * δf[t] / 100 * 2
	end

	return conv_power, wind_power, bess_power
end

function _calc_dynamic_params(units, winds, sampling, flag)
	return 1.0, 1.0, 1.0, 1.0, 1.0  # Placeholder — implement actual calculation
end

function plot_additional_power(conv_proposed, wind_proposed, bess_proposed,
                               conv_enhanced, wind_enhanced, bess_enhanced)
	t = collect(0:0.05:30)
	N = 601
	p = plot(t, conv_proposed[1:N] .+ wind_proposed[1:N] .+ bess_proposed[1:N];
		xlims=(0,30), ylims=(0,0.35), size=(300,300),
		xlabel=L"t / s", ylabel=L"Output (p.u.)",
		label="FDUC", framestyle=:box, foreground_color_grid=:grey,
		lw=3, lc=:orange, la=0.75, grid=:true,
		xticks=(0:10:30, 0:10:30))
	plot!(t, conv_enhanced[1:1201] .+ wind_enhanced[1:1201] .+ bess_enhanced[1:1201];
		label="CCFDUC", la=0.5, lc=:blue, lw=3)
	return p
end
