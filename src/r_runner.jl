# =============================================================================
# r_runner.jl — R visualization script runner
# =============================================================================

"""
	run_r_scripts(project_root)

Execute all R visualization scripts found in output/data_centra/.
Duplication eliminated — uses a loop over script names.
"""
function run_r_scripts(project_root = joinpath(@__DIR__, ".."))
	scripts = [
		"draw_dc_fv²_subplots.r",
		"draw_dc_fv².r",
		"draw_dc_fv²λ.r",
		"draw_dc_p.r",
		"draw_dc_λ.r",
		"draw_dc_λ_seq.r",
		"draw_dc_fv²λ_subplots.r",
	]
	rscript_cmd = "Rscript"
	script_dir  = joinpath(project_root, "output", "data_centra")

	println("="^60)
	println("Running R visualization scripts from: $script_dir")
	println("="^60)

	for script in scripts
		path = joinpath(script_dir, script)
		if !isfile(path)
			println("  [SKIP] $script — not found")
			continue
		end
		println("  [RUN]  $script")
		try
			run(`$rscript_cmd $path`)
			println("  [OK]   $script completed successfully")
		catch e
			println("  [FAIL] $script — $e")
		end
	end
	println("="^60)
	println("All R scripts processed.")
end
