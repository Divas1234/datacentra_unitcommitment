using DelimitedFiles
using Statistics
using Plots

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
const DC_DIR = joinpath(ROOT, "output", "data_centra", "master-3(iter=12)")
const OUT_DIR = joinpath(ROOT, "output", "visualization", "current_results_plotsjl")
const FIG_SIZE = (400, 400)

function read_csv_matrix(path::AbstractString)
    raw = readdlm(path, ',', String; skipstart = 1)
    return parse.(Float64, raw)
end

function read_vector(path::AbstractString)
    return vec(Float64.(readdlm(path)))
end

function export_workbook_cache()
    cache_dir = joinpath(OUT_DIR, "_xlsx_cache")
    mkpath(cache_dir)
    script_path = joinpath(cache_dir, "extract_workbook.py")
    write(script_path, raw"""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import csv
import re
import sys

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}

def colnum(ref):
    letters = re.match(r"[A-Z]+", ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - ord("A") + 1
    return n - 1

def read_sheet(zf, sheet_name):
    shared = []
    if "xl/sharedStrings.xml" in zf.namelist():
        root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
        for item in root.findall(".//a:si", NS):
            shared.append("".join(t.text or "" for t in item.findall(".//a:t", NS)))

    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    relmap = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels}
    target = None
    for sheet in workbook.find("a:sheets", NS):
        if sheet.attrib["name"] == sheet_name:
            rid = sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]
            target = "xl/" + relmap[rid]
            break
    if target is None:
        raise RuntimeError(f"missing sheet: {sheet_name}")

    root = ET.fromstring(zf.read(target))
    rows = []
    for row in root.findall(".//a:sheetData/a:row", NS):
        values = []
        for cell in row.findall("a:c", NS):
            idx = colnum(cell.attrib["r"])
            while len(values) <= idx:
                values.append("")
            node = cell.find("a:v", NS)
            raw = "" if node is None else node.text or ""
            values[idx] = shared[int(raw)] if cell.attrib.get("t") == "s" and raw else raw
        rows.append(values)
    return rows

xlsx = Path(sys.argv[1])
outdir = Path(sys.argv[2])
outdir.mkdir(parents=True, exist_ok=True)
sheets = ["mg_bus_map", "units_data", "load_data", "strogesystem_data", "data_centra", "data_centra_jobcurve", "load_curve"]
with ZipFile(xlsx) as zf:
    for name in sheets:
        rows = read_sheet(zf, name)
        with (outdir / f"{name}.csv").open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerows(rows)
""")
    run(`python $script_path $(joinpath(ROOT, "data", "data.xlsx")) $cache_dir`)
    return cache_dir
end

function read_cached_sheet(cache_dir::AbstractString, name::AbstractString)
    path = joinpath(cache_dir, name * ".csv")
    raw = readdlm(path, ',', String; skipstart = 1)
    return parse.(Float64, raw)
end

function workbook_inputs()
    cache_dir = export_workbook_cache()
    return (
        mg_bus_map = read_cached_sheet(cache_dir, "mg_bus_map"),
        units = read_cached_sheet(cache_dir, "units_data"),
        loads = read_cached_sheet(cache_dir, "load_data"),
        storage = read_cached_sheet(cache_dir, "strogesystem_data"),
        dcc = read_cached_sheet(cache_dir, "data_centra"),
        dcc_jobcurve = read_cached_sheet(cache_dir, "data_centra_jobcurve"),
        loadcurve = read_cached_sheet(cache_dir, "load_curve"),
    )
end

function save_png_pdf(p, stem::AbstractString)
    mkpath(OUT_DIR)
    png_path = joinpath(OUT_DIR, stem * ".png")
    pdf_path = joinpath(OUT_DIR, stem * ".pdf")
    savefig(p, png_path)
    savefig(p, pdf_path)
    println("saved: ", png_path)
    println("saved: ", pdf_path)
end

function parse_result_list(path::AbstractString, list_no::Int, rows::Int)
    lines = readlines(path)
    marker = "list $(list_no):"
    start = findfirst(line -> startswith(strip(line), marker), lines)
    start === nothing && error("Cannot find $marker in $path")

    data = Vector{Vector{Float64}}()
    for line in lines[(start + 1):end]
        s = strip(line)
        isempty(s) && (!isempty(data) ? break : continue)
        startswith(s, "list ") && break
        push!(data, parse.(Float64, split(s)))
        length(data) == rows && break
    end
    return reduce(vcat, permutedims.(data))
