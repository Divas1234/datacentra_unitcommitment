library(ggplot2)
library(tidyplots)
data1 <- readr::read_table("D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\LoadCurve.txt", col_names = FALSE)
head(data1)

ggplot(data1, aes(x = X1, y = X2)) +
    geom_line(color = "steelblue", linewidth = 1) + # 设置线的颜色和粗细
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
    geom_col(fill = "gray60", color = "black", width = 0.75) +
    scale_y_continuous(name = "Power (p.u.)", expand = expansion(mult = c(0, 0.1))) +
    scale_x_continuous(name = "Time (h)", breaks = 1:24) +
    annotate(
        geom = "text", label = "Load Curve", x = Inf, y = Inf, vjust = 1.5, hjust = 1.1,
        size = 14 / .pt
    ) +
    theme_bw() +
    theme(
        panel.grid.minor = element_blank(),
        axis.title = element_text(size = 14),
        axis.text = element_text(size = 12),
        panel.grid.major.y = element_line(linewidth = 2)
    )

ggsave(plot = q, width = 8, height = 3, dpi = 300, filename = "D:\\GithubClonefiles\\datacentra_unitcommitment\\output\\bench\\loadcurve.pdf")
