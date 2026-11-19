# =============================================================================
# io.jl — Excel data reading and input data formatting
# =============================================================================

"""
	read_excel_sheets([filepath])

Read all sheets from the Excel data file and return parsed arrays.
Defaults to `data/data.xlsx` relative to the project root.
"""
function read_excel_sheets(filepath = default_data_path())
	println("Step-1: Reading Excel data...")

	df = XLSX.readxlsx(filepath)

	# Part 1: Frequency parameters
	units_freq = df["units_frequencyparam"]
	winds_freq = df["winds_frequencyparam"]
	units_freq = _sheet_to_matrix(units_freq, "A2:G")
	winds_freq = _sheet_to_matrix(winds_freq, "A2:F")

	# Part 2: Storage system data
	storage_data = df["strogesystem_data"]
	storage_data = _sheet_to_matrix(storage_data, "A2:L")

	# Part 3: Generator, network, and load data
	gen_data = df["units_data"]
	gen_data = _sheet_to_matrix(gen_data, "A2:M")

	gen_cost = df["units_cost"]
	gen_cost = _sheet_to_matrix(gen_cost, "A2:H")

	branch_data = df["branch_data"]
	branch_data = _sheet_to_matrix(branch_data, "A2:E")

	load_curve = df["load_curve"]
	load_curve = _sheet_to_matrix(load_curve, "A2:B")

	load_data = df["load_data"]
	load_data = _sheet_to_matrix(load_data, "A2:C")

	# Part 4: Data center data
	dc_data = df["data_centra"]
	dc_data = _sheet_to_matrix(dc_data, "A2:I")

	dc_job_curve = df["data_centra_jobcurve"]
	dc_job_curve = _sheet_to_matrix_full(dc_job_curve)

	println("  ✓ All sheets loaded from $(basename(filepath))")
	return units_freq, winds_freq, storage_data, gen_data, gen_cost,
	       branch_data, load_curve, load_data, dc_data, dc_job_curve
end

"""
	default_data_path()

Return the canonical path to the Excel data file.
"""
function default_data_path()
	return joinpath(@__DIR__, "..", "data", "data.xlsx")
end

"""
	_sheet_to_matrix(sheet, range_prefix)

Convert an XLSX sheet range to a Float64 matrix.
"""
function _sheet_to_matrix(sheet, range_prefix)
	nrows = size(sheet[:], 1)
	full_range = string(range_prefix, string(nrows))
	return convert(Array{Float64,2}, sheet[full_range])
end

"""
	_sheet_to_matrix_full(sheet)

Convert the used range of an XLSX sheet (from A2) to a Float64 matrix.
"""
function _sheet_to_matrix_full(sheet)
	data = sheet[:]
	nrows, ncols = size(data)
	nrows < 2 && error("Sheet has no data rows")
	# Skip header row; keep all used columns
	return convert(Array{Float64,2}, Float64.(coalesce.(data[2:end, 1:ncols], NaN)))
end