end

function wind_curve()
    return [
        0.440724927203680, 0.420965256587272, 0.449034794022911, 0.454128108336623,
        0.436483077739172, 0.477450522402300, 0.443871634609799, 0.374756446192485,
        0.448192193924943, 0.431190577826877, 0.428867647037057, 0.445673091565042,
        0.433764408789611, 0.421900481861469, 0.429104412188035, 0.463277796146724,
        0.426579282372516, 0.448189506134410, 0.429353980231385, 0.434861266141317,
        0.437494540514197, 0.456877055120346, 0.425139803090161, 0.425629623577982,
    ]
end

function current_power_data(dc_p)
    wb = workbook_inputs()
    result_path = joinpath(ROOT, "output", "Bench_calculation_result.txt")
    loadcurve = wb.loadcurve[:, 2] ./ 100.0

    unit_p = parse_result_list(result_path, 2, size(wb.units, 1))
    wind_spill = parse_result_list(result_path, 3, 2)
    load_cut = parse_result_list(result_path, 4, size(wb.loads, 1))
    charge = parse_result_list(result_path, 7, size(wb.storage, 1))
    discharge = parse_result_list(result_path, 8, size(wb.storage, 1))

    bus_to_mg = Dict(Int(row[1]) => Int(row[2]) for row in eachrow(wb.mg_bus_map))
    mg_count = maximum(values(bus_to_mg))
    mg = [Dict(k => zeros(24) for k in ["thermal", "wind", "load", "dc", "charge", "discharge", "cut", "net"]) for _ in 1:mg_count]

    for i in 1:size(wb.units, 1)
        target = bus_to_mg[Int(wb.units[i, 2])]
        mg[target]["thermal"] .+= unit_p[i, :]
    end

    # Two wind units are connected to bus 1/MG1, each with 2.0 p.u. capacity.
    wc = wind_curve()
    wind_mg = bus_to_mg[1]
    mg[wind_mg]["wind"] .+= 2.0 .* wc .- wind_spill[1, :]
    mg[wind_mg]["wind"] .+= 2.0 .* wc .- wind_spill[2, :]

    for i in 1:size(wb.loads, 1)
        target = bus_to_mg[Int(wb.loads[i, 2])]
        mg[target]["load"] .+= wb.loads[i, 3] .* loadcurve
        mg[target]["cut"] .+= load_cut[i, :]
    end

    for i in 1:size(wb.storage, 1)
        target = bus_to_mg[Int(wb.storage[i, 2])]
        mg[target]["charge"] .+= charge[i, :]
        mg[target]["discharge"] .+= discharge[i, :]
    end

    for i in 1:min(size(wb.dcc, 1), size(dc_p, 1))
        target = bus_to_mg[Int(wb.dcc[i, 2])]
        mg[target]["dc"] .+= dc_p[i, :]
    end

    for i in eachindex(mg), t in 1:24
        supply = mg[i]["thermal"][t] + mg[i]["wind"][t] + mg[i]["discharge"][t]
        demand = mg[i]["load"][t] - mg[i]["cut"][t] + mg[i]["dc"][t] + mg[i]["charge"][t]
        mg[i]["net"][t] = supply - demand
    end

    return mg
end

function workload_migration_plot(dc_p)
    t = 1:24
    colors = palette(:tab10, size(dc_p, 1))
    ymax = maximum(vec(sum(dc_p; dims = 1))) * 1.12
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "Power (p.u.)",
        title = "DCC Workload Migration",
        size = FIG_SIZE,
        legend = :outerright,
        framestyle = :box,
        grid = :y,
        xlims = (0.4, 24.6),
        ylims = (0, ymax),
    )
    for i in 1:size(dc_p, 1)
        for tt in t
            y0 = sum(dc_p[1:(i - 1), tt]; init = 0.0)
            y1 = y0 + dc_p[i, tt]
            label = tt == 1 ? "DCC $i" : ""
            shape = Shape([tt - 0.36, tt + 0.36, tt + 0.36, tt - 0.36], [y0, y0, y1, y1])
            plot!(p, shape; color = colors[i], label = label, linewidth = 0)
        end
    end
    return p
end

