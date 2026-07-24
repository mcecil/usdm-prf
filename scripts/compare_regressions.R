# =============================================================================
# compare_regressions.R
#
# Quantifies how much the regression tables changed between two copies of the
# repo (e.g., pre-clustering-fix "original" vs post-fix "clone"). Designed for
# Batch 3a (SE clustering): coefficients should be UNCHANGED; standard errors
# (and significance stars) should move in the year-only and year+state columns.
#
# It parses the etable-generated .tex files, extracts each coefficient estimate,
# its standard error, and significance stars, and reports the absolute and
# relative change for every cell -- flagging which changed.
#
# USAGE: set the two repo roots, then source() or `Rscript compare_regressions.R`.
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
repo_original <- if (length(args) >= 1) args[[1]] else "~/Documents/GitHub/usdm-prf"
repo_clone    <- if (length(args) >= 2) args[[2]] else "~/Documents/GitHub/usdm-prf copy"
repo_original <- path.expand(repo_original)
repo_clone    <- path.expand(repo_clone)
tables_subdir <- "data/outputs/tables"

# regression tables the manuscript uses
reg_files <- c(
  "reg_m2_basis_risk.tex" = "Table 5  (Model 2: basis risk + any D4)",
  "reg_m3_br_lr.tex"      = "Table S7 (Model 3: + loss ratio)",
  "reg_m4_br_dm.tex"      = "Table S8 (Model 4: + drought intensity)",
  "reg_m5_full.tex"       = "Table S9 (Model 5: full)"
)

# ---- Parse an etable .tex into (coef, se, stars) per variable x column -------
# etable format: a coefficient row looks like
#   Variable label & est1$^{***}$ & est2$^{**}$ & est3$^{*}$ \\
# and the SE row directly beneath is
#   & (se1) & (se2) & (se3) \\
# We pair each coefficient row with the parenthesized SE row that follows it.
parse_etable <- function(path) {
  if (!file.exists(path)) return(NULL)
  lines <- readLines(path, warn = FALSE)

  # a "data" line has & separators and ends with \\
  is_data <- grepl("&", lines) & grepl("\\\\\\\\", lines)

  # helper: split a tex row into cells (strip trailing \\)
  cells_of <- function(s) {
    s <- sub("\\\\\\\\\\s*$", "", s)          # drop trailing \\
    parts <- strsplit(s, "&", fixed = TRUE)[[1]]
    trimws(parts)
  }
  # helper: does a cell look like a number (possibly with stars/math)?
  num_in <- function(cell) {
    # extract first signed decimal
    m <- regmatches(cell, regexpr("-?[0-9]*\\.?[0-9]+", cell))
    if (length(m) == 0) return(NA_real_)
    suppressWarnings(as.numeric(m))
  }
  stars_in <- function(cell) {
    n <- lengths(regmatches(cell, gregexpr("\\*", cell)))
    # etable uses $^{***}$ style; count asterisks
    paste(rep("*", n), collapse = "")
  }
  is_se_row <- function(cellvec) {
    # SE rows: first cell empty, other non-empty cells wrapped in ( )
    body <- cellvec[-1]
    body <- body[nzchar(body)]
    length(body) > 0 && all(grepl("^\\(.*\\)$", body))
  }

  out <- list()
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    if (is_data[i]) {
      cv <- cells_of(lines[i])
      label <- cv[1]
      # is this a coefficient row? (has a numeric in >=1 body cell, not an SE row)
      body <- cv[-1]
      has_num <- any(!is.na(vapply(body, num_in, numeric(1))))
      if (nzchar(label) && has_num && !is_se_row(cv)) {
        ests  <- vapply(body, num_in, numeric(1))
        stars <- vapply(body, stars_in, character(1))
        # look for an SE row immediately following (skip blank/non-data)
        se <- rep(NA_real_, length(ests))
        j <- i + 1L
        while (j <= n && !is_data[j]) j <- j + 1L
        if (j <= n && is_data[j]) {
          cv2 <- cells_of(lines[j])
          if (is_se_row(cv2)) {
            body2 <- cv2[-1]
            se <- vapply(body2, function(x) num_in(gsub("[()]", "", x)), numeric(1))
            i <- j  # consume the SE row
          }
        }
        out[[length(out) + 1L]] <- list(label = label, est = ests, se = se, stars = stars)
      }
    }
    i <- i + 1L
  }
  out
}

fmt <- function(x, d = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = d))
pct <- function(a, b) {
  if (is.na(a) || is.na(b) || a == 0) return(NA_real_)
  100 * (b - a) / abs(a)
}

cat("========================================================================\n")
cat("Regression table comparison (magnitude of change)\n")
cat("  original:", repo_original, "\n")
cat("  clone:   ", repo_clone, "\n")
cat("========================================================================\n")

for (f in names(reg_files)) {
  role <- reg_files[[f]]
  a <- parse_etable(file.path(repo_original, tables_subdir, f))
  b <- parse_etable(file.path(repo_clone,    tables_subdir, f))
  cat("\n------------------------------------------------------------------------\n")
  cat(f, " -- ", role, "\n", sep = "")
  cat("------------------------------------------------------------------------\n")
  if (is.null(a) || is.null(b)) {
    cat("  MISSING in ", paste(c(if (is.null(a)) "original", if (is.null(b)) "clone"),
                               collapse = ", "), " -- skipped\n", sep = "")
    next
  }
  # match rows by label
  labs_a <- vapply(a, `[[`, character(1), "label")
  labs_b <- vapply(b, `[[`, character(1), "label")
  common <- intersect(labs_a, labs_b)
  if (length(common) == 0) { cat("  (no matching coefficient rows parsed)\n"); next }

  for (lab in common) {
    ra <- a[[which(labs_a == lab)[1]]]
    rb <- b[[which(labs_b == lab)[1]]]
    ncol <- max(length(ra$est), length(rb$est))
    cat(sprintf("  %s\n", lab))
    for (k in seq_len(ncol)) {
      ea <- ra$est[k]; eb <- rb$est[k]
      sa <- ra$se[k];  sb <- rb$se[k]
      sta <- if (k <= length(ra$stars)) ra$stars[k] else ""
      stb <- if (k <= length(rb$stars)) rb$stars[k] else ""
      coef_changed <- !isTRUE(all.equal(ea, eb))
      se_changed   <- !isTRUE(all.equal(sa, sb))
      star_changed <- !identical(sta, stb)
      flag <- paste0(
        if (coef_changed) " [COEF CHANGED]" else "",
        if (se_changed)   " [SE changed]"   else "",
        if (star_changed) sprintf(" [stars %s -> %s]", ifelse(nzchar(sta),sta,"·"),
                                                        ifelse(nzchar(stb),stb,"·")) else ""
      )
      cat(sprintf("    col %d: coef %s -> %s (%+.1f%%)   se %s -> %s (%+.1f%%)%s\n",
                  k, fmt(ea), fmt(eb), ifelse(is.na(pct(ea,eb)),0,pct(ea,eb)),
                  fmt(sa), fmt(sb), ifelse(is.na(pct(sa,sb)),0,pct(sa,sb)), flag))
    }
  }
}

cat("\n------------------------------------------------------------------------\n")
cat("Interpretation for Batch 3a (clustering fix):\n")
cat("  EXPECTED: coefficients unchanged in ALL columns; standard errors (and\n")
cat("  possibly stars) change in columns 1 (year) and 2 (year+state); column 3\n")
cat("  (county FE, already clustered) unchanged.\n")
cat("  ANY [COEF CHANGED] flag is unexpected -- investigate.\n")
