# =============================================================================
# test_drought_windows.R
#
# Purpose: empirically determine which two-month intervals belong to the 2011
#          and 2020-2021 drought events, using the manuscript's stated rule:
#          "intervals where at least 10% of grids in the nine-state region were
#          classified as D4 (DM_median >= 4)."
#
# This is a STANDALONE diagnostic. It reads only grids_usdm_stats.rda and prints
# results to the console. It writes nothing and changes nothing. Once we agree on
# the window, the resulting interval vectors get hard-coded into _setup.R.
#
# Run from the project root (so here() resolves), e.g. in RStudio open the
# project and source this file, or: Rscript test_drought_windows.R
# =============================================================================

library(dplyr)
library(tidyr)
library(stringr)
library(sf)
library(here)

# ---- Settings (match the analysis-layer conventions) ------------------------
high_drought_threshold <- 4          # D4
threshold_pct          <- 10         # the manuscript's >= 10% rule
aoi_states <- c("CA","NV","AZ","NM","CO","UT","TX","OK","KS")  # nine-state region

# ---- Load the shared USDM/RI object -----------------------------------------
load(here("data/outputs/grids_usdm_stats.rda"))   # provides `grids`

# Apply the same non-NA filter the analysis scripts use, so the grid set matches
grids <- grids %>%
  filter(!is.na(cpc_index_2010_625)) %>%
  filter(!is.na(DM_median_2010_625))

# ---- Build long DM table: one row per grid x year x interval ----------------
dm_long <- grids %>%
  st_drop_geometry() %>%
  select(GRIDCODE, STATE, starts_with("DM_median_")) %>%
  pivot_longer(
    cols = -c(GRIDCODE, STATE),
    names_to = "var",
    values_to = "DM"
  ) %>%
  mutate(
    var      = str_remove(var, "^DM_median_"),
    year     = as.integer(str_sub(var, 1, 4)),
    interval = as.integer(str_sub(var, 6))
  ) %>%
  select(-var) %>%
  filter(!is.na(DM))

# ---- % of nine-state grids in D4, for every year x interval -----------------
# (Event-interval selection uses the FULL nine-state region, per the text.)
d4_share <- dm_long %>%
  filter(STATE %in% aoi_states) %>%
  group_by(year, interval) %>%
  summarise(
    n_grids   = n(),
    n_d4      = sum(DM >= high_drought_threshold, na.rm = TRUE),
    pct_d4    = 100 * n_d4 / n_grids,
    .groups   = "drop"
  ) %>%
  mutate(meets_threshold = pct_d4 >= threshold_pct)

# Readable interval labels (625 = Jan-Feb ... 635 = Nov-Dec)
interval_start <- setNames(1:11, 625:635)
interval_end   <- setNames(2:12, 625:635)
lab <- function(intv) paste0(month.abb[interval_start[as.character(intv)]], "-",
                             month.abb[interval_end[as.character(intv)]])

# =============================================================================
# REPORT 1: every interval that meets >= 10%, chronologically
# =============================================================================
cat("\n=====================================================================\n")
cat("All year-intervals with >= ", threshold_pct, "% of nine-state grids in D4\n", sep = "")
cat("=====================================================================\n")
meets <- d4_share %>%
  filter(meets_threshold) %>%
  arrange(year, interval) %>%
  mutate(label = paste0(year, " ", sapply(interval, lab)))
print(as.data.frame(meets %>% select(year, interval, label, pct_d4, n_d4, n_grids)),
      row.names = FALSE)

# =============================================================================
# REPORT 2: focus on the two event years, showing ALL intervals (met or not)
#           so you can see exactly where the >= 10% run starts/stops, including
#           the year-boundary crossing for 2020-21.
# =============================================================================
show_event <- function(years, event_name) {
  cat("\n=====================================================================\n")
  cat(event_name, " -- all intervals across ", paste(years, collapse = ", "), "\n", sep = "")
  cat("(marker '*' = meets >= ", threshold_pct, "%)\n", sep = "")
  cat("=====================================================================\n")
  tab <- d4_share %>%
    filter(year %in% years) %>%
    arrange(year, interval) %>%
    mutate(
      label = paste0(year, " ", sapply(interval, lab)),
      flag  = ifelse(meets_threshold, "*", " ")
    )
  for (i in seq_len(nrow(tab))) {
    cat(sprintf("  %s  %-10s  pct_d4 = %5.1f%%   (%d / %d grids)\n",
                tab$flag[i], tab$label[i], tab$pct_d4[i], tab$n_d4[i], tab$n_grids[i]))
  }
}

