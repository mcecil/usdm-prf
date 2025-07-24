# Load required libraries
library(ggplot2)
library(readr)  # for reading CSVs
library(dplyr)  # optional, for data manipulation

# Read your data
data <- read_csv("/Users/mjcecil/Documents/data.csv")

# Ensure USDM is treated as an ordered factor for consistent grouping
data$USDM <- factor(data$USDM, levels = c("None", "D0", "D1", "D2", "D3", "D4"), ordered = TRUE)

# Create the plot
ggplot(data, aes(x = USDM, y = PRF, label = Year)) +
  geom_jitter(width = 0.2, height = 0, size = 3, color = "steelblue") +  # jitter to avoid overlap
  geom_text(vjust = -0.7, size = 3) +  # year labels
  geom_hline(yintercept = c(0.7, 0.9), linetype = "dashed", color = "red") +  # threshold lines
  scale_y_continuous(limits = c(0, 2)) +
  labs(title = "PRF Index by USDM Drought Classification",
       x = "USDM Drought Classification",
       y = "PRF Index") +
  theme_minimal()
