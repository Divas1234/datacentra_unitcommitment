library(ggplot2)
library(dplyr)

# Read the CSV file
data <- read.csv("d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/dc_p.csv")

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

# Define custom colors using a darker blue gradient with hex codes
num_dccs <- 24
grey_palette <- colorRampPalette(c("#e0e0e0", "#212121")) # LightGrey to DarkGrey
dcc_colors <- grey_palette(num_dccs)
names(dcc_colors) <- paste0("DCC", 1:num_dccs)

# Create the stacked bar plot
q <- ggplot(data_long, aes(x = time, y = workload, fill = DCC)) +
  geom_bar(stat = "identity", color = "black", linewidth = 0.2, width = 0.75) +
  scale_fill_manual(values = dcc_colors) +
  scale_y_continuous(name = "Power (p.u.)", expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  coord_cartesian(ylim = c(0, 0.75)) +
  theme_bw(base_size = 16) + # Larger base font size
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
ggsave(plot = q, width = 8, height = 4, dpi = 300, filename = "d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/stacked_dcc_p_plot.pdf")
