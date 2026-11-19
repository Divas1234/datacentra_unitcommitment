# =============================================================================
# powerflow.jl — DC power flow and Generation Shift Distribution Factors
# =============================================================================

"""
	compute_linear_powerflow(unit, lines, load, NG, NB, ND, NL)

Compute the DC power flow GSDF (Generation Shift Distribution Factors) matrix.
Returns `(G2B, D2B, GSDF)`.
"""
function compute_linear_powerflow(unit::Unit, lines::TransmissionLine,
                                   load::Load, NG::Int64, NB::Int64,
                                   ND::Int64, NL::Int64)
	B = zeros(NB, NB)
	M = zeros(NB, NL)

	for k in 1:NL
		n1 = lines.from[k]
		n2 = lines.to[k]
		M[n1, k] = 1
		M[n2, k] = -1
		inv_x = 1.0 / lines.x[k]
		B[n1, n1] += inv_x
		B[n2, n2] += inv_x
		B[n1, n2] -= inv_x
		B[n2, n1] -= inv_x
	end

	G2B = zeros(NB, NG)
	D2B = zeros(NB, ND)

	for i in 1:NG
		G2B[unit.locatebus[i], i] = 1
	end
	for i in 1:ND
		D2B[load.locatebus[i], i] = 1
	end

	slack = 1

	# Reduced B matrix (remove slack bus row/col)
	B1 = zeros(NB - 1, NB - 1)
	if slack == 1
		B1[:, :] = B[2:NB, 2:NB]
	else
		B1[1:slack-1, :] = B[1:slack-1, 2:NB]
		B1[slack:NB-1, :] = B[slack+1:NB, 2:NB]
	end

	M1 = M[1:NB .!= slack, :]

	# PTDF matrix
	T1 = M1' / B1
	for k in 1:(NB - 1)
		T1[:, k] ./= lines.x
	end

	GSDF = zeros(NL, NB)
	if slack == 1
		GSDF[:, (slack+1):NB] = T1[:, slack:(NB-1)]
	else
		GSDF[:, 1:slack-1] = T1[:, 1:slack-1]
		GSDF[:, slack+1:NB] = T1[:, slack:NB-1]
	end

	return G2B, D2B, GSDF
end
