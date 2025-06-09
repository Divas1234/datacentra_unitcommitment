library(ggplot2)
library(tidyr)
library(dplyr)

# Read the data
wind_data <- read.csv("windsimulation_curve.csv", header = FALSE)

# Transpose the data
transposed_data <- as.data.frame(t(wind_data))

# Add a time step column
transposed_data <- transposed_data %>% mutate(time = 1:n())

# Reshape data from wide to long format for plotting
transposed_data_long <- transposed_data %>%
  pivot_longer(cols = -time, names_to = "simulation", values_to = "power") %>%
  mutate(power = as.numeric(power))

# Create the plot
wind_plot <- ggplot(transposed_data_long, aes(x = time, y = power, group = simulation)) +
  geom_line(alpha = 0.5, linewidth = 0.35) + # Use alpha for transparency to see overlapping lines
  labs(
    title = "Transposed Wind Simulation Curves",
    x = "Time Step",
    y = "Power Output (p.u.)"
  ) +
  coord_cartesian(ylim = c(0.35, 0.5)) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  theme_bw(base_size = 16) + # Larger base font size
  theme(
    legend.position = "none",
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 8), # Larger legend text
    axis.title = element_text(size = 8), # Axis titles bigger
    axis.text = element_text(size = 8), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 5, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 1),
    legend.margin = margin(0, 0, 0, 8),
    legend.box.spacing = unit(0, "pt")
  ) # Remove legend

# Save the plot
# ggsave("windsimulation_curve.pdf", plot = wind_plot, width = 10, height = 6)
ggsave("D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\windscurve_result.pdf", width = 6, height = 4, dpi = 300)
print("Plot saved to windsimulation_curve.pdf")