function migration_delta_plot(dc_p)
    delta = dc_p .- mean(dc_p; dims = 2)
    lim = maximum(abs.(delta))
    return heatmap(
        1:24, 1:size(dc_p, 1), delta;
        xlabel = "Time (h)",
        ylabel = "DCC",
        title = "Migration Delta",
        color = :balance,
        clims = (-lim, lim),
        yticks = 1:size(dc_p, 1),
        size = FIG_SIZE,
        framestyle = :box,
    )
end

function heatmap_plot(mat, title_text, colorbar_title)
    return heatmap(
        1:24, 1:size(mat, 1), mat;
        xlabel = "Time (h)",
        ylabel = "DCC",
        title = title_text,
        color = :viridis,
        colorbar_title = colorbar_title,
        yticks = 1:size(mat, 1),
        size = FIG_SIZE,
        framestyle = :box,
    )
end

function interpark_aid_plot(dc_p)
    t = 1:24
    aid = dc_p .- mean(dc_p; dims = 2)
    absorb = vec(sum(max.(aid, 0.0); dims = 1))
    release = vec(sum(min.(aid, 0.0); dims = 1))
    net = vec(sum(aid; dims = 1))

    p = bar(
        t, [absorb release];
        label = ["absorb" "release"],
        color = [:steelblue :orange],
        xlabel = "Time (h)",
        ylabel = "Relative exchange",
        title = "DCC Load Balancing",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
    )
    plot!(p, t, net; label = "net", color = :black, linewidth = 2)
    return p
end

function dcc_power_allocation_plot(dc_p)
    t = 1:24
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "DCC power (p.u.)",
        title = "All DCC Power Allocation",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :outerright,
    )
    for i in 1:size(dc_p, 1)
        plot!(p, t, dc_p[i, :]; label = "DCC $i", linewidth = 2, marker = :circle, markersize = 2)
    end
    return p
end

function microgrid_dcc_allocation_plot(dc_p)
    t = 1:24
    wb = workbook_inputs()
    bus_to_mg = Dict(Int(row[1]) => Int(row[2]) for row in eachrow(wb.mg_bus_map))
    mg_count = maximum(values(bus_to_mg))
    mg_dcc = zeros(mg_count, length(t))
    for i in 1:min(size(wb.dcc, 1), size(dc_p, 1))
        target = bus_to_mg[Int(wb.dcc[i, 2])]
        mg_dcc[target, :] .+= dc_p[i, :]
    end

    p = plot(;
        xlabel = "Time (h)",
        ylabel = "DCC power (p.u.)",
        title = "Microgrid DCC Load Allocation",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :topright,
    )
    markers = [:circle, :square, :diamond, :utriangle]
    for i in 1:mg_count
        plot!(p, t, mg_dcc[i, :]; label = "MG$i DCC total", linewidth = 3, marker = markers[((i - 1) % length(markers)) + 1], markersize = 3)
    end
    return p
end

function baseline_dcc_power()
    wb = workbook_inputs()
    nd = size(wb.dcc, 1)
    tasks = wb.dcc_jobcurve[:, 1:nd] ./ 100.0
    idle = wb.dcc[:, 6]
    sv = wb.dcc[:, 7]
    mu = wb.dcc[:, 9]

    before = zeros(nd, 24)
    for i in 1:nd, t in 1:24
        before[i, t] = idle[i] + sv[i] / mu[i] * tasks[t, i] * 10.0
    end
    return before
end

function microgrid_dcc_totals(mat)
    wb = workbook_inputs()
    bus_to_mg = Dict(Int(row[1]) => Int(row[2]) for row in eachrow(wb.mg_bus_map))
    mg_count = maximum(values(bus_to_mg))
    totals = zeros(mg_count, size(mat, 2))
    for i in 1:min(size(wb.dcc, 1), size(mat, 1))
        target = bus_to_mg[Int(wb.dcc[i, 2])]
        totals[target, :] .+= mat[i, :]
    end
    return totals
end

function microgrid_native_load_totals()
    wb = workbook_inputs()
    bus_to_mg = Dict(Int(row[1]) => Int(row[2]) for row in eachrow(wb.mg_bus_map))
    mg_count = maximum(values(bus_to_mg))
    loadcurve = wb.loadcurve[:, 2] ./ 100.0
    totals = zeros(mg_count, 24)
    for i in 1:size(wb.loads, 1)
        target = bus_to_mg[Int(wb.loads[i, 2])]
        totals[target, :] .+= wb.loads[i, 3] .* loadcurve
    end
    return totals
