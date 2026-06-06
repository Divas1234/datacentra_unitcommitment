from __future__ import annotations

import csv
import html
import math
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
XLSX_NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def read_csv_matrix(path: Path) -> list[list[float]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))
    return [[float(x) for x in row] for row in rows[1:]]


def read_vector(path: Path) -> list[float]:
    values: list[float] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        values.extend(float(x) for x in line.split())
    return values


def column_index(cell_ref: str) -> int:
    letters = re.match(r"[A-Z]+", cell_ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - ord("A") + 1
    return n - 1


def read_xlsx_sheet(path: Path, sheet_name: str) -> list[list[float | str]]:
    with ZipFile(path) as zf:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in zf.namelist():
            root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for item in root.findall(".//a:si", XLSX_NS):
                shared.append("".join(t.text or "" for t in item.findall(".//a:t", XLSX_NS)))

        workbook = ET.fromstring(zf.read("xl/workbook.xml"))
        rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        relmap = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels}
        target = None
        for sheet in workbook.find("a:sheets", XLSX_NS):
            if sheet.attrib["name"] == sheet_name:
                rel_id = sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]
                target = "xl/" + relmap[rel_id]
                break
        if target is None:
            raise ValueError(f"Sheet not found: {sheet_name}")

        root = ET.fromstring(zf.read(target))
        rows: list[list[float | str]] = []
        for row in root.findall(".//a:sheetData/a:row", XLSX_NS):
            values: list[float | str] = []
            for cell in row.findall("a:c", XLSX_NS):
                idx = column_index(cell.attrib["r"])
                while len(values) <= idx:
                    values.append("")
                node = cell.find("a:v", XLSX_NS)
                raw = "" if node is None else node.text or ""
                if cell.attrib.get("t") == "s":
                    values[idx] = shared[int(raw)]
                else:
                    try:
                        values[idx] = float(raw)
                    except ValueError:
                        values[idx] = raw
            rows.append(values)
        return rows


def sheet_numeric_rows(path: Path, sheet_name: str) -> list[list[float]]:
    rows = read_xlsx_sheet(path, sheet_name)
    return [[float(x) for x in row if x != ""] for row in rows[1:]]


