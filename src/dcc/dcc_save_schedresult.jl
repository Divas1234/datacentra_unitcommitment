function save_data_centra(res, num_sos, output_dir)
	data_to_write = [("dc_p.csv", (res["dc_p"][1:(ND2), 1:NT])),
		("dc_fv².csv", (res["dc_fv²"][1:(ND2), 1:NT])),
		("dc_fv²λ.csv", (res["dc_fv²λ"][1:(ND2), 1:NT])),
		("dc_fv²_plus.csv", (res["dc_fv²_plus"][1:(ND2), 1:NT])),
		("dc_λ.csv", (res["dc_fv²λ"][1:(ND2), 1:NT] ./ res["dc_fv²"][1:(ND2), 1:NT])),
		("dc_fv²_minus.csv", (res["dc_fv²_minus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²λ_plus.csv", (res["dc_fv²λ_plus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²λ_minus.csv", (res["dc_fv²λ_minus"][1:(ND2 * num_sos), 1:NT])),
		("dc_fv²_2_plus.csv", (res["dc_fv²_2_plus"][1:(ND2), 1:NT])),
		("dc_fv²_2_minus.csv", (res["dc_fv²_2_minus"][1:(ND2), 1:NT])),
		("dc_fv²λ_2_plus.csv", (res["dc_fv²λ_2_plus"][1:(ND2), 1:NT])),
		("dc_fv²λ_2_minus.csv", (res["dc_fv²λ_2_minus"][1:(ND2), 1:NT]))
		# ("weight_fv²_minus.csv", (res["weight_fv²_minus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²_plus.csv", (res["weight_fv²_plus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²λ_minus.csv", (res["weight_fv²λ_minus"][1:(ND2), 1:NT, 1:num_sos])),
		# ("weight_fv²λ_plus.csv", (res["weight_fv²λ_plus"][1:(ND2), 1:NT, 1:num_sos]))
	]

	for (filename, data) in data_to_write
		filepath = joinpath(output_dir, filename)
		try
            if !isdir(dirname(filepath))
                mkdir(dirname(filepath))
            end
			CSV.write(filepath, DataFrame(data, :auto),writeargs=(append=false,))
			println("→ Successfully wrote to $filepath")
		catch e
			@error "Failed to write to $filepath" exception=(e, catch_backtrace())
		end
	end
end
