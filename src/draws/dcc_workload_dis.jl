using Statistics, LaTeXStrings, Plots
function draw_workload_envelope(NT, ND2, workload_dis, figure_type)
	# workload_dis = DataCentras.computational_power_tasks

	# using Statistics, LaTeXStrings, Plots

	Plots.theme(:vibrant)
	# Plots.theme(:default)

	t = 1:NT

	if figure_type == "evenvelope"
		# plot individual DCC traces faintly for context
		p = Plots.plot(t, workload_dis[:, 1]; xlims = (0, 25), ylims = (0, 0.25), legend = :topright, xlabel = L"t\ (h)", ylabel = L"p (p.u.)",
					   label = "DCC 1",
					   grid = :y, framestyle = :box, alpha = 1.0, lw = 3,
					   #    legend_background_color = :transparent,
					   legend_background_alpha = 0.0)
		for i in 2:ND2
			p = Plots.plot!(t, workload_dis[:, i]; label = "DCC $i", alpha = 1.00, lw = 3)
		end
		# compute time-wise envelope (max/min across DCC traces)
		selected_cols = collect(2:3:size(workload_dis, 2))  # 2,5,8,...
		if isempty(selected_cols)
			error("No columns selected. Ensure there are columns at indices 2,5,8,...")
		end

		sel = workload_dis[:, selected_cols]
		env_max = vec(maximum(sel, dims = 2))
		env_min = vec(minimum(sel, dims = 2))

		# draw shaded envelope between min and max (for selected columns)
		p = Plots.plot!(t, env_max; fillrange = env_min, color = :green, fillalpha = 0.25, label = "Type 1", lw = 0)

		# draw boundary lines for the envelope
		p = Plots.plot!(t, env_max; color = :blue, lw = 1, markercolor = :green, markersize = 4, marker = :circle, ls = :solid, label = "")
		p = Plots.plot!(t, env_min; color = :blue, lw = 1, markercolor = :green, markersize = 4, marker = :circle, ls = :solid, label = "")

		# select columns that are NOT in selected_cols
		all_cols = collect(1:size(workload_dis, 2))
		not_selected = setdiff(all_cols, selected_cols)
		sel = workload_dis[:, not_selected]
		env_max = vec(maximum(sel, dims = 2))
		env_min = vec(minimum(sel, dims = 2))

		# draw shaded envelope between min and max (for selected columns)
		p = Plots.plot!(t, env_max; fillrange = env_min, color = :red, fillalpha = 0.15, label = "Type 2", lw = 0)

		# draw boundary lines for the envelope
		p = Plots.plot!(t, env_max; color = :blue, lw = 1, markercolor = :red, markersize = 4, marker = :circle, ls = :solid, label = "")
		p = Plots.plot!(t, env_min; color = :blue, lw = 1, markercolor = :red, markersize = 4, marker = :circle, ls = :solid, label = "")
	end

	if figure_type == "simple_fv²"
		p = Plots.plot(t, workload_dis[:, 1]; seriestype = :line, ylims = (0.23, 0.28), xlims = (0, 25), legend = :topright, xlabel = L"t\ (h)", ylabel = L"fv^{2} (p.u.)",
					   label = "DCC 1",
					   grid = :y,
					   framestyle = :box, alpha = 0.95, lw = 3, marker = :none,
					   #    legend_background_color = :transparent,
					   legend_background_alpha = 0.0)
		for i in 2:ND2
			p = Plots.plot!(t, workload_dis[:, i]; seriestype = :line, label = "DCC $i", alpha = 0.95, lw = 3, marker = :none)
		end
	end

	if figure_type == "simple_fv²λ"
		p = Plots.plot(t, workload_dis[:, 1]; seriestype = :line, xlims = (0, 25), legend = :topright,
					   xlabel = L"t\ (h)", ylabel = L"fv^{2} \times \lambda (p.u.)", label = "DCC 1", grid = :y,
					   framestyle = :box, alpha = 0.95, lw = 3, marker = :none,
					   legend_background_alpha = 0.0)
		for i in 2:ND2
			p = Plots.plot!(t, workload_dis[:, i]; seriestype = :line, label = "DCC $i", alpha = 0.95, lw = 3, marker = :none)
		end
	end

	return p
