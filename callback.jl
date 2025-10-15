function run_r_visualizations()
    # Get the base path of the current project.
    # Assumes callback.jl is at the root of the workspace d:/GithubClonefiles/datacentra_unitcommitment
    project_root = @__DIR__
    println("Project root directory: $project_root")

    # Define paths to the R scripts relative to the project root
    # Note: The R scripts themselves use absolute paths for their internal file operations.
    freq_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_fv²_subplots.r")
    dvfs_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_fv².r")
    voltage_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_fv²λ.r")
    workload_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_p.r")
    lambda_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_λ.r")
    seq_lambda_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_λ_seq.r")
    seq_workload_script_path = joinpath(project_root, "output", "data_centra", "draw_dc_fv²λ_subplots.r")

    # Ensure Rscript is in the PATH or provide full path to Rscript executable
    # For example, on Windows: rscript_executable = "C:\\Program Files\\R\\R-4.3.1\\bin\\Rscript.exe"
    # On Linux/macOS: rscript_executable = "Rscript"
    # We will assume Rscript is in the PATH for simplicity here.
    rscript_executable = "Rscript"

    println("Attempting to execute R script for frequency data visualization.")
    println("Script path: $freq_script_path")
    if isfile(freq_script_path)
        try
            run(`$rscript_executable $freq_script_path`)
            println("Frequency data visualization script ($freq_script_path) executed successfully.")
        catch e
            println("Error executing frequency R script ($freq_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Frequency R script not found at $freq_script_path")
        println() # Newline after error
    end

    println("Attempting to execute R script for lambda data visualization.")
    println("Script path: $lambda_script_path")
    if isfile(lambda_script_path)
        try
            run(`$rscript_executable $lambda_script_path`)
            println("Lambda data visualization script ($lambda_script_path) executed successfully.")
        catch e
            println("Error executing lambda R script ($lambda_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Lambda R script not found at $lambda_script_path")
        println() # Newline after error
    end

    if isfile(seq_workload_script_path)
        try
            run(`$rscript_executable $seq_workload_script_path`)
            println("Lambda data visualization script ($seq_workload_script_path) executed successfully.")
        catch e
            println("Error executing lambda R script ($seq_workload_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Lambda R script not found at $lambda_script_path")
        println() # Newline after error
    end

    println("Attempting to execute R script for DVFS data visualization.")
    println("Script path: $dvfs_script_path")
    if isfile(dvfs_script_path)
        try
            run(`$rscript_executable $dvfs_script_path`)
            println("DVFS data visualization script ($dvfs_script_path) executed successfully.")
        catch e
            println("Error executing DVFS R script ($dvfs_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: DVFS R script not found at $dvfs_script_path")
        println() # Newline after error
    end

    println("Attempting to execute R script for sequential lambda data visualization.")
    println("Script path: $seq_lambda_script_path")
    if isfile(seq_lambda_script_path)
        try
            run(`$rscript_executable $seq_lambda_script_path`)
            println("Sequential lambda data visualization script ($seq_lambda_script_path) executed successfully.")
        catch e
            println("Error executing sequential lambda R script ($seq_lambda_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Sequential lambda R script not found at $seq_lambda_script_path")
        println() # Newline after error
    end

    println("Attempting to execute R script for voltage data visualization.")
    println("Script path: $voltage_script_path")
    if isfile(voltage_script_path)
        try
            run(`$rscript_executable $voltage_script_path`)
            println("Voltage data visualization script ($voltage_script_path) executed successfully.")
        catch e
            println("Error executing voltage R script ($voltage_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Voltage R script not found at $voltage_script_path")
        println() # Newline after error
    end

    println("Attempting to execute R script for workload data visualization.")
    println("Script path: $workload_script_path")
    if isfile(workload_script_path)
        try
            run(`$rscript_executable $workload_script_path`)
            println("Workload data visualization script ($workload_script_path) executed successfully.")
        catch e
            println("Error executing workload R script ($workload_script_path): ")
            showerror(stdout, e)
            println() # Newline after error
        end
    else
        println("Error: Workload R script not found at $workload_script_path")
        println() # Newline after error
    end

    println("All R visualization scripts have been processed.")
end

# To make this function callable from other Julia files, you might want to export it if this becomes part of a module.
# For now, it can be included and called directly.

# Example usage (comment out or remove if you intend to call this from another script):
# if abspath(PROGRAM_FILE) == @__FILE__
#     run_r_visualizations()
# end