end

function dcc_before_after_lines_plot(before, after)
    t = 1:24
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "DCC power (p.u.)",
        title = "DCC Before/After",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :outerright,
    )
    colors = palette(:tab10, size(after, 1))
    for i in 1:size(after, 1)
        plot!(p, t, before[i, :]; label = "DCC $i before", color = colors[i], linestyle = :dash, linewidth = 1.4)
        plot!(p, t, after[i, :]; label = "DCC $i after", color = colors[i], linewidth = 2)
    end
    return p
end

function dcc_power_difference_heatmap(before, after)
    diff = after .- before
    lim = maximum(abs.(diff))
    return heatmap(
        1:24, 1:size(after, 1), diff;
        xlabel = "Time (h)",
        ylabel = "DCC",
        title = "DCC Power Difference",
        color = :balance,
        clims = (-lim, lim),
        yticks = 1:size(after, 1),
        size = FIG_SIZE,
        framestyle = :box,
    )
end

function dcc_energy_before_after_bar(before, after)
    x = 1:size(after, 1)
    before_energy = vec(sum(before; dims = 2))
    after_energy = vec(sum(after; dims = 2))
    p = bar(
        x .- 0.18, before_energy;
        label = "before",
        bar_width = 0.34,
        xlabel = "DCC",
        ylabel = "Total energy (p.u.h)",
        title = "DCC Energy Change",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        xticks = x,
    )
    bar!(p, x .+ 0.18, after_energy; label = "after", bar_width = 0.34)
    return p
end

function microgrid_dcc_before_after_plot(before, after)
    t = 1:24
    before_mg = microgrid_dcc_totals(before)
    after_mg = microgrid_dcc_totals(after)
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "DCC power (p.u.)",
        title = "MG DCC Load Before/After",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :topright,
    )
    colors = palette(:tab10, size(after_mg, 1))
    for i in 1:size(after_mg, 1)
        plot!(p, t, before_mg[i, :]; label = "MG$i before", color = colors[i], linestyle = :dash, linewidth = 2)
        plot!(p, t, after_mg[i, :]; label = "MG$i after", color = colors[i], linewidth = 2.5)
    end
    return p
end

function microgrid_total_load_before_after_plot(before, after)
    t = 1:24
    native = microgrid_native_load_totals()
    before_total = native .+ microgrid_dcc_totals(before)
    after_total = native .+ microgrid_dcc_totals(after)
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "Total load (p.u.)",
        title = "MG Load Before/After",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :topright,
    )
    colors = palette(:tab10, size(after_total, 1))
    for i in 1:size(after_total, 1)
        plot!(p, t, before_total[i, :]; label = "MG$i before", color = colors[i], linestyle = :dash, linewidth = 2)
        plot!(p, t, after_total[i, :]; label = "MG$i after", color = colors[i], linewidth = 2.5)
    end
    return p
end

function microgrid_load_delta_plot(before, after)
    native = microgrid_native_load_totals()
    before_total = native .+ microgrid_dcc_totals(before)
    after_total = native .+ microgrid_dcc_totals(after)
    diff = after_total .- before_total
    lim = maximum(abs.(diff))
    return heatmap(
        1:24, 1:size(diff, 1), diff;
        xlabel = "Time (h)",
        ylabel = "Microgrid",
        title = "MG Load Difference",
        color = :balance,
        clims = (-lim, lim),
        yticks = 1:size(diff, 1),
        size = FIG_SIZE,
        framestyle = :box,
    )
end

function microgrid_balance_plot(mg, idx)
    t = 1:24
    p = plot(;
        xlabel = "Time (h)",
        ylabel = "Power (p.u.)",
        title = "Microgrid $idx Balance",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :topright,
    )
    plot!(p, t, mg["thermal"]; label = "thermal", linewidth = 2)
    plot!(p, t, mg["wind"]; label = "wind", linewidth = 2)
    plot!(p, t, mg["load"]; label = "load", linewidth = 2)
    plot!(p, t, mg["dc"]; label = "dc load", linewidth = 2)
    plot!(p, t, mg["discharge"] .- mg["charge"]; label = "BESS net", linewidth = 2)
    plot!(p, t, mg["net"]; label = "surplus", color = :black, linestyle = :dash, linewidth = 2)
    return p
