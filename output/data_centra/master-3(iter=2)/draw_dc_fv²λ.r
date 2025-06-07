library(ggplot2)
library(dplyr)

# Read the CSV file
data <- read.csv("d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/dc_fv²λ.csv")

# Transpose the data
data_transposed <- t(data)

# Convert to data frame
data_transposed <- as.data.frame(data_transposed)

# Add column names
colnames(data_transposed) <- paste0("DCC", 1:ncol(data_transposed))

# Add time column
data_transposed$time <- 1:nrow(data_transposed)

# Convert to long format for ggplot2
data_long <- data_transposed %>%
  tidyr::pivot_longer(cols = starts_with("DCC"), names_to = "DCC", values_to = "workload")

# Define custom grey colors
dcc_colors <- c(
  "DCC1" = "#1f77b4", "DCC2" = "#ff7f0e", "DCC3" = "#2ca02c", "DCC4" = "#d62728",
  "DCC5" = "#9467bd", "DCC6" = "#8c564b", "DCC7" = "#e377c2", "DCC8" = "#7f7f7f",
  "DCC9" = "#bcbd22", "DCC10" = "#17becf", "DCC11" = "#aec7e8", "DCC12" = "#ffbb78",
  "DCC13" = "#98df8a", "DCC14" = "#ff9896", "DCC15" = "#c5b0d5", "DCC16" = "#c49c94",
  "DCC17" = "#f7b6d2", "DCC18" = "#c7c7c7", "DCC19" = "#dbdb8d", "DCC20" = "#9edae5",
  "DCC21" = "#393b79", "DCC22" = "#637939", "DCC23" = "#8c6d31", "DCC24" = "#843c39"
)


# Apply linear interpolation to add more data points
new_time <- seq(min(data_long$time), max(data_long$time), length.out = 200)

spline.d <- data_long %>%
  group_by(DCC) %>%
  do({
    approx_result <- approx(.$time, .$workload, xout = new_time)
    data.frame(time = approx_result$x, workload = approx_result$y, DCC = .$DCC[1])
  }) %>%
  ungroup()
# Create the stacked bar plot
q <- ggplot(spline.d, aes(x = time, y = workload, color = DCC)) +
  geom_line(linewidth = 0.95) +
  scale_color_manual(values = dcc_colors) +
  scale_y_continuous(name = expression(paste(("F · V"^{2}), " · ", lambda, " (p.u.)")), expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  coord_cartesian(ylim = c(0, 2)) +
  theme_bw(base_size = 16) +
  theme(
    # legend.position = c(0.8, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 10), # Larger legend text
    axis.title = element_text(size = 14), # Axis titles bigger
    axis.text = element_text(size = 12), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 20, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 1)
  )


# Save the plot to a PDF file
ggsave(plot = q, width = 8, height = 4, dpi = 300, filename = "d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/stacked_dc_fv²λ.pdf")