# 2011 event: text says the run is within 2011 (May-Jun .. Nov-Dec)
show_event(2011, "2011 DROUGHT")

# 2020-21 event: text says Nov-Dec 2020 .. Sep-Oct 2021, so show both years
show_event(c(2020, 2021), "2020-2021 DROUGHT")

# =============================================================================
# REPORT 3: contiguous >= 10% run for each event, as an interval vector
#           (This is the most likely intended definition: the unbroken span.)
#           Encodes each interval as year*1000 + interval so runs are orderable
#           across the year boundary.
# =============================================================================
contiguous_run <- function(years) {
  s <- d4_share %>%
    filter(year %in% years) %>%
    arrange(year, interval) %>%
    mutate(time_id = year * 1000 + interval)
  met <- s %>% filter(meets_threshold)
  if (nrow(met) == 0) return(invisible(NULL))
  # longest contiguous run among the met intervals (by adjacency in the ordered seq)
  s$met <- s$meets_threshold
  s$run_id <- cumsum(!s$met)            # increments on each non-meeting interval
  best <- s %>% filter(met) %>%
    count(run_id, sort = TRUE) %>% slice(1) %>% pull(run_id)
  run <- s %>% filter(met, run_id == best) %>% arrange(time_id)
  run
}

cat("\n=====================================================================\n")
cat("Contiguous >= 10% runs (suggested event windows)\n")
cat("=====================================================================\n")

run_2011 <- contiguous_run(2011)
cat("\n2011:\n")
if (!is.null(run_2011)) {
  cat("  intervals (code):   ", paste(run_2011$interval, collapse = ", "), "\n")
  cat("  span:               ", lab(min(run_2011$interval)), "to", lab(max(run_2011$interval)), "\n")
  cat("  n intervals:        ", nrow(run_2011), "\n")
  cat("  -> DM_cols_2011 <- paste0(\"DM_median_2011_\", c(",
      paste(run_2011$interval, collapse = ", "), "))\n")
}

run_2021 <- contiguous_run(c(2020, 2021))
cat("\n2020-2021:\n")
if (!is.null(run_2021)) {
  cat("  intervals (yr, code):\n")
  print(as.data.frame(run_2021 %>% select(year, interval)), row.names = FALSE)
  cat("  n intervals:        ", nrow(run_2021), "\n")
  cat("  time_id span:       ", min(run_2021$time_id), "to", max(run_2021$time_id), "\n")
}

# =============================================================================
# REPORT 4: state restriction check (the SECOND >= 10% rule)
#           Given a chosen window, which states have >= 10% of their grid-intervals
#           in D4 over that window? Text expects: 2011 -> KS,OK,TX,NM (4);
#           2020-21 -> CA,NV,UT,AZ,CO,NM (6).
#           Uses the contiguous runs found above.
# =============================================================================
state_restriction <- function(run_df, event_name) {
  cat("\n---------------------------------------------------------------------\n")
  cat("State restriction for ", event_name, " (>= ", threshold_pct,
      "% of a state's grid-intervals in D4 over the window)\n", sep = "")
  cat("---------------------------------------------------------------------\n")
  if (is.null(run_df)) { cat("  (no window)\n"); return(invisible(NULL)) }
  keys <- run_df %>% mutate(time_id = year * 1000 + interval) %>% pull(time_id)
  st <- dm_long %>%
    filter(STATE %in% aoi_states) %>%
    mutate(time_id = year * 1000 + interval) %>%
    filter(time_id %in% keys) %>%
    group_by(STATE) %>%
    summarise(
      n      = n(),
      n_d4   = sum(DM >= high_drought_threshold, na.rm = TRUE),
      pct_d4 = 100 * n_d4 / n,
      .groups = "drop"
    ) %>%
    arrange(desc(pct_d4)) %>%
    mutate(included = ifelse(pct_d4 >= threshold_pct, "INCLUDE", ""))
  print(as.data.frame(st), row.names = FALSE)
  cat("  -> states included: ",
      paste(st$STATE[st$pct_d4 >= threshold_pct], collapse = ", "), "\n")
}

state_restriction(run_2011,  "2011")
state_restriction(run_2021,  "2020-2021")

cat("\nDone. Compare the runs/labels above against the manuscript text:\n")
cat("  2011 text:     7 intervals, May-Jun to Nov-Dec 2011\n")
cat("  2020-21 text: 10 intervals, Nov-Dec 2020 to Sep-Oct 2021\n")
cat("  2011 states:   KS, OK, TX, NM (4)\n")
cat("  2020-21 states: CA, NV, UT, AZ, CO, NM (6)\n")
