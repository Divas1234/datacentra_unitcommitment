using Plots
using PlotThemes
Plots.theme(:vibrant)

# 数据准备
frequencies = [0.5, 1.0, 1.5, 2.0, 2.5]
voltages = [1.2, 1.1, 1.0, 0.9, 0.8]
labels = [
	"P0 (High Frequency, High Performance)",
	"P1",
	"P2",
	"P3",
	"P4/P5 (Low Frequency, Low Power)"
]

# 绘图
p = plot(frequencies, voltages,
		 seriestype = :scatter,
		 markersize = 8,
		 markercolor = :blue,
		 xlabel = "Frequency (GHz)",
		 frame = :box,
		 ylim = (0.75, 1.25),
		 xlim = (0.4, 3.0),
		 ylabel = "Voltage (V)",
		 legend = :none,
		 xticks = 0.5:0.5:3.5,
		 yticks = 0.8:0.1:1.2,
		 annotations = [(frequencies[i], voltages[i] + 0.01, text(labels[i], :left, 8)) for i in 1:length(frequencies)])
display(p)
savefilepath = "D:\\GithubClonefiles\\datacentra_unitcommitment\\sos1\\dvfs\\dcc_dvfs_ptypes.pdf"
Plots.savefig(p, savefilepath)

#ANCHOR - performence vs power 3D bar plot
# CPU states and metrics
states      = ["P0", "P1", "P2", "P3", "P4", "P5"]
freq        = [3.5, 3.0, 2.5, 2.0, 1.5, 1.0]          # GHz
volt        = [1.20, 1.10, 1.00, 0.90, 0.85, 0.80]    # V
power_ratio = [100, 85, 70, 55, 40, 25]        # %
perf_ratio  = [100, 86, 71, 57, 43, 29]        # %

# build a grid matrix Z (rows -> volt, cols -> freq) and fill measured points
Z = fill(NaN, length(volt), length(freq))
for i in 1:min(length(freq), length(volt))
	Z[i, i] = power_ratio[i]
end

p_heat = Plots.heatmap(freq, volt, Z;
					   xlabel = "Frequency (GHz)",
					   ylabel = "Voltage (V)",
					   title = "Power Ratio (%) vs Frequency and Voltage",
					   color = :viridis,
					   clims = (minimum(power_ratio) - 5, maximum(power_ratio) + 5),
					   framestyle = :box,
					   legend = :none)

# annotate the measured points with their power ratio
annotate!(p_heat, [(freq[i], volt[i], text("$(power_ratio[i])%", :center, 8, :white)) for i in 1:length(freq)])

display(p_heat)
savefig(p_heat, "D:\\GithubClonefiles\\datacentra_unitcommitment\\sos1\\dvfs\\dcc_dvfs_heatmap.pdf")
