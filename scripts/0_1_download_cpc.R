# =============================================================================
# 0_1_download_cpc.R  —  download raw CPC daily precipitation (CONUS)
#
# Entry point of the pipeline. Downloads daily CPC Unified Gauge-Based Analysis
# of Daily Precipitation over CONUS via the rnoaa package and writes one CSV per
# day to data/cpc_downloads/. Downstream, 1_1_group_cpc_data.Rmd reads these CSVs
# and builds the rainfall-index baseline "from 1948 to year (t-2)", so the full
# historical record is required -- not just the analysis years.
#
# NOTE: rnoaa was archived from CRAN and is installed from GitHub below.
# NOTE: the full 1948-2025 daily record is large (~30 GB) and the download takes
#       a long time. The loop is resumable -- files already present are skipped --
#       so it is safe to stop and re-run. Consider running it in year-sized
#       chunks (see start_date/end_date) rather than all at once.
# =============================================================================

# ---- Packages ---------------------------------------------------------------
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
if (!requireNamespace("rnoaa", quietly = TRUE)) {
  # rnoaa is not on CRAN; pin a commit for reproducibility if possible, e.g.:
  #   devtools::install_github("ropensci/rnoaa", ref = "<COMMIT_SHA>")
  devtools::install_github("ropensci/rnoaa")
}
library(rnoaa)
library(here)
library(lubridate)

# ---- Date range -------------------------------------------------------------
# Full record needed to reproduce the analysis:
#   - RI historical normals are built from 1948 onward (see 1_1_group_cpc_data.Rmd,
#     start_year <- 1948), so the baseline requires daily data back to 1948.
#   - analysis years run through 2025.
# To top up only recent data (incremental use), narrow this range -- already-
# downloaded days are skipped automatically.
start_date <- ymd("1948-01-01")
end_date   <- ymd("2025-12-31")


date_seq <- format(seq(start_date, end_date, by = "day"), "%Y-%m-%d")

# ---- Output directory -------------------------------------------------------
out_dir <- here("data", "cpc_downloads")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---- Download loop (resumable) ----------------------------------------------
n_total <- length(date_seq)
n_done  <- 0L
n_skip  <- 0L
n_fail  <- 0L
failed  <- character(0)

for (date in date_seq) {
  out_file <- file.path(out_dir, paste0("cpc_", date, ".csv"))

  # Skip days already downloaded -- makes the loop safe to re-run after a stop.
  if (file.exists(out_file)) {
    n_skip <- n_skip + 1L
    next
  }

  # Fetch one day; on failure, record and continue rather than aborting the run.
  cpc_data <- tryCatch(
    cpc_prcp(as.character(date), us = TRUE),
    error = function(e) {
      warning("Download failed for ", date, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(cpc_data)) {
    n_fail <- n_fail + 1L
    failed <- c(failed, date)
    next
  }

  write.csv(cpc_data, file = out_file, row.names = FALSE)
  n_done <- n_done + 1L

  # Light progress ping every ~1000 new files.
  if (n_done %% 1000L == 0L) {
    message(sprintf("... %d downloaded, %d skipped (of %d days)",
                    n_done, n_skip, n_total))
  }
}

# ---- Summary ----------------------------------------------------------------
message(sprintf("Done. %d newly downloaded, %d already present, %d failed (of %d days).",
                n_done, n_skip, n_fail, n_total))

if (n_fail > 0L) {
  fail_log <- here("data", "cpc_download_failures.txt")
  writeLines(failed, fail_log)
  message("Failed dates written to: ", fail_log,
          " -- re-run this script to retry them (successful days are skipped).")
}
