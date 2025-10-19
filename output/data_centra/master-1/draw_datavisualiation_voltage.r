library(ggplot2)
library(dplyr)

# Read the CSV file
data <- read.csv("d://GithubClonefiles//datacentra_unitcommitment//output//data_centra//dc_v².csv")

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
  "DCC1" = "grey90", # Lighter
  "DCC2" = "grey75",
  "DCC3" = "grey70",
  "DCC4" = "grey65",
  "DCC5" = "grey60",
  "DCC6" = "grey55",
  "DCC7" = "grey50",
  "DCC8" = "grey40", # Darker
  "DCC9" = "grey45",
  "DCC10" = "grey35",
  "DCC11" = "grey30",
  "DCC12" = "grey25",
  "DCC13" = "grey20",
  "DCC14" = "grey15",
  "DCC15" = "grey10",
  "DCC16" = "grey5",
  "DCC17" = "grey80",
  "DCC18" = "grey85",
  "DCC19" = "grey45",
  "DCC20" = "grey35",
  "DCC21" = "grey30",
  "DCC22" = "grey25",
  "DCC23" = "grey20",
  "DCC24" = "grey15"
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
q = ggplot(spline.d, aes(x = time, y = workload, color = DCC)) +
  geom_line( linewidth = 0.95) +
  scale_fill_manual(values = dcc_colors) +
  scale_y_continuous(name = "Voltage (p.u.)", expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_bw(base_size = 16) +
  theme(
    # legend.position = c(0.8, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 10), # Larger legend text
    axis.title = element_text(size = 14), # Axis titles bigger
    axis.text = element_text(size = 12), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title =  element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 20, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 1)
)


# Save the plot to a PDF file
ggsave(plot = q, width = 8, height = 4, dpi = 300, filename = "d://GithubClonefiles//datacentra_unitcommitment//output//data_centra//stacked_dcc_v²_plot.pdf")