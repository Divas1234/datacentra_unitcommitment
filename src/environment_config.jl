using Pkg
Pkg.activate("./.pkg")
# Pkg.add([
# 			"Revise", "JuMP", "Gurobi", "Test", "DelimitedFiles", "PlotlyJS",
# 			"LaTeXStrings", "Plots", "JLD", "DataFrames", "Clustering",
# 			"StatsPlots", "CSV", "BenchmarkTools"
# 		])
using Revise, JuMP, Gurobi, Test, DelimitedFiles, LaTeXStrings, Plots, DataFrames, Clustering, StatsPlots, CSV, BenchmarkTools
gr()
using Random
using DataFrames
Random.seed!(1234)
# using BenchmarkTools

# @benchmark sort(data) setup=(data=rand(10))

# files_to_include = [
# 	"formatteddata.jl",
# 	"get_boundarycondtions.jl",
# 	"renewableenergysimulation.jl",
# 	"showboundrycase.jl",
# 	"readdatafromexcel.jl",
# 	"SUCuccommitmentmodel.jl",
# 	"casesploting.jl",
# 	"saveresult.jl"
# ]
# for file in files_to_include
# 	include(file)
# end

include("./oths/formatteddata.jl")
include("./oths/get_boundarycondtions.jl")
include("./oths/renewableenergysimulation.jl")
include("./oths/showboundrycase.jl")
include("./oths/readdatafromexcel.jl")
include("./oths/SUCuccommitmentmodel.jl")
include("./oths/casesploting.jl")
include("./oths/saveresult.jl")
# include(joinpath(@__DIR__, "..", "callback.jl"))

include("./draws/dcc_workload_dis.jl")