"""
	_normalize_dc_job_curve(raw, ND2, NT)

Normalize DC job-curve sheet to an `ND2 × NT` matrix (pu).
Accepts either orientation (`ND2×NT` or `NT×ND2`), drops an optional ID
column/row, then pads/truncates the time dimension to `NT`.
"""
function _normalize_dc_job_curve(raw, ND2::Int, NT::Int)
	mat = convert(Array{Float64,2}, raw)
	# Drop empty trailing columns
	while size(mat, 2) > 1 && all(isnan, mat[:, end])
		mat = mat[:, 1:end-1]
	end
	# Drop empty trailing rows
	while size(mat, 1) > 1 && all(isnan, mat[end, :])
		mat = mat[1:end-1, :]
	end
	# Drop leading ID column when present (1,2,...,n)
	if size(mat, 2) > 1
		ids = mat[:, 1]
		if all(x -> isfinite(x) && isinteger(x), ids) && ids == Float64.(1:size(mat, 1))
			mat = mat[:, 2:end]
		end
	end
	# Drop leading ID row when present
	if size(mat, 1) > 1
		ids = mat[1, :]
		if all(x -> isfinite(x) && isinteger(x), ids) && ids == Float64.(1:size(mat, 2))
			mat = mat[2:end, :]
		end
	end
	any(isnan, mat) && error("DC job curve contains non-numeric / empty cells")
	mat = mat ./ 100

	nrows, ncols = size(mat)
	if nrows == ND2 && ncols != ND2
		# already ND2 × time
		nothing
	elseif ncols == ND2 && nrows != ND2
		# time × ND2 → transpose to ND2 × time
		mat = Matrix(mat')
	elseif nrows == NT && ncols == ND2
		mat = Matrix(mat')
	elseif nrows == ND2 && ncols == NT
		nothing
	else
		error("DC job curve size $(size(mat)) cannot map to ND2=$ND2, NT=$NT")
	end

	nrows, ncols = size(mat)
	nrows == ND2 || error("DC job curve rows ($nrows) != ND2 ($ND2) after orientation fix")

	if ncols < NT
		@warn "DC job curve has $ncols time columns < NT=$NT; padding with last column"
		mat = hcat(mat, repeat(mat[:, end:end], 1, NT - ncols))
	elseif ncols > NT
		@warn "DC job curve has $ncols time columns > NT=$NT; truncating to first $NT"
		mat = mat[:, 1:NT]
	end
	return mat
end

"""
	format_input_data(gen_data, branch_data, load_data, load_curve, gen_cost,
	                  units_freq, storage_data, dc_data, dc_job_curve)

Convert raw Excel data into typed Julia structs.
"""
function format_input_data(gen_data, branch_data, load_data, load_curve,
                           gen_cost, units_freq, storage_data, dc_data, dc_job_curve)

	NT = 24  # Number of time periods (fixed)
	NG = Int64(size(gen_data, 1))
	NL = Int64(size(branch_data, 1))
	NB = Int64(max(maximum(branch_data[:, 2]), maximum(branch_data[:, 3])))
	ND = Int64(size(load_data, 1))
	NC = Int64(size(storage_data, 1))

	# --- Generator data ---
	idx   = convert(Array{Int64},   gen_data[:, 1])
	bus   = convert(Array{Int64},   gen_data[:, 2])
	pmax  = gen_data[:, 3] / 100
	pmin  = gen_data[:, 4] / 100
	rd    = gen_data[:, 5] / 100
	ru    = gen_data[:, 6] / 100
	sd    = gen_data[:, 7] / 100
	su    = gen_data[:, 8] / 100
	tu    = gen_data[:, 9]
	td    = gen_data[:, 10]
	x0    = gen_data[:, 11]
	t0    = gen_data[:, 12]
	p0    = gen_data[:, 13] / 100

	# Cost coefficients (note scaling)
	c     = gen_cost[:, 2]
	b     = gen_cost[:, 3] * 1e2
	a     = gen_cost[:, 4] * 1e4
	cd    = gen_cost[:, 5]
	cu    = gen_cost[:, 6]
	cu1   = gen_cost[:, 7]
	cold  = gen_cost[:, 8]

	# Frequency params
	Hg = units_freq[:, 2]
	Dg = units_freq[:, 3]
	Kg = units_freq[:, 4]
	Fg = units_freq[:, 5]
	Tg = units_freq[:, 6]
	Rg = units_freq[:, 7]

	unit = Unit(idx, bus, pmax, pmin, ru, rd, su, sd, tu, td, x0, t0, p0,
	            a, b, c, cu, cu1, cd, cold, Hg, Dg, Kg, Fg, Tg, Rg)

	# --- Transmission lines ---
	t_idx  = convert(Array{Int64}, branch_data[:, 1])
	t_from = convert(Array{Int64}, branch_data[:, 2])
	t_to   = convert(Array{Int64}, branch_data[:, 3])
	t_x    = branch_data[:, 4]
	t_pmax = branch_data[:, 5] / 100
	t_pmin = -branch_data[:, 5] / 100

	line = TransmissionLine(t_idx, t_from, t_to, t_x, t_pmax, t_pmin)

	# --- Loads ---
	l_idx   = convert(Array{Int64}, load_data[:, 1])
	l_bus   = convert(Array{Int64}, load_data[:, 2])
	l_pct   = load_data[:, 3]
	l_total = load_curve[:, 2] / 100

	l_curve = zeros(ND, NT)
	for t in 1:NT
		l_curve[:, t] = l_total[t] .* l_pct
	end

	load = Load(l_idx, l_bus, l_curve)

	# --- Storage ---
	s_idx   = convert(Array{Int64}, storage_data[:, 1])
	s_bus   = convert(Array{Int64}, storage_data[:, 2])
	s_qmax  = storage_data[:, 3] / 100
	s_qmin  = storage_data[:, 4] / 100
	s_pch   = storage_data[:, 5] / 100
	s_pdis  = storage_data[:, 6] / 100
	s_p0    = storage_data[:, 7] / 100
	s_gch   = storage_data[:, 8] / 100
	s_gdis  = storage_data[:, 9] / 100
	s_ech   = storage_data[:, 10]
	s_edis  = storage_data[:, 11]
	s_delta = storage_data[:, 12]

	storage = Storage(s_idx, s_bus, s_qmax, s_qmin, s_pch, s_pdis, s_p0,
	                  s_gch, s_gdis, s_ech, s_edis, s_delta)

	# --- Data center ---
	dc_idx    = convert(Array{Int64}, dc_data[:, 1])
	dc_bus    = convert(Array{Int64}, dc_data[:, 2])
	dc_pmax   = dc_data[:, 3] / 100
	dc_pmin   = dc_data[:, 4] / 100
	dc_vreg   = dc_data[:, 5]
	dc_idle   = dc_data[:, 6]
	dc_sv     = dc_data[:, 7]
	dc_lambda = dc_data[:, 8]
	dc_mu     = dc_data[:, 9]

	ND2 = size(dc_idx, 1)
	dc_job_curve = _normalize_dc_job_curve(dc_job_curve, ND2, NT)

	dc = DataCenter(dc_idx, dc_bus, dc_pmax, dc_pmin, dc_vreg, dc_idle,
	                dc_sv, dc_lambda, dc_mu, dc_job_curve)

	# --- Config (legacy default: DC on, network constraints off) ---
	# Network can be enabled via config.is_NetWorkCon = 1 after formatting.
	config = Config(0, 1, 1, 1, 1, 3, 0.005, 0.005, 1, 1, 1,
	                1e5, 1e5, 50, 0.01, 1)

	println("Step-2: Input data formatted successfully")
	return config, unit, line, load, storage, NB, NG, NL, ND, NT, NC, ND2, dc
end
