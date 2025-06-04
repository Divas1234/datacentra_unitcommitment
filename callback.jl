function run_r_visualizations()
    # Get the base path of the current project.
    # Assumes callback.jl is at the root of the workspace d:/GithubClonefiles/datacentra_unitcommitment
    project_root = @__DIR__

    # Define paths to the R scripts relative to the project root
    # Note: The R scripts themselves use absolute paths for their internal file operations.
    freq_script_path = joinpath(project_root, "output", "data_centra", "draw_datavisualiation_freq.r")
    lambda_script_path = joinpath(project_root, "output", "data_centra", "draw_datavisualiation_lambda.r")
    voltage_script_path = joinpath(project_root, "output", "data_centra", "draw_datavisualiation_voltage.r")
    workload_script_path = joinpath(project_root, "output", "data_centra", "draw_datavisualiation.r")

    # Ensure Rscript is in the PATH or provide full path to Rscript executable
    # For example, on Windows: rscript_executable = "C:\\Program Files\\R\\R-4.3.1\\bin\\Rscript.exe"
    # On Linux/macOS: rscript_executable = "Rscript"
    # We will assume Rscript is in the PATH for simplicity here.
    rscript_executable = "Rscript"

    println("Executing R script for frequency data visualization: $freq_script_path")
    try
        run(`$rscript_executable $freq_script_path`)
        println("Frequency data visualization script executed successfully.")
    catch e
        println("Error executing frequency R script ($freq_script_path): ")
        showerror(stdout, e)
        println() # Newline after error
    end

    println("Executing R script for lambda data visualization: $lambda_script_path")
    try
        run(`$rscript_executable $lambda_script_path`)
        println("Lambda data visualization script executed successfully.")
    catch e
        println("Error executing lambda R script ($lambda_script_path): ")
        showerror(stdout, e)
        println() # Newline after error
    end

    println("Executing R script for voltage data visualization: $voltage_script_path")
    try
        run(`$rscript_executable $voltage_script_path`)
        println("Voltage data visualization script executed successfully.")
    catch e
        println("Error executing voltage R script ($voltage_script_path): ")
        showerror(stdout, e)
        println() # Newline after error
    end

    println("Executing R script for workload data visualization: $workload_script_path")
    try
        run(`$rscript_executable $workload_script_path`)
        println("Workload data visualization script executed successfully.")
    catch e
        println("Error executing workload R script ($workload_script_path): ")
        showerror(stdout, e)
        println() # Newline after error
    end

    println("All R visualization scripts have been called.")
end

# To make this function callable from other Julia files, you might want to export it if this becomes part of a module.
# For now, it can be included and called directly.

# Example usage (comment out or remove if you intend to call this from another script):
# if abspath(PROGRAM_FILE) == @__FILE__
#     run_r_visualizations()
# end