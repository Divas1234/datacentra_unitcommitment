library(ggplot2)
library(dplyr)
library(tidyr)

# Read the CSV file
data <- read.csv("D:\\GithubClonefiles\\datacentra_unitcommitment\\vis\\dc_fv².csv")

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
  geom_line(aes(color = DCC), linewidth = 0.5, show.legend = FALSE) +
  scale_color_manual(values = rep("#5f7078", length(unique(data_long$DCC)))) +
  geom_point(shape = 1, size = 2) +
  geom_text(
    data = label_data,
    aes(label = label),
    x = 1,
    y = Inf,
    hjust = 0.1,
    vjust = 1.5,
    show.legend = FALSE,
    size = 3,
    color = "#3732b5",
    fontface = "bold"
  ) +
  facet_grid(DCC ~ ., scales = "free_y") +
  labs(
    x = "Time (h)",
    y = expression(paste(("F · V"^{
      2
    }), " (p.u.)"))
  ) +
  scale_x_continuous(breaks = 1:24, expand = c(0.05, 0.05)) +
  theme_bw(base_size = 10) +
  theme(
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 8), # Larger legend text
    axis.title = element_text(size = 8), # Axis titles bigger
    axis.text = element_text(size = 8), # Axis labels bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 20, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 0.5),
    strip.background = element_blank(),
    strip.text.y = element_blank()
  )


# Save the plot to a PDF file
ggsave(plot = p, width = 5, height = 6, dpi = 300, filename = "D:\\GithubClonefiles\\datacentra_unitcommitment\\vis\\stacked_dc_fv_subplots.pdf")
