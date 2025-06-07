library(ggplot2)
library(tidyr)
library(ggstream)
library(areaplot)

# read data
loadcurve <- readr::read_table(
  "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\LoadCurve.txt",
  col_names = FALSE
)
res_thermalunits <- readr::read_table(
  "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\res_thermalunits.txt",
  col_names = FALSE
)
res_windunits <- readr::read_table(
  "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\res_windunits.txt",
  col_names = FALSE
)
res_forced_load_curtailment <- readr::read_table(
  paste0(
    "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\",
    "res_forcedloadcurtailment.txt"
  ),
  col_names = FALSE
)
res_bess_charging <- readr::read_table(
  paste0(
    "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\",
    "res_BESS_charging.txt"
  ),
  col_names = FALSE
)
res_bess_discharging <- readr::read_table(
  paste0(
    "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\",
    "res_BESS_discharging.txt"
  ),
  col_names = FALSE
)
res_ddc <- readr::read_table(
  paste0(
    "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\",
    "res_ddc.txt"
  ),
  col_names = FALSE
)

res_loadcurve <- loadcurve$X2

typeof(loadcurve)

head(loadcurve)
head(res_thermalunits)

mylist <- list(
  unlist(res_thermalunits),
  unlist(res_windunits),
  unlist(res_forced_load_curtailment),
  unlist(res_bess_charging),
  unlist(res_bess_discharging)
)

series_names <- factor(series_names, levels = c("Thermal Generator", "Wind Farms", "Forced Load Curtailment", "BESS Charging Power", "BESS Discharging Output"))
if (length(series_names) != length(mylist)) {
  stop("The number of series names doesn't match the number of lists.")
}

series_names <- c(
  "Thermal",
  "Wind",
  "Forced Load",
  "BESS(Charging)",
  "BESS(Discharging)"
)

# Create data frame
df <- data.frame(
  Time = 1:dim(res_thermalunits)[1]
)

# Add each list as a new series in the data frame
for (i in seq_along(mylist)) {
  df[[series_names[i]]] <- mylist[[i]]
}

# Convert to long format for ggplot2
df_long <- pivot_longer(
  df,
  cols = -Time,
  names_to = "Series",
  values_to = "Value"
)

# Make sure the BESS Charging Output is below the 0 line
df_long$Value <- ifelse(df_long$Series == "BESS(Charging)", -df_long$Value, df_long$Value)


# Beautify the stacked area plot with y-axis limits from 0 to 3
q <- ggplot(df_long, aes(x = Time, y = Value, fill = Series)) +
  # Stacked area plot (ggplot will stack the areas automatically)
  geom_area(alpha = 0.85, color = "white", linewidth = 0.25) +
  scale_fill_manual(values = c(
    "Thermal" = "brown3", "Wind" = "darkgreen", "Load Cut" = "blue",
    "BESS(Charging)" = "orange", "BESS(Discharging)" = "cyan"
  )) +
  scale_y_continuous(name = "Power (p.u.)", expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  coord_cartesian(ylim = c(-0.5, 3.5)) +
  theme_bw(base_size = 16) + # Larger base font size
  theme(
    # legend.position = c(0.8, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
    legend.position = "right",
    legend.title = element_blank(), # Larger legend title
    legend.text = element_text(size = 10), # Larger legend text
    axis.title = element_text(size = 14), # Axis titles bigger
    axis.text = element_text(size = 12), # Axis labels bigger
    # legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_text(size = 18, face = "bold"), # Title size and bold
    panel.grid.major = element_line(size = 0.5, color = "gray90"), # Lighter grid lines
    panel.grid.minor = element_blank(), # No minor grid lines
    plot.margin = margin(20, 20, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 1)
  )

ggsave(plot = q, width = 10, height = 5, dpi = 300, filename = "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\balanceprocess.pdf")