def parse_result_list(path: Path, list_no: int, rows: int) -> list[list[float]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    marker = f"list {list_no}:"
    start = next(i for i, line in enumerate(lines) if line.strip().startswith(marker)) + 1
    data: list[list[float]] = []
    for line in lines[start:]:
        line = line.strip()
        if not line:
            if data:
                break
            continue
        if line.startswith("list "):
            break
        data.append([float(x) for x in line.split()])
        if len(data) == rows:
            break
    return data


def scale(values: list[float], start: float, end: float) -> list[float]:
    lo, hi = min(values), max(values)
    if math.isclose(lo, hi):
        return [(start + end) / 2 for _ in values]
    return [start + (v - lo) / (hi - lo) * (end - start) for v in values]


def color_blend(a: str, b: str, x: float) -> str:
    x = max(0.0, min(1.0, x))
    ar, ag, ab = int(a[1:3], 16), int(a[3:5], 16), int(a[5:7], 16)
    br, bg, bb = int(b[1:3], 16), int(b[3:5], 16), int(b[5:7], 16)
    return f"#{round(ar + (br - ar) * x):02x}{round(ag + (bg - ag) * x):02x}{round(ab + (bb - ab) * x):02x}"


def diverging_color(value: float, limit: float) -> str:
    if limit <= 0:
        return "#f7f7f7"
    x = max(-1.0, min(1.0, value / limit))
    return color_blend("#f7f7f7", "#4c78a8", x) if x >= 0 else color_blend("#f7f7f7", "#f58518", -x)


def sequential_color(value: float, lo: float, hi: float) -> str:
    x = 0.5 if math.isclose(lo, hi) else (value - lo) / (hi - lo)
    return color_blend("#eef3f8", "#2f4858", x)


def svg_frame(width: int, height: int, title: str, body: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="100%" height="100%" fill="#ffffff"/>
<style>
text {{ font-family: Arial, 'Microsoft YaHei', sans-serif; fill: #1f2933; }}
.title {{ font-size: 22px; font-weight: 700; }}
.axis {{ font-size: 12px; fill: #52606d; }}
.legend {{ font-size: 12px; fill: #334e68; }}
.grid {{ stroke: #e4e7eb; stroke-width: 1; }}
.axisline {{ stroke: #9aa5b1; stroke-width: 1; }}
</style>
<text x="32" y="34" class="title">{html.escape(title)}</text>
{body}
</svg>"""


def save_svg(path: Path, width: int, height: int, title: str, body: str) -> None:
    path.write_text(svg_frame(width, height, title, body), encoding="utf-8")


def stacked_workload_svg(dc_p: list[list[float]], path: Path) -> None:
    width, height = 980, 460
    left, top, right, bottom = 70, 62, 180, 58
    plot_w, plot_h = width - left - right, height - top - bottom
    totals = [sum(row[t] for row in dc_p) for t in range(len(dc_p[0]))]
    ymax = max(totals) * 1.12
    colors = ["#4c78a8", "#f58518", "#54a24b", "#e45756", "#72b7b2", "#b279a2", "#ff9da6", "#9d755d"]
    bar_w = plot_w / 24 * 0.72
    parts = []
    for g in range(5):
        y = top + plot_h - g * plot_h / 4
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" class="grid"/>')
    for t in range(24):
        x = left + t * plot_w / 24 + (plot_w / 24 - bar_w) / 2
        y_base = top + plot_h
        for i, row in enumerate(dc_p):
            h = row[t] / ymax * plot_h
            y_base -= h
            parts.append(f'<rect x="{x:.1f}" y="{y_base:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors[i % len(colors)]}"/>')
        if t % 2 == 0:
            parts.append(f'<text x="{x + bar_w/2:.1f}" y="{height-30}" text-anchor="middle" class="axis">{t+1}</text>')
    parts.append(f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" class="axisline"/>')
    parts.append(f'<text x="{left+plot_w/2}" y="{height-8}" text-anchor="middle" class="axis">Time (h)</text>')
    parts.append(f'<text x="18" y="{top+plot_h/2}" transform="rotate(-90 18 {top+plot_h/2})" text-anchor="middle" class="axis">Power / workload (p.u.)</text>')
    for i in range(len(dc_p)):
        y = top + 12 + i * 22
        parts.append(f'<rect x="{width-right+28}" y="{y-10}" width="12" height="12" fill="{colors[i % len(colors)]}"/>')
        parts.append(f'<text x="{width-right+48}" y="{y}" class="legend">DCC {i+1}</text>')
    save_svg(path, width, height, "Computing Workload Migration", "\n".join(parts))


def heatmap_svg(mat: list[list[float]], path: Path, title: str, mode: str = "seq") -> None:
    width, height = 980, 460
    left, top, right, bottom = 88, 64, 130, 58
    rows, cols = len(mat), len(mat[0])
    plot_w, plot_h = width - left - right, height - top - bottom
    flat = [v for row in mat for v in row]
    lo, hi = min(flat), max(flat)
    limit = max(abs(lo), abs(hi))
    cell_w, cell_h = plot_w / cols, plot_h / rows
    parts = []
    for r, row in enumerate(mat):
        for c, value in enumerate(row):
            color = diverging_color(value, limit) if mode == "div" else sequential_color(value, lo, hi)
            parts.append(f'<rect x="{left+c*cell_w:.1f}" y="{top+r*cell_h:.1f}" width="{cell_w+0.4:.1f}" height="{cell_h+0.4:.1f}" fill="{color}"/>')
    for c in range(cols):
        if c % 2 == 0:
            parts.append(f'<text x="{left+(c+0.5)*cell_w:.1f}" y="{height-30}" text-anchor="middle" class="axis">{c+1}</text>')
    for r in range(rows):
        parts.append(f'<text x="{left-10}" y="{top+(r+0.62)*cell_h:.1f}" text-anchor="end" class="axis">DCC {r+1}</text>')
    parts.append(f'<text x="{left+plot_w/2}" y="{height-8}" text-anchor="middle" class="axis">Time (h)</text>')
    parts.append(f'<text x="{width-right+20}" y="{top+12}" class="legend">min {lo:.3f}</text>')
    parts.append(f'<text x="{width-right+20}" y="{top+34}" class="legend">max {hi:.3f}</text>')
    save_svg(path, width, height, title, "\n".join(parts))


def line_path(xs: list[float], ys: list[float]) -> str:
    return " ".join(("M" if i == 0 else "L") + f"{x:.1f},{y:.1f}" for i, (x, y) in enumerate(zip(xs, ys)))


def interpark_aid_svg(dc_p: list[list[float]], path: Path) -> None:
    width, height = 980, 460
    left, top, right, bottom = 76, 62, 170, 58
    plot_w, plot_h = width - left - right, height - top - bottom
    aid = [[v - sum(row) / len(row) for v in row] for row in dc_p]
    pos = [sum(max(row[t], 0.0) for row in aid) for t in range(24)]
    neg = [sum(min(row[t], 0.0) for row in aid) for t in range(24)]
    net = [sum(row[t] for row in aid) for t in range(24)]
    ymax = max(max(pos), abs(min(neg))) * 1.15
    y0 = top + plot_h / 2
    bar_w = plot_w / 24 * 0.72
    parts = [f'<line x1="{left}" y1="{y0:.1f}" x2="{left+plot_w}" y2="{y0:.1f}" class="axisline"/>']
    for t in range(24):
        x = left + t * plot_w / 24 + (plot_w / 24 - bar_w) / 2
        hp = pos[t] / ymax * plot_h / 2
        hn = abs(neg[t]) / ymax * plot_h / 2
        parts.append(f'<rect x="{x:.1f}" y="{y0-hp:.1f}" width="{bar_w:.1f}" height="{hp:.1f}" fill="#4c78a8"/>')
        parts.append(f'<rect x="{x:.1f}" y="{y0:.1f}" width="{bar_w:.1f}" height="{hn:.1f}" fill="#f58518"/>')
        if t % 2 == 0:
            parts.append(f'<text x="{x + bar_w/2:.1f}" y="{height-30}" text-anchor="middle" class="axis">{t+1}</text>')
    xs = [left + (t + 0.5) * plot_w / 24 for t in range(24)]
    ys = [y0 - v / ymax * plot_h / 2 for v in net]
    parts.append(f'<path d="{line_path(xs, ys)}" fill="none" stroke="#111827" stroke-width="2"/>')
    parts.append(f'<text x="{left+plot_w/2}" y="{height-8}" text-anchor="middle" class="axis">Time (h)</text>')
    parts.append(f'<text x="18" y="{top+plot_h/2}" transform="rotate(-90 18 {top+plot_h/2})" text-anchor="middle" class="axis">Relative exchange (p.u.)</text>')
    legend = [("Absorb workload", "#4c78a8"), ("Release workload", "#f58518"), ("Net", "#111827")]
    for i, (label, color) in enumerate(legend):
        y = top + 14 + i * 24
        parts.append(f'<rect x="{width-right+20}" y="{y-11}" width="14" height="14" fill="{color}"/>')
        parts.append(f'<text x="{width-right+42}" y="{y}" class="legend">{label}</text>')
    save_svg(path, width, height, "Inter-park Mutual Aid from Workload Reallocation", "\n".join(parts))


def microgrid_power_svg(bench_dir: Path, path: Path) -> None:
    width, height = 980, 460
    left, top, right, bottom = 76, 62, 190, 58
    plot_w, plot_h = width - left - right, height - top - bottom
    thermal = read_vector(bench_dir / "res_thermalunits.txt")
    wind = read_vector(bench_dir / "res_windunits.txt")
    charge = read_vector(bench_dir / "res_BESS_charging.txt")
    discharge = read_vector(bench_dir / "res_BESS_discharging.txt")
    ddc = read_vector(bench_dir / "res_ddc.txt")
    storage = [d - c for d, c in zip(discharge, charge)]
    supply_minus_demand = [th + wi + dis - d - ch for th, wi, dis, d, ch in zip(thermal, wind, discharge, ddc, charge)]
    all_vals = thermal + wind + ddc + storage + supply_minus_demand
    ymin, ymax = min(all_vals), max(all_vals)
    ymin = min(ymin, 0.0)
    ymax *= 1.08
    xs = [left + i * plot_w / 23 for i in range(24)]

    def yvals(vals: list[float]) -> list[float]:
        return [top + plot_h - (v - ymin) / (ymax - ymin) * plot_h for v in vals]

    parts = []
    for g in range(5):
        y = top + g * plot_h / 4
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" class="grid"/>')
    zero_y = yvals([0.0])[0]
    parts.append(f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left+plot_w}" y2="{zero_y:.1f}" class="axisline"/>')
    series = [
        ("Thermal", thermal, "#8e6c8a"),
        ("Wind", wind, "#54a24b"),
        ("Data center load", ddc, "#4c78a8"),
        ("BESS net support", storage, "#e45756"),
        ("Supply - demand", supply_minus_demand, "#111827"),
    ]
    for label, values, color in series:
        parts.append(f'<path d="{line_path(xs, yvals(values))}" fill="none" stroke="{color}" stroke-width="2.4"/>')
    for t, x in enumerate(xs):
        if t % 2 == 0:
            parts.append(f'<text x="{x:.1f}" y="{height-30}" text-anchor="middle" class="axis">{t+1}</text>')
    parts.append(f'<text x="{left+plot_w/2}" y="{height-8}" text-anchor="middle" class="axis">Time (h)</text>')
    parts.append(f'<text x="18" y="{top+plot_h/2}" transform="rotate(-90 18 {top+plot_h/2})" text-anchor="middle" class="axis">Power (p.u.)</text>')
    for i, (label, _, color) in enumerate(series):
        y = top + 14 + i * 24
        parts.append(f'<rect x="{width-right+20}" y="{y-11}" width="14" height="14" fill="{color}"/>')
        parts.append(f'<text x="{width-right+42}" y="{y}" class="legend">{label}</text>')
    save_svg(path, width, height, "Microgrid Mutual Aid and Balance", "\n".join(parts))


def current_power_data(dc_p: list[list[float]]) -> tuple[list[dict[str, list[float]]], list[float], list[float]]:
    xlsx = ROOT / "data" / "data.xlsx"
    result = ROOT / "output" / "Bench_calculation_result.txt"
    mg_bus = {int(row[0]): int(row[1]) for row in sheet_numeric_rows(xlsx, "mg_bus_map")}
    units = sheet_numeric_rows(xlsx, "units_data")
    loads = sheet_numeric_rows(xlsx, "load_data")
    storage = sheet_numeric_rows(xlsx, "strogesystem_data")
    dcc = sheet_numeric_rows(xlsx, "data_centra")
    load_curve = [row[1] / 100.0 for row in sheet_numeric_rows(xlsx, "load_curve")]

    unit_p = parse_result_list(result, 2, len(units))
    wind_spill = parse_result_list(result, 3, 2)
    load_cut = parse_result_list(result, 4, len(loads))
    charge = parse_result_list(result, 7, len(storage))
    discharge = parse_result_list(result, 8, len(storage))

    wind_curve = [
        0.440724927203680, 0.420965256587272, 0.449034794022911, 0.454128108336623,
        0.436483077739172, 0.477450522402300, 0.443871634609799, 0.374756446192485,
        0.448192193924943, 0.431190577826877, 0.428867647037057, 0.445673091565042,
        0.433764408789611, 0.421900481861469, 0.429104412188035, 0.463277796146724,
        0.426579282372516, 0.448189506134410, 0.429353980231385, 0.434861266141317,
        0.437494540514197, 0.456877055120346, 0.425139803090161, 0.425629623577982,
    ]

    mg_count = max(mg_bus.values())
    data = [
        {
            "thermal": [0.0] * 24,
            "wind": [0.0] * 24,
            "load": [0.0] * 24,
            "dc": [0.0] * 24,
            "charge": [0.0] * 24,
            "discharge": [0.0] * 24,
            "cut": [0.0] * 24,
            "net": [0.0] * 24,
        }
        for _ in range(mg_count)
    ]

    for i, row in enumerate(units):
        mg = mg_bus[int(row[1])] - 1
        for t in range(24):
            data[mg]["thermal"][t] += unit_p[i][t]

    # The model defines two wind units at bus 1, each with 2.0 p.u. installed capacity.
    for i in range(2):
        mg = mg_bus[1] - 1
        for t in range(24):
            data[mg]["wind"][t] += 2.0 * wind_curve[t] - wind_spill[i][t]

    for i, row in enumerate(loads):
        mg = mg_bus[int(row[1])] - 1
        share = row[2]
        for t in range(24):
            data[mg]["load"][t] += load_curve[t] * share
            data[mg]["cut"][t] += load_cut[i][t]

    for i, row in enumerate(storage):
        mg = mg_bus[int(row[1])] - 1
        for t in range(24):
            data[mg]["charge"][t] += charge[i][t]
            data[mg]["discharge"][t] += discharge[i][t]

    for i, row in enumerate(dcc):
        mg = mg_bus[int(row[1])] - 1
        if i < len(dc_p):
            for t in range(24):
                data[mg]["dc"][t] += dc_p[i][t]

    for mg in data:
        for t in range(24):
            supply = mg["thermal"][t] + mg["wind"][t] + mg["discharge"][t]
            demand = mg["load"][t] - mg["cut"][t] + mg["dc"][t] + mg["charge"][t]
            mg["net"][t] = supply - demand

    tie_mg1_to_mg2 = data[0]["net"][:] if len(data) >= 2 else [0.0] * 24
    imbalance = []
    for t in range(24):
        vals = [row[t] for row in dc_p]
        avg = sum(vals) / len(vals)
        imbalance.append(math.sqrt(sum((v - avg) ** 2 for v in vals) / len(vals)))
    return data, tie_mg1_to_mg2, imbalance


def coupled_coordination_svg(dc_p: list[list[float]], path: Path) -> None:
    mg_data, tie, imbalance = current_power_data(dc_p)
    width, height = 1080, 760
    left, top, right, bottom = 82, 58, 190, 48
    panel_h, gap = 175, 34
    plot_w = width - left - right
    xs = [left + i * plot_w / 23 for i in range(24)]
    body: list[str] = []

    def panel_y(panel: int) -> int:
        return top + panel * (panel_h + gap)

    def draw_balance_panel(mg: dict[str, list[float]], panel: int, title: str) -> None:
        ytop = panel_y(panel)
        series = [
            ("thermal", "#8e6c8a", 1),
            ("wind", "#54a24b", 1),
            ("discharge", "#72b7b2", 1),
            ("load", "#9aa5b1", -1),
            ("dc", "#4c78a8", -1),
            ("charge", "#f58518", -1),
        ]
        vals = []
        for name, _, sign in series:
            vals.extend(sign * v for v in mg[name])
        limit = max(abs(v) for v in vals + mg["net"]) * 1.18 or 1.0
        zero_y = ytop + panel_h / 2
        body.append(f'<text x="{left}" y="{ytop-12}" class="legend" style="font-weight:700">{html.escape(title)}</text>')
        body.append(f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left+plot_w}" y2="{zero_y:.1f}" class="axisline"/>')
        for g in [-1, -0.5, 0.5, 1]:
            y = zero_y - g * panel_h / 2
            body.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" class="grid"/>')
        bar_w = plot_w / 24 * 0.64
        for t in range(24):
            x = left + t * plot_w / 24 + (plot_w / 24 - bar_w) / 2
            up, down = zero_y, zero_y
            for name, color, sign in series:
                h = mg[name][t] / limit * panel_h / 2
                if sign > 0:
                    up -= h
                    body.append(f'<rect x="{x:.1f}" y="{up:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{color}" opacity="0.86"/>')
                else:
                    body.append(f'<rect x="{x:.1f}" y="{down:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{color}" opacity="0.72"/>')
                    down += h
        ys = [zero_y - v / limit * panel_h / 2 for v in mg["net"]]
        body.append(f'<path d="{line_path(xs, ys)}" fill="none" stroke="#111827" stroke-width="2.3"/>')

    draw_balance_panel(mg_data[0], 0, "Microgrid 1 local balance: generation/storage vs load + data centers")
    if len(mg_data) > 1:
        draw_balance_panel(mg_data[1], 1, "Microgrid 2 local balance: generation vs native load")

    ytop = panel_y(2)
    limit = max(max(abs(v) for v in tie), max(imbalance) * 8.0) * 1.12 or 1.0
    zero_y = ytop + panel_h / 2
    body.append(f'<text x="{left}" y="{ytop-12}" class="legend" style="font-weight:700">Tie-line mutual aid and DCC load-balancing coordination</text>')
    body.append(f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left+plot_w}" y2="{zero_y:.1f}" class="axisline"/>')
    bar_w = plot_w / 24 * 0.66
    for t, value in enumerate(tie):
        x = left + t * plot_w / 24 + (plot_w / 24 - bar_w) / 2
        h = abs(value) / limit * panel_h / 2
        y = zero_y - h if value >= 0 else zero_y
        color = "#4c78a8" if value >= 0 else "#e45756"
        body.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{color}" opacity="0.82"/>')
        if t % 2 == 0:
            body.append(f'<text x="{x+bar_w/2:.1f}" y="{height-26}" text-anchor="middle" class="axis">{t+1}</text>')
    imb_scaled = [v * 8.0 for v in imbalance]
    ys = [zero_y - v / limit * panel_h / 2 for v in imb_scaled]
    body.append(f'<path d="{line_path(xs, ys)}" fill="none" stroke="#111827" stroke-width="2.5"/>')

    legends = [
        ("thermal", "#8e6c8a"), ("wind", "#54a24b"), ("storage discharge", "#72b7b2"),
        ("native load", "#9aa5b1"), ("data center load", "#4c78a8"), ("storage charge", "#f58518"),
        ("net / imbalance", "#111827"), ("MG1 export", "#4c78a8"), ("MG1 import", "#e45756"),
    ]
    for i, (label, color) in enumerate(legends):
        y = top + 8 + i * 24
        body.append(f'<rect x="{width-right+22}" y="{y-11}" width="14" height="14" fill="{color}"/>')
        body.append(f'<text x="{width-right+44}" y="{y}" class="legend">{html.escape(label)}</text>')
    body.append(f'<text x="{left+plot_w/2}" y="{height-6}" text-anchor="middle" class="axis">Time (h)</text>')
    body.append(f'<text x="20" y="{top+panel_h}" transform="rotate(-90 20 {top+panel_h})" text-anchor="middle" class="axis">Power balance (p.u.)</text>')
    save_svg(path, width, height, "Coupled Coordination of Microgrids and Data Centers", "\n".join(body))


def dashboard_html(outdir: Path, names: list[str]) -> None:
    cards = "\n".join(
        f'<section><h2>{html.escape(Path(name).stem)}</h2><img src="{html.escape(name)}" alt="{html.escape(name)}"></section>'
        for name in names
    )
    page = f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Current Result Visualization</title>
<style>
body {{ margin: 0; padding: 28px; font-family: Arial, 'Microsoft YaHei', sans-serif; color: #1f2933; background: #f5f7fa; }}
h1 {{ margin: 0 0 18px; font-size: 24px; }}
section {{ background: white; border: 1px solid #d9e2ec; border-radius: 8px; padding: 16px; margin: 0 0 18px; }}
h2 {{ margin: 0 0 12px; font-size: 16px; color: #334e68; }}
img {{ width: 100%; height: auto; display: block; }}
</style>
</head>
<body>
<h1>数据中心算力迁移与微电网园区互济可视化</h1>
{cards}
</body>
</html>"""
    (outdir / "dashboard.html").write_text(page, encoding="utf-8")


def main() -> None:
    dc_dir = ROOT / "output" / "data_centra" / "master-3(iter=12)"
    bench_dir = ROOT / "output" / "bench"
    outdir = ROOT / "output" / "visualization" / "current_results"
    outdir.mkdir(parents=True, exist_ok=True)

    dc_p = read_csv_matrix(dc_dir / "dc_p.csv")
    dc_fv2 = read_csv_matrix(dc_dir / "dc_fv².csv")
    dc_fv2lambda = read_csv_matrix(dc_dir / "dc_fv²λ.csv")
    dc_lambda = [[b / a if a else 0.0 for a, b in zip(row_a, row_b)] for row_a, row_b in zip(dc_fv2, dc_fv2lambda)]
    delta = [[v - sum(row) / len(row) for v in row] for row in dc_p]

    outputs = [
        "01_workload_migration.svg",
        "02_migration_delta_heatmap.svg",
        "03_dvfs_fv2_heatmap.svg",
        "04_effective_workload_fv2lambda_heatmap.svg",
        "05_lambda_heatmap.svg",
        "06_interpark_mutual_aid.svg",
        "07_microgrid_power_mutual_aid.svg",
        "08_coupled_microgrid_dcc_coordination.svg",
    ]
    stacked_workload_svg(dc_p, outdir / outputs[0])
    heatmap_svg(delta, outdir / outputs[1], "Migration Direction vs Daily Mean", "div")
    heatmap_svg(dc_fv2, outdir / outputs[2], "DVFS State", "seq")
    heatmap_svg(dc_fv2lambda, outdir / outputs[3], "Effective Workload after Migration", "seq")
    heatmap_svg(dc_lambda, outdir / outputs[4], "Migration Coefficient", "seq")
    interpark_aid_svg(dc_p, outdir / outputs[5])
    microgrid_power_svg(bench_dir, outdir / outputs[6])
    coupled_coordination_svg(dc_p, outdir / outputs[7])
    dashboard_html(outdir, outputs)

    totals = [sum(row[t] for row in dc_p) for t in range(24)]
    summary = [
        f"Data center result directory: {dc_dir}",
        f"Microgrid balance directory: {bench_dir}",
        f"DCC count: {len(dc_p)}",
        f"Time periods: {len(dc_p[0])}",
        f"Total DCC workload: {sum(sum(row) for row in dc_p):.6f} p.u.",
        f"Peak total DCC workload: {max(totals):.6f} p.u.",
        "Inter-park mutual aid is visualized as each DCC/park's deviation from its own daily mean workload.",
        "The coupled coordination figure infers tie-line mutual aid from each microgrid's local supply-demand surplus.",
    ]
    (outdir / "visualization_summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"Saved visualizations to: {outdir}")


if __name__ == "__main__":
    main()
