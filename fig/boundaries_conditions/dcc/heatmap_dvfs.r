# Load necessary libraries
library(ggplot2)
library(reshape2) # For melt function

# Read the z matrix from the CSV file
z <- as.matrix(read.csv("fig/boundaries_conditions/dcc/z_matrix.csv", header = FALSE))

# Define x and y vectors as in the Julia script for correct data mapping
x_julia <- seq(0.25, 1.5, by = 0.05)
y_julia <- x_julia * 1.25

# Assign dimnames for melting
dimnames(z) <- list(x_julia, y_julia)

# Melt the matrix into a long format data frame for ggplot2
df_plot <- melt(z, varnames = c("X", "Y"), value.name = "Value")


# Create the heatmap plot
heatmap_plot <- ggplot(df_plot, aes(x = X, y = Y, fill = Value)) +
  geom_tile(color = "white", linewidth = 0.5, alpha = 0.9) + # Use geom_tile for heatmap with white grid and less transparency
  scale_fill_gradient(low = "lightgrey", high = "black") + # Use a grayscale color scheme
  labs(
    x = "Frequency (GHz)",
    y = "Voltage (V)",
    fill = "Power (W)"
  ) +
  xlim(0.5, 1.5) +
  ylim(0.85, 1.25) +
  theme_minimal(base_size = 14) + # Increase base font size
  theme(
    # axis.title = element_text(face = "bold"),
    # legend.title = element_text(face = "bold"),
    legend.title = element_text(size = 8),
    # legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 8), # Larger legend text
    axis.title = element_text(size = 8), # Axis titles bigger
    axis.text = element_text(size = 8), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(2, 2, 5, 5), # Reduce margin around the plot
    panel.grid.major.y = element_line(linewidth = 1)
  ) +
  coord_fixed(ratio = 1) # Ensure aspect ratio is fixed

# Print the plot to the default device (e.g., RStudio Plots pane)
print(heatmap_plot)

# Optionally, save the plot to a file
ggsave("fig/boundaries_conditions/dcc/dvfs_heatmap.pdf", plot = heatmap_plot, width = 4, height = 4)
ggsave("fig/boundaries_conditions/dcc/dvfs_heatmap.png", plot = heatmap_plot, width = 4, height = 4, dpi = 300)

cat("Heatmap plot saved as dvfs_heatmap.pdf and dvfs_heatmap.png in fig/boundaries_conditions/dcc/\n")
