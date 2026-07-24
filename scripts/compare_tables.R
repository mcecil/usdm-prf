# =============================================================================
# compare_tables.R
#
# Compares the manuscript-USED LaTeX tables between two copies of the repo
# (e.g., a pristine "original" and the cleaned "clone"), to verify that the
# Batch 2a cleanup did not change any generated table.
#
# It compares only the tables the manuscript actually \input's (14 of them),
# not every .tex the scripts happen to write. For each, it reports:
#   IDENTICAL / DIFFERS / MISSING, and for DIFFERS shows a line-level diff.
#
# USAGE — set the two repo roots below, then source() this file or run:
#   Rscript compare_tables.R
# (You can also pass the two roots as command-line args.)
# =============================================================================

# ---- Set the two repo roots here (or pass as args) --------------------------
args <- commandArgs(trailingOnly = TRUE)
repo_original <- if (length(args) >= 1) args[[1]] else
  "~/Documents/GitHub/usdm-prf"          # <-- pristine / baseline
repo_clone    <- if (length(args) >= 2) args[[2]] else
  "~/Documents/GitHub/usdm-prf copy"     # <-- cleaned clone

repo_original <- path.expand(repo_original)
repo_clone    <- path.expand(repo_clone)

# relative path (within each repo) to the generated tables
tables_subdir <- "data/outputs/tables"

# ---- The tables the MANUSCRIPT uses (on-disk filename -> manuscript role) ----
# Written filenames differ from the \input names for the rate tables, so we
# compare the actual files on disk and label them with their manuscript role.
tables <- list(
  c("acre_table_aoi.tex",             "Table S1  (acre_table_aoi)"),
  c("summary_dm_ri_thresholds.tex",   "Table S2  (summary_dm_ri_thresholds)"),
  c("summary_by_period.tex",          "Table 4   (summary_by_period_rates)"),
  c("summary_by_period_combo.tex",    "Table S3  (summary_by_period_combo)"),
  c("summary_by_state.tex",           "Table S4  (summary_by_state_rates)"),
  c("summary_by_year.tex",            "Table S5  (summary_by_year_rates)"),
  c("summary_by_interval.tex",        "Table S6  (summary_by_interval_rates)"),
  c("desc_stats_regression.tex",      "Table 3   (desc_stats_regression)"),
  c("reg_m2_basis_risk.tex",          "Table 5   (reg_m2_basis_risk)"),
  c("reg_m3_br_lr.tex",               "Table S7  (reg_m3_br_lr)"),
  c("reg_m4_br_dm.tex",               "Table S8  (reg_m4_br_dm)"),
  c("reg_m5_full.tex",                "Table S9  (reg_m5_full)")
  # key_datasets.tex and crosstab_labels.tex are static (hand-written), not
  # script-generated, so they are not part of this cleanup check. Add them here
  # if you want to confirm they are unchanged too.
)

# ---- Helpers ----------------------------------------------------------------
read_lines_safe <- function(path) {
  if (!file.exists(path)) return(NULL)
  readLines(path, warn = FALSE)
}

# simple line-level diff (no external deps): show lines that differ
show_line_diff <- function(a, b, max_show = 40) {
  n <- max(length(a), length(b))
  a <- c(a, rep(NA_character_, n - length(a)))
  b <- c(b, rep(NA_character_, n - length(b)))
  shown <- 0
  for (i in seq_len(n)) {
    ai <- a[[i]]; bi <- b[[i]]
    if (is.na(ai)) ai <- "<no line>"
    if (is.na(bi)) bi <- "<no line>"
    if (!identical(ai, bi)) {
      shown <- shown + 1
      if (shown > max_show) { cat("      ... (more differences not shown)\n"); break }
      cat(sprintf("      L%-4d\n", i))
      cat(sprintf("        original: %s\n", ai))
      cat(sprintf("        clone:    %s\n", bi))
    }
  }
}

# classify a difference as cosmetic (caption/label only) vs substantive
classify_diff <- function(a, b) {
  diff_idx <- which(!mapply(identical,
                            c(a, rep(NA, max(0, length(b)-length(a)))),
                            c(b, rep(NA, max(0, length(a)-length(b))))))
  changed <- unique(c(a[diff_idx], b[diff_idx]))
  changed <- changed[!is.na(changed)]
  only_caption_label <- all(grepl("\\\\caption|\\\\label", changed))
  if (length(changed) > 0 && only_caption_label) "cosmetic (caption/label only)"
  else "SUBSTANTIVE (table body differs)"
}

# ---- Run --------------------------------------------------------------------
cat("========================================================================\n")
cat("Table comparison\n")
cat("  original:", repo_original, "\n")
cat("  clone:   ", repo_clone, "\n")
cat("========================================================================\n\n")

n_identical <- 0; n_differ <- 0; n_missing <- 0
differ_names <- character(0)

for (t in tables) {
  fname <- t[[1]]; role <- t[[2]]
  pa <- file.path(repo_original, tables_subdir, fname)
  pb <- file.path(repo_clone,    tables_subdir, fname)
  a <- read_lines_safe(pa); b <- read_lines_safe(pb)

  if (is.null(a) || is.null(b)) {
    n_missing <- n_missing + 1
    miss <- c(if (is.null(a)) "original" , if (is.null(b)) "clone")
    cat(sprintf("MISSING   %-34s %s   (not found in: %s)\n", fname, role,
                paste(miss, collapse = ", ")))
    next
  }

  if (identical(a, b)) {
    n_identical <- n_identical + 1
    cat(sprintf("IDENTICAL %-34s %s\n", fname, role))
  } else {
    n_differ <- n_differ + 1
    differ_names <- c(differ_names, fname)
    kind <- classify_diff(a, b)
    cat(sprintf("DIFFERS   %-34s %s   -> %s\n", fname, role, kind))
    show_line_diff(a, b)
    cat("\n")
  }
}

cat("\n------------------------------------------------------------------------\n")
cat(sprintf("Summary: %d identical, %d differ, %d missing (of %d checked)\n",
            n_identical, n_differ, n_missing, length(tables)))
if (n_differ == 0 && n_missing == 0) {
  cat("PASS: all manuscript tables are byte-identical between the two repos.\n")
} else {
  if (n_differ > 0)  cat("Tables that differ: ", paste(differ_names, collapse = ", "), "\n")
  cat("Review the diffs above. 'cosmetic' = caption/label only (harmless);\n")
  cat("'SUBSTANTIVE' = a value in the table body changed (investigate).\n")
}
