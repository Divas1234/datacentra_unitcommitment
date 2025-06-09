library(ggplot2)
library(tidyplots)
data1 <- readr::read_table("D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\LoadCurve.txt", col_names = FALSE)
head(data1)

ggplot(data1, aes(x = X1, y = X2)) +
    geom_line(color = "steelblue", linewidth = 0) + # 设置线的颜色和粗细
    labs(
        title = "Power Output Over Time", # 标题
        x = "Time / h", # x 轴标签
        y = "Power / p.u." # y 轴标签
    ) +
    theme_bw(base_size = 14) +
    theme(
        plot.title = element_text(hjust = 0.5, face = "bold"),
        axis.title = element_text(face = "bold"),
        axis.text = element_text(color = "black")
    )

q <- ggplot(data1, aes(x = X1, y = X2)) +
    geom_col(fill = "gray60", color = "#ede6e6", width = 0.75) +
    scale_y_continuous(name = "Power (p.u.)", expand = expansion(mult = c(0, 0.1))) +
    scale_x_continuous(name = "Time (h)", breaks = 1:24) +
    annotate(
        geom = "text", label = "Load Curve", x = Inf, y = Inf, vjust = 1.5, hjust = 1.1,
        size = 10 / .pt
    ) +
    theme_bw(base_size = 10) + # Larger base font size
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

ggsave(plot = q, width = 6, height = 4, dpi = 300, filename = "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\loadcurve.pdf")
