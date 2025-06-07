using Plots
using DataFrames

baseline_jobdatacurve = [12	10	15
7	8	20
5	5	15
0	0	10
0	0	9
0	0	15
0	0	20
0	0	20
3	0	20
8	0	20
13	0	20
15	0	20
15	0	20
15	0	20
13	0	20
10	0	20
7	0	20
10	0	20
13	0	20
10	0	20
5	0	20
0	0	15
0	0	5
0	0	0
]

Plots.plot(baseline_jobdatacurve)

num_workloads_Jobs = 8
workloads_jolbmatrix = zeros(size(baseline_jobdatacurve, 1), num_workloads_Jobs)
workloads_jolbmatrix[:,1:3] = baseline_jobdatacurve


for i in 1:num_workloads_Jobs
    if i > 3
        workloads_jolbmatrix[:,i] = workloads_jolbmatrix[:,i-3] .+ rand(size(workloads_jolbmatrix, 1)) .* 1.50
    end
end

Plots.plot(workloads_jolbmatrix)

using CSV

@show workloads_jobdf = DataFrame(workloads_jolbmatrix, :auto)
CSV.write("workloads_jobdf.csv", workloads_jobdf)