end

# Robustly create p1..p5 by slicing res["dc_p"] into chunks of 8 columns.
# If there are fewer columns than expected the remaining plots become empty placeholders.
function draw_dcc_power_dvfs_subfigures(res)
	function get_subfigures(dc_p, figure_type = "evenvelope")
		chunk = 8
		maxplots = 5
		ncols = size(dc_p, 2)

		plots = Vector{Any}(undef, maxplots)
		for i in 1:maxplots
			s = (i - 1) * chunk + 1
			e = min(i * chunk, ncols)
			if s <= ncols
				plots[i] = draw_workload_envelope(NT, ND2, dc_p[:, s:e], figure_type)
			else
				# empty placeholder so p1..p5 are always defined
				plots[i] = Plots.plot()
			end
		end
		return plots, ncols, chunk, maxplots
	end

	# get dc_p
	dc_p = try
		transpose(res["dc_p"])
	catch err
		error("res[\"dc_p\"] is missing or not indexable: $err")
	end

	dc_power_plots, dc_power_ncols, dc_power_chunk, dc_power_maxplots = get_subfigures(dc_p)
	dc_p_p1, dc_p_p2, dc_p_p3, dc_p_p4, dc_p_p5 = dc_power_plots
	@show dc_power_ncols, dc_power_chunk, dc_power_maxplots

	# get dc_fv²
	dc_fv² = try
		transpose(res["dc_fv²"])
	catch err
		error("res[\"dc_fv²\"] is missing or not indexable: $err")
	end
	figure_type = "simple_fv²"
	dc_fv²_plots, dc_fv²_ncols, dc_fv²_chunk, dc_fv²_maxplots = get_subfigures(dc_fv², figure_type)
	dc_fv²_p1, dc_fv²_p2, dc_fv²_p3, dc_fv²_p4, dc_fv²_p5 = dc_fv²_plots
	@show dc_fv²_ncols, dc_fv²_chunk, dc_fv²_maxplots

	# get dc_fv²λ
	dc_fv²λ = try
		transpose(res["dc_fv²λ"])
	catch
		error("res[\"dc_fv²λ\"] is missing or not indexable: $err")
	end
	figure_type = "simple_fv²λ"
	dc_fv²λ_plots, dc_fv²λ_ncols, dc_fv²λ_chunk, dc_fv²λ_maxplots = get_subfigures(dc_fv²λ, figure_type)
	dc_fv²λ_p1, dc_fv²λ_p2, dc_fv²λ_p3, dc_fv²λ_p4, dc_fv²λ_p5 = dc_fv²λ_plots
	@show dc_fv²λ_ncols, dc_fv²λ_chunk, dc_fv²λ_maxplots

	return dc_p_p1, dc_p_p2, dc_p_p3, dc_p_p4, dc_p_p5,
		   dc_fv²_p1, dc_fv²_p2, dc_fv²_p3, dc_fv²_p4, dc_fv²_p5,
		   dc_fv²λ_p1, dc_fv²λ_p2, dc_fv²λ_p3, dc_fv²λ_p4, dc_fv²λ_p5
end

# helper: ensure output directory exists, combine exactly layout slots and save safely
function combine_and_save(plot_objs::AbstractVector, outfile::AbstractString; layout = (3, 2), size = (900, 1200))
	mkpath(dirname(outfile))
	nslots = prod(layout)
	objs = copy(plot_objs)
	while length(objs) < nslots
		push!(objs, Plots.plot())   # empty placeholder
	end
	combined = Plots.plot(objs...; layout = layout, size = size)
	try
		Plots.savefig(combined, outfile)
	catch err
		@warn "Failed to save plot to $outfile: $err"
	end
	return combined
end
