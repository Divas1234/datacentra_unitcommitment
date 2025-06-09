library(ggplot2)
library(dplyr)
library(tidyr)

# Read the CSV file
data <- read.csv("d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/dc_λ.csv")

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
  pivot_longer(cols = starts_with("DCC"), names_to = "DCC", values_to = "workload")

# Create data for placing labels at the top-left of each facet
label_data <- data_long %>%
  group_by(DCC) %>%
  summarise(
    time = min(time),
    workload = max(workload),
    label = first(DCC),
    .groups = "drop"
  )

# Create the plot with facets
p <- ggplot(data_long, aes(x = time, y = workload)) +
  geom_col(aes(fill = DCC), show.legend = FALSE) +
  geom_text(
    data = label_data,
    aes(label = label),
    x = 1,
    y = Inf,
    hjust = -0.1,
    vjust = 1.5,
    show.legend = FALSE,
    size = 4,
    color = "black"
  ) +
  facet_grid(DCC ~ ., scales = "free_y") +
  labs(
    x = "Time (h)",
    y = expression(paste(lambda, " (p.u.)"))
  ) +
  scale_x_continuous(breaks = 1:24, expand = c(0.05, 0.05)) +
  theme_bw(base_size = 16) +
  theme(
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 10), # Larger legend text
    axis.title = element_text(size = 14), # Axis titles bigger
    axis.text = element_text(size = 12), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 20, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 1),
    strip.background = element_blank(),
    strip.text.y = element_blank()
  )

# Save the plot to a PDF file
ggsave(plot = p, width = 8, height = 10, dpi = 300, filename = "d:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/master-3(ITER=6)/stacked_dc_λ_subplots.pdf")
