using Plots
using DelimitedFiles
x = collect(0.25:0.05:1.5)
# y = x * 1.25
y = collect(0.25 * 1.25:0.025:1.5*1.25)

# z = x .* y.^2 * 0.035

num = length(x)
num_col = length(y)
z = zeros(num, num_col)
for i in 1:num
    for j in 1:num_col
        z[i, j] = x[i] * y[j]^2 * 0.035
    end
end

z
# Plots.plot3d(x, y, z)
writedlm("fig/boundaries_conditions/dcc/z_matrix.csv", z, ',')