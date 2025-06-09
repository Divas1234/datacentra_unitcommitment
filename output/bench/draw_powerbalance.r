library(ggplot2)
library(tidyr)
library(ggstream)
library(areaplot)

# read data
loadcurve <- readr::read_table("output/bench/LoadCurve.txt", col_names = FALSE)
res_thermalunits <- readr::read_table("output/bench/res_thermalunits.txt", col_names = FALSE)
res_windunits <- readr::read_table("output/bench/res_windunits.txt", col_names = FALSE)
res_forced_load_curtailment <- readr::read_table("output/bench/res_forcedloadcurtailment.txt", col_names = FALSE)
res_bess_charging <- readr::read_table("output/bench/res_BESS_charging.txt", col_names = FALSE)
res_bess_discharging <- readr::read_table("output/bench/res_BESS_discharging.txt", col_names = FALSE)
res_ddc <- readr::read_table("output/bench/res_ddc.txt", col_names = FALSE)

res_loadcurve <- loadcurve$X2

# Define the desired stacking order from bottom to top
series_names <- c(
  "Wind",
  "Thermal",
  "Load Cutting",
  "BESS(Discharging)",
  "BESS(Charging)"
)

# Match the data to the desired order
mylist <- list(
  unlist(res_windunits),
  unlist(res_thermalunits),
  unlist(res_forced_load_curtailment),
  unlist(res_bess_discharging),
  unlist(res_bess_charging)
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

# Set the factor levels to the REVERSE of the desired stacking order
df_long$Series <- factor(df_long$Series, levels = rev(series_names))

# Make sure the BESS Charging Output is below the 0 line
df_long$Value <- ifelse(df_long$Series == "BESS(Charging)", -df_long$Value, df_long$Value)


# Beautify the stacked area plot
q <- ggplot(df_long, aes(x = Time, y = Value, fill = Series)) +
  geom_area(alpha = 0.85, color = "white", linewidth = 0.25) +
  scale_fill_manual(values = c(
    "Thermal" = "brown3", "Wind" = "darkgreen", "Load Cutting" = "blue",
    "BESS(Charging)" = "orange", "BESS(Discharging)" = "#226f6f"
  )) +
  scale_y_continuous(name = "Power (p.u.)", expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(name = "Time (h)", breaks = 1:24) +
  coord_cartesian(ylim = c(-0.5, 4)) +
  theme_bw(base_size = 16) +
  theme(
    legend.title = element_blank(),
    legend.text = element_text(size = 8),
    axis.title = element_text(size = 8),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"),
    panel.grid.minor = element_blank(),
    plot.margin = margin(20, 5, 20, 20),
    panel.grid.major.y = element_line(linewidth = 1),
    legend.margin = margin(0, 0, 0, 8),
    legend.box.spacing = unit(0, "pt")
  )

ggsave(plot = q, width = 6, height = 4, dpi = 300, filename = "output/bench/balanceprocess.pdf")
