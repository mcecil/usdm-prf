# =============================================================================
# _setup.R  —  shared setup for the PRF x USDM analysis scripts (2_2* layer)
#
# Sourced at the top of each analysis script:  source(here::here("_setup.R"))
# Contains: library loads, conflict preferences, shared constants, the
# drought-event definitions, and the LaTeX table-export helper.
#
# Deliberately does NOT load data. Each script performs its own
#   load(here("data/outputs/grids_usdm_stats.rda"))
# and the standard non-NA filter, immediately after sourcing this file.
# =============================================================================

# ---- Libraries (superset used across the analysis layer) --------------------
library(dplyr)
library(here)
library(sf)
library(raster)
library(conflicted)
library(rlang)
library(scico)
library(ggpubr)
library(assertthat)
library(ggplot2)
library(stringr)
library(tidyr)
library(gt)
library(viridis)
library(scales)
library(purrr)
library(patchwork)
library(tibble)
library(tigris)
library(ggrepel)

# ---- Conflict preferences ---------------------------------------------------
conflicted::conflict_prefer("select", "dplyr")
conflicted::conflict_prefer("filter", "dplyr")
conflicts_prefer(dplyr::lag)

options(max.print = 10000)

# ---- Shared constants -------------------------------------------------------
start_year <- 2010
end_year   <- 2025

ri_threshold           <- 0.9
high_drought_threshold <- 4
high_drought_label     <- "D4"

aoi_states <- c("CA", "NV", "AZ", "NM", "CO", "UT", "TX", "OK", "KS")

interval_start_months <- 1:11
names(interval_start_months) <- 625:635

interval_end_months <- 2:12
names(interval_end_months) <- 625:635

# ---- Drought-event definitions ----------------------------------------------
# Derived empirically via test_drought_windows.R using the manuscript rule:
# event intervals = intervals where >= 10% of nine-state grids are in D4
# (DM_median >= 4); state subsets = states with >= 10% of their grid-intervals
# in D4 over the event window. These reproduce the manuscript's stated windows
# (2011: 7 intervals, May-Jun to Nov-Dec; 2020-21: 10 intervals, Nov-Dec 2020
# to Sep-Oct 2021) and state subsets.

# 2011 event: intervals 629-635 (May-Jun through Nov-Dec 2011)
intervals_2011 <- 629:635

# 2020-21 event: Nov-Dec 2020 (interval 635) then Jan-Feb..Sep-Oct 2021
# (intervals 625-633). Encoded as (year, interval) pairs because it crosses
# the calendar-year boundary.
window_2021 <- data.frame(
  year     = c(2020, rep(2021, 9)),
  interval = c(635,  625:633)
)

# State subsets (>= 10% of a state's grid-intervals in D4 over the window)
states_2011 <- c("TX", "OK", "NM", "KS")
states_2021 <- c("UT", "AZ", "NM", "NV", "CA", "CO")

# ---- LaTeX table-export helper ----------------------------------------------
# (appended verbatim from the source scripts by the build step)
export_df_to_latex <- function(df, file_path, caption = NULL) {
  
  #-----------------------------
  # Helper: escape LaTeX specials
  #-----------------------------
  escape_latex <- function(x) {
    x <- gsub("\\\\", "\\\\textbackslash{}", x)
    x <- gsub("([%&_#\\$])", "\\\\\\1", x)
    x <- gsub("_", "\\\\_", x)
    return(x)
  }
  
  # Convert to character
  df[] <- lapply(df, as.character)
  
  # Escape LaTeX characters
  df[] <- lapply(df, escape_latex)
  colnames(df) <- escape_latex(colnames(df))
  
  # Alignment: first left, rest right
  n_cols <- ncol(df)
  align_string <- paste0("l", paste(rep("r", n_cols - 1), collapse = ""))
  
  # Build body rows
  body_rows <- apply(df, 1, function(row) {
    paste(row, collapse = " & ")
  })
  
  body_rows <- paste0(body_rows, " \\\\")
  body_text <- paste(body_rows, collapse = "\n")
  
  # Header row
  header <- paste(colnames(df), collapse = " & ")
  header <- paste0(header, " \\\\")
  
  # Caption + label handling
  file_name <- tools::file_path_sans_ext(basename(file_path))
  
  if (is.null(caption)) {
    caption_text <- gsub("_", " ", file_name)
  } else {
    caption_text <- caption
  }
  
  label <- paste0("tab:", file_name)
  
  # Build LaTeX table
  latex_table <- paste0(
    "\\begin{table}[t]
\\centering
\\caption{", caption_text, "}
\\label{", label, "}
\\fontsize{12pt}{14pt}\\selectfont
\\begin{tabular}{@{\\extracolsep{\\fill}}", align_string, "}
\\toprule
", header, "
\\midrule\\addlinespace[2.5pt]
", body_text, "
\\bottomrule
\\end{tabular}
\\end{table}"
  )
  
  # Write file
  writeLines(latex_table, file_path)
  
  message("LaTeX table exported to: ", file_path)
}