end

function tie_and_dcc_coordination_plot(mg, dc_p)
    t = 1:24
    tie = mg[1]["net"]
    imbalance = [std(dc_p[:, i]) for i in 1:24]
    scale_factor = maximum(abs.(tie)) / max(maximum(imbalance), eps())

    p = bar(
        t, tie;
        label = "MG1 surplus / export",
        color = :steelblue,
        xlabel = "Time (h)",
        ylabel = "Tie-line power (p.u.)",
        title = "Tie-line Aid vs DCC Balance",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
    )
    plot!(p, t, imbalance .* scale_factor; label = "DCC std scaled", color = :black, linewidth = 2)
    return p
end

function coupled_coordination_plot(mg, dc_p)
    t = 1:24
    tie = mg[1]["net"]
    imbalance = [std(dc_p[:, i]) for i in 1:24]
    scale_factor = maximum(abs.(tie)) / max(maximum(imbalance), eps())

    p = plot(;
        xlabel = "Time (h)",
        ylabel = "Power / scaled index",
        title = "MG-DCC Coordination",
        size = FIG_SIZE,
        framestyle = :box,
        grid = :y,
        legend = :topright,
    )
    plot!(p, t, mg[1]["net"]; label = "MG1 surplus", linewidth = 2)
    plot!(p, t, mg[2]["net"]; label = "MG2 surplus", linewidth = 2)
    plot!(p, t, tie; label = "tie aid", linewidth = 2, linestyle = :dash)
    plot!(p, t, imbalance .* scale_factor; label = "DCC std scaled", color = :black, linewidth = 2)
    hline!(p, [0.0]; label = "", color = :gray, linewidth = 1)
    return p
end

function main()
    dc_p = read_csv_matrix(joinpath(DC_DIR, "dc_p.csv"))
    dc_fv2 = read_csv_matrix(joinpath(DC_DIR, "dc_fv².csv"))
    dc_fv2lambda = read_csv_matrix(joinpath(DC_DIR, "dc_fv²λ.csv"))
    dc_lambda = dc_fv2lambda ./ dc_fv2
    dc_before = baseline_dcc_power()
    mg = current_power_data(dc_p)

    plots = [
        ("01_workload_migration", workload_migration_plot(dc_p)),
        ("02_migration_delta_heatmap", migration_delta_plot(dc_p)),
        ("03_dvfs_fv2_heatmap", heatmap_plot(dc_fv2, "DVFS fv2", "fv2")),
        ("04_effective_workload_fv2lambda_heatmap", heatmap_plot(dc_fv2lambda, "Effective fv2lambda", "fv2lambda")),
        ("05_lambda_heatmap", heatmap_plot(dc_lambda, "Migration lambda", "lambda")),
        ("06_all_dcc_power_allocation", dcc_power_allocation_plot(dc_p)),
        ("07_microgrid_dcc_load_allocation", microgrid_dcc_allocation_plot(dc_p)),
        ("08_dcc_load_balancing_deviation", interpark_aid_plot(dc_p)),
        ("09_microgrid_1_balance", microgrid_balance_plot(mg[1], 1)),
        ("10_microgrid_2_balance", microgrid_balance_plot(mg[2], 2)),
        ("11_tie_aid_vs_dcc_balance", tie_and_dcc_coordination_plot(mg, dc_p)),
        ("12_coupled_coordination", coupled_coordination_plot(mg, dc_p)),
        ("13_dcc_before_after_power", dcc_before_after_lines_plot(dc_before, dc_p)),
        ("14_dcc_power_difference_heatmap", dcc_power_difference_heatmap(dc_before, dc_p)),
        ("15_dcc_energy_before_after", dcc_energy_before_after_bar(dc_before, dc_p)),
        ("16_microgrid_dcc_before_after", microgrid_dcc_before_after_plot(dc_before, dc_p)),
        ("17_microgrid_total_load_before_after", microgrid_total_load_before_after_plot(dc_before, dc_p)),
        ("18_microgrid_load_difference_heatmap", microgrid_load_delta_plot(dc_before, dc_p)),
    ]

    for (stem, p) in plots
        save_png_pdf(p, stem)
    end
end

main()
