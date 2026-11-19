# visulization.jl
# GitHub Copilot
#
# Demonstration: approximate product z = x * y using a simple SOS1-style discretization
# and compare the true surface with the SOS1-relaxed piecewise planes visually.
#
using Plots
using PlotThemes
using LaTeXStrings
# Generate data and plot function
# function plot_sos1_relaxation(K::Int = 5; nx::Int = 80, ny::Int = 80, savepath::String = "sos1_relaxation.png")
# use the provided nx, ny and K (do not overwrite them here)
nx, ny = 120, 120
xs = range(0.0, 1.0, length = nx)
ys = range(0.0, 1.0, length = ny)

# grid
X = repeat(collect(xs)', ny, 1)  # ny x nx
Y = repeat(collect(ys), 1, nx)   # ny x nx

# true product surface
Z_true = X .* Y .* Y

# discretize x into K nodes (candidates for SOS1)
K = 10
x_nodes = range(0.0, 1.0, length = K) |> collect

# For each value, snap to nearest node (simulate SOS1 selecting one node)
function snap_to_nodes(xv)
    # return array of the same length as xv with node values
    idx = map(x -> findmin(abs.(x_nodes .- x))[2], xv)
    return x_nodes[idx]
end

# Build relaxed surface by snapping x values to nodes
Z_relax = similar(Z_true)
for j in 1:size(X, 2)
    xcol = X[:, j]
    xcol_snapped = snap_to_nodes(xcol)
    Z_relax[:, j] .= xcol_snapped .* Y[:, j] .* Y[:, j]
end

# sample points to draw connecting lines between true and relaxed values
sample_indices = [(round(Int, ny*0.2), round(Int, nx*0.3)),
    (round(Int, ny*0.5), round(Int, nx*0.5)),
    (round(Int, ny*0.8), round(Int, nx*0.7))]

# plotting
plt = Plots.plot(layout = (1, 3), size = (1400, 480))

# true surface
Plots.plot!(plt[1], title = "Original constraints: z = f * v^{2}", xlabel = L"f (p.u.)", ylabel = L"v (p.u.)", zlabel = L"fv^{2} (p.u.)")
Plots.surface!(plt[1], xs, ys, Z_true, c = :viridis, alpha = 0.9, colorbar = false)

# SOS1 discretized surface (piecewise planes)
Plots.plot!(plt[2], title = "SOS1 discretization (x binned)", xlabel = L"f (p.u.)", ylabel = L"v (p.u.)", zlabel = L"fv^{2} (p.u.)")
Plots.surface!(plt[2], xs, ys, Z_relax, c = :plasma, alpha = 0.9, colorbar = false)

# comparison: both surfaces and sample mappings
# clearer comparison: show true surface and a slightly z-shifted relaxed surface
Plots.plot!(plt[3], title = "Mapping: true points vs SOS1 relaxation", xlabel = L"f (p.u.)", ylabel = L"v (p.u.)", zlabel = L"fv^{2} (p.u.)")
# true surface (semi-transparent)
Plots.surface!(plt[3], xs, ys, Z_true, c = :viridis, alpha = 0.9, label = "True", colorbar = false)
# shift the relaxed surface slightly upward so the two surfaces don't lie on top of each other
z_shift = 0.03
Z_relax_shift = Z_relax .+ z_shift
Plots.surface!(plt[3], xs, ys, Z_relax_shift, c = :plasma, alpha = 0.9, label = "SOS1 (shifted)", colorbar = false)

# overlay mesh lines on the relaxed surface to emphasize the stepwise structure
for j in 1:size(X, 2)
    Plots.plot!(plt[3], X[:, j], Y[:, j], Z_relax_shift[:, j], lw = 0.6, lc = :black, label = false)
end
for i in 1:size(X, 1)
    Plots.plot!(plt[3], X[i, :], Y[i, :], Z_relax_shift[i, :], lw = 0.6, lc = :black, label = false)
end

# draw sample points and connecting lines on comparison subplot
for (iy, ix) in sample_indices
    x0 = X[iy, ix];
    y0 = Y[iy, ix];
    z0 = Z_true[iy, ix]
    z_rel = Z_relax[iy, ix]
    Plots.scatter!(plt[3], [x0], [y0], [z0], markersize = 6, markercolor = :black, label = false)
    Plots.scatter!(plt[3], [x0], [y0], [z_rel], markersize = 6, markercolor = :red, label = false)
    Plots.plot!(plt[3], [x0, x0], [y0, y0], [z0, z_rel], lw = 2, lc = :black, label = false)
end

# save images: full figure and each subplot separately
base_dir = raw"D:\GithubClonefiles\datacentra_unitcommitment\sos1"
savefig(plt, joinpath(base_dir, "sos1_relaxation_full.pdf"))
savefig(plot(plt[1]), joinpath(base_dir, "sos1_relaxation_true.pdf"))
savefig(plot(plt[2]), joinpath(base_dir, "sos1_relaxation_relax.pdf"))
savefig(plot(plt[3]), joinpath(base_dir, "sos1_relaxation_mapping.pdf"))

savefig(plt, joinpath(base_dir, "sos1_relaxation_full.png"))
savefig(plot(plt[1]), joinpath(base_dir, "sos1_relaxation_true.png"))
savefig(plot(plt[2]), joinpath(base_dir, "sos1_relaxation_relax.png"))
savefig(plot(plt[3]), joinpath(base_dir, "sos1_relaxation_mapping.png"))


println("Saved full figure and individual subplots to: ", base_dir)
