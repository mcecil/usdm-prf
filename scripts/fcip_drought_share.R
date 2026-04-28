# FCIP Drought Share Analysis
# Expects a CSV with columns: Year, Peril_group, Billion_USD
# Adjust column names to match your actual CSV header

library(dplyr)
library(readr)

# --- Load data ---
# Change the filename/path as needed
fcip <- read_csv("/Users/mjcecil/Downloads/fcip_indemnities_by_cause_of_loss (1).csv")

# --- Clean column names (adjust if yours differ) ---
# Expected: Year, Peril_group, Billion_USD
colnames(fcip) <- c("Year", "Peril_group", "Billion_USD")

r# FCIP Indemnities by Cause of Loss - Share Analysis
# Expects a CSV with columns: Year, Peril_group, Billion_USD
# Adjust column names to match your actual CSV header

library(dplyr)
library(readr)
library(tidyr)

# --- Load data ---
fcip <- read_csv("fcip_losses.csv")

# --- Clean column names ---
colnames(fcip) <- c("Year", "Peril_group", "Billion_USD")

# --- Annual: total, drought, and drought share ---
annual_summary <- fcip %>%
  group_by(Year) %>%
  summarise(
    Total_Indemnity   = sum(Billion_USD, na.rm = TRUE),
    Drought_Indemnity = sum(Billion_USD[grepl("Drought", Peril_group,
                                              ignore.case = TRUE)],
                            na.rm = TRUE)
  ) %>%
  mutate(
    Drought_Share_Pct = round((Drought_Indemnity / Total_Indemnity) * 100, 1)
  )

print(annual_summary, n = Inf)

# --- Overall across all years: ALL peril categories ---
overall_total <- sum(fcip$Billion_USD, na.rm = TRUE)

overall_by_peril <- fcip %>%
  group_by(Peril_group) %>%
  summarise(
    Total_Indemnity_B = round(sum(Billion_USD, na.rm = TRUE), 2)
  ) %>%
  mutate(
    Share_Pct = round((Total_Indemnity_B / overall_total) * 100, 1)
  ) %>%
  arrange(desc(Total_Indemnity_B))

cat("\n--- Overall 1990-2024: All Peril Categories ---\n")
cat("Grand total FCIP indemnities: $", round(overall_total, 2), "B\n\n")
print(overall_by_peril, n = Inf)

# --- Optional: write results to CSV ---
write_csv(annual_summary,    "fcip_drought_share_by_year.csv")
write_csv(overall_by_peril,  "fcip_all_perils_overall.csv")