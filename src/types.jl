# =============================================================================
# types.jl — Data structure definitions
# =============================================================================

"""
	Config

Configuration parameters for the unit commitment model.
"""
mutable struct Config
	is_NetWorkCon::Int64
	is_ThermalUnitCon::Int64
	is_WindUnitCon::Int64
	is_SysticalCon::Int64
	is_PieceLinear::Int64
	is_NumSeg::Int64
	is_Alpha::Float64
	is_Belta::Float64
	is_CoalPrice::Int64
	is_ActiveLoad::Int64
	is_WindIntegration::Int64
	is_LoadsCuttingCoefficient::Float64
	is_WindsCuttingCoefficient::Float64
	is_MaxIterationsNum::Int64
	is_CalculPrecision::Float64
	is_ConsiderDataCentra::Int64
end

"""
	Unit

Conventional thermal generator data, including frequency response parameters.
"""
struct Unit
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	ramp_up::Vector{Float64}
	ramp_down::Vector{Float64}
	shut_up::Vector{Float64}
	shut_down::Vector{Float64}
	min_up_time::Vector{Float64}
	min_down_time::Vector{Float64}
	x_0::Vector{Float64}
	t_0::Vector{Float64}
	p_0::Vector{Float64}
	coeff_a::Vector{Float64}
	coeff_b::Vector{Float64}
	coeff_c::Vector{Float64}
	cold_start_cost::Vector{Float64}
	cold_start_cost_2::Vector{Float64}
	cold_shutdown_cost::Vector{Float64}
	cold_shutdown_cost_2::Vector{Float64}

	# Frequency response parameters
	Hg::Vector{Float64}  # Inertia constant
	Dg::Vector{Float64}  # Damping constant
	Kg::Vector{Float64}  # Mechanical power gain
	Fg::Vector{Float64}  # Turbine power fraction
	Tg::Vector{Float64}  # Time constant
	Rg::Vector{Float64}  # Droop gain
end

"""
	TransmissionLine

Transmission line data for DC power flow.
"""
struct TransmissionLine
	index::Vector{Int64}
	from::Vector{Int64}
	to::Vector{Int64}
	x::Vector{Float64}       # Reactance
	p_max::Vector{Float64}   # Forward limit
	p_min::Vector{Float64}   # Reverse limit
end

"""
	Load

System load data with time-varying curve.
"""
struct Load
	index::Vector{Int64}
	locatebus::Vector{Int64}
	curve::Array{Float64}    # ND × NT load curve
end

"""
	Storage

Battery energy storage system parameters.
"""
struct Storage
	index::Vector{Int64}
	locatebus::Vector{Int64}
	Q_max::Vector{Float64}   # Max energy capacity
	Q_min::Vector{Float64}   # Min energy capacity
	p_charge::Vector{Float64} # Max charge power
	p_discharge::Vector{Float64} # Max discharge power
	P_init::Vector{Float64}  # Initial energy
	gamma_charge::Vector{Float64}  # Charging rate limit
	gamma_discharge::Vector{Float64} # Discharging rate limit
	eta_charge::Vector{Float64}   # Charging efficiency
	eta_discharge::Vector{Float64} # Discharging efficiency
	delta_self::Vector{Float64}   # Self-discharge rate
end

"""
	Wind

Wind farm data including frequency control mode parameters.
"""
struct Wind
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	prob::Float64          # Scenario probability
	num_scenarios::Int64
	curve::Array{Float64}  # scenarios_nums × NT
	FCmode::Vector{Float64}
	Kw::Vector{Float64}
	Rw::Vector{Float64}
	Mw::Vector{Float64}
	Dw::Vector{Float64}
	Tw::Vector{Float64}
end

"""
	DataCenter

Data center / cloud computing workload parameters for DVFS scheduling.
"""
struct DataCenter
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	voltage_regulation::Vector{Float64}
	idle_power::Vector{Float64}
	sv_constant::Vector{Float64}   # DVFS constant
	lambda::Vector{Float64}        # Workload-to-power factor
	mu::Vector{Float64}            # Utilization factor
	computational_power_tasks::Matrix{Float64}  # ND2 × NT workload matrix
end
