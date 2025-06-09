# Load ggplot2 library
library(ggplot2)
library(tidyr)

# Data extracted from OCR
# punit1 <- c(12, 7, 5, 0, 0, 0, 0, 0, 3, 8, 13, 15, 15, 15, 13, 10, 7, 10, 13, 10, 5, 0, 0, 0)
# punit2 <- c(10, 8, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
# punit3 <- c(15, 20, 15, 10, 9, 15, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 15, 5, 0)

df <- read.csv("D:\\GithubClonefiles\\datacentra_unitcommitment\\fig\\boundaries_conditions\\workloads_jobdf.csv", header = TRUE)
df$Time <- 1:nrow(df)


# Time axis
time <- 1:24

# Create a data frame
# df <- data.frame(
#      Time = time,
#      Punit1 = punit1,
#      Punit2 = punit2,
#      Punit3 = punit3
# )

# Convert to long format for ggplot2
df_long <- tidyr::gather(df, key = "Punit", value = "PowerOutput", x1, x2, x3, x4, x5, x6, x7, x8)
df_long$Punit <- gsub("x", "DCC-", df_long$Punit)
df_long$Punit <- gsub("^0+", "", df_long$Punit)

# Define a colorblind-friendly palette
cbPalette <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999")

# Plotting the data with ggplot2
ggplot(df_long, aes(x = Time, y = PowerOutput, color = Punit)) +
     geom_line(linewidth = 0.75) +
     scale_color_manual(values = cbPalette) +
     scale_y_continuous(name = "Workload Balancing Rate (p.u.)", expand = expansion(mult = c(0, 0.1))) +
     scale_x_continuous(name = "Time (h)", breaks = 1:24) +
     coord_cartesian(ylim = c(0, 25)) +
     theme_bw(base_size = 16) + # Larger base font size
     theme(
          # legend.position = c(0.8, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
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
     )

# Saving the plot
ggsave("D:\\GithubClonefiles\\datacentra_unitcommitment\\fig\\boundaries_conditions\\workload_distribution.pdf", width = 6, height = 4, dpi = 300)
