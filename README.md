# Rainfall Index Insurance Under Exceptional Drought: Payout Alignment and Producer Response

Replication code and derived data for Cecil, Benami, Carroll, Yu, and Ifft, *Rainfall
Index Insurance Under Exceptional Drought: Payout Alignment and Producer Response*,
submitted to *Earth's Future* (2026).

This repository benchmarks payouts from the USDA Pasture, Rangeland, and Forage (PRF)
Rainfall Index insurance program against U.S. Drought Monitor (USDM) exceptional (D4)
drought across nine western states (CA, NV, AZ, NM, CO, UT, TX, OK, KS), 2010–2025, and
models how prior-year drought and basis-risk experience relate to subsequent enrollment.

- **Paper DOI:** ⟨FILL: 10.xxxx/… once assigned⟩
- **Archived release DOI:** ⟨FILL: Zenodo concept DOI, 10.5281/zenodo.xxxxxxx⟩
- **Corresponding author:** Michael J. Cecil, University of Maryland (mjcecil@umd.edu)

---

## What this repository contains

- **`*.Rmd`** — the 14 analysis scripts (R Markdown), organized as a numbered pipeline.
- **`_setup.R`** — shared setup sourced by the `2_2*` layer: library loads, conflict
  preferences, constants, the drought-event window definitions, and the LaTeX
  table-export helper.
- **`data/`** — inputs and derived objects (see *Data* below for what is and isn't included).
- **`outputs/`** (or `data/outputs/`) — generated tables (`.tex`), figures, and the
  regression/summary artifacts consumed by the manuscript.
- **`⟨FILL: manuscript dir, if included⟩`** — LaTeX source for the manuscript, if archived here.

---

## Data

The analysis draws on three **publicly available** federal datasets. These are **not
redistributed** in this repository; the scripts download or reference them from their
official sources:

| Dataset | Source | Used for |
|---|---|---|
| PRF enrollment, premia, indemnities (county-year) | USDA RMA Summary of Business — https://www.rma.usda.gov/tools-reports/summary-of-business/state-county-crop-summary-business | Enrollment model, coverage-level figures |
| U.S. Drought Monitor weekly shapefiles | National Drought Mitigation Center / USDA / NOAA — https://droughtmonitor.unl.edu/DmData/GISData.aspx | D4 classification |
| CPC Unified Gauge-Based Analysis of Daily Precipitation over CONUS | NOAA Physical Sciences Laboratory — https://psl.noaa.gov/data/gridded/data.unified.daily.conus.html | Rainfall Index (RI) |

**What *is* included:** the derived analysis objects the pipeline produces — principally
`grids_usdm_stats.rda` (grid-interval RI + USDM stats) and `tpu_collapsed.rda` (the
county-year enrollment panel) — plus the state/county boundary files under
`data/boundaries/` (see *Reproducibility* below). These let a user reproduce all tables
and figures without re-downloading and re-processing the ~30 GB CPC record.

> **Note on the CPC data.** The raw CPC precipitation archive is large (~30 GB) and is
> **not** included. `1_1_group_cpc_data.Rmd` expects it at a path set via the
> `cpc_data_path` config variable near the top of that script — edit that to point at
> your local copy before running the pipeline from raw inputs.

---

## Pipeline and run order

Scripts are numbered by dependency. **Run in this order:**

```
1_1_group_cpc_data.Rmd          # aggregate raw CPC daily precip to two-month intervals
1_2_index_calculation.Rmd       # compute the Rainfall Index (RI) per grid-interval
1_3_payout_calculations_no_sim.Rmd   # binary payout (RI <= 0.90) per grid-interval
2_1_process_usdm.Rmd            # extract weekly USDM classifications to grid centroids
2_3_payouts_raw_only.Rmd        # build the county-year enrollment panel (tpu_collapsed)
2_4_participation_model.Rmd     # fixed-effects participation model (Tables 3, 5, S7–S9)
```

After `2_1` and `2_3`, the remaining scripts are **independent of one another** and may be
run in any order:

```
2_2_summary_stats_grid_interval.Rmd      # Table S2
2_2_payout_crosstabs_DM_median.Rmd       # Tables 4, S3–S6; crosstab map (Fig S3)
2_2_drought_lag_length_dm_median.Rmd     # Figures 5, S4 (drought length/position)
2_2_heatmaps_DM_median.Rmd               # Figure 2 (drought/payout heatmaps)
2_2_prf_usdm_summary_maps_2010_2025.Rmd  # Figures 4, S5 (occurrence / missed-payout maps)
2_2_RI_VI_by_year.Rmd                    # RI-vs-VI comparison
2_5_sob_enrollment_coverage_level.Rmd    # Table S1; Figure S1 (coverage levels)
2_5_three_datasets_map.Rmd               # Figures 1, S2 (study area / data footprints)
```

Each `2_2*`/`2_5*` script begins with `source(here::here("_setup.R"))` followed by
`load(here("data/outputs/grids_usdm_stats.rda"))` and a standard non-NA filter.
`2_4` loads `tpu_collapsed.rda` and does **not** source `_setup.R`.

---

## Requirements

- **R** version ⟨FILL: e.g. 4.3.x — the version you ran⟩ or later.
- **Pandoc / RStudio** to knit the `.Rmd` files (RStudio bundles Pandoc).
- A **LaTeX** installation if you knit to PDF (`tinytex::install_tinytex()` is sufficient).

### R packages

Install from CRAN:

```r
install.packages(c(
  "tidyverse", "dplyr", "tidyr", "stringr", "tibble", "purrr", "lubridate",
  "sf", "raster", "exactextractr", "tigris",
  "fixest", "car",
  "ggplot2", "ggpubr", "ggrepel", "patchwork", "scales", "scico", "viridis", "gt",
  "here", "conflicted", "rlang", "assertthat", "tinytex"
))
```

For exact reproducibility, package versions are pinned in `⟨FILL: renv.lock if you use
renv — strongly recommended; otherwise list sessionInfo() output here⟩`.

---

## Reproducibility

- **Boundaries are pinned, not fetched live.** `tigris` normally pulls state/county
  boundaries from the web, and that geometry can vary between runs (it caused a small,
  non-deterministic count shift during development). `1_2` and `1_3_no_sim` therefore
  load boundaries from `data/boundaries/*.rda` if present, and only download-and-cache
  them otherwise. Keep these files in place to reproduce the published numbers exactly.
- With the pinned boundaries and the derived `.rda` objects included here, re-running the
  table/figure scripts reproduces the manuscript tables **byte-for-byte** (only PDF
  timestamps differ).
- Key canonical definitions used throughout: D4 drought = `DM_median >= 4`; payout =
  `RI <= 0.90`; study window 2010–2025; nine states as listed above.

---

## Key outputs and where they come from

| Manuscript item | Produced by |
|---|---|
| Table 3 (descriptive stats), Table 5, Tables S7–S9 | `2_4_participation_model.Rmd` |
| Table 4, Tables S3–S6 | `2_2_payout_crosstabs_DM_median.Rmd` |
| Table S2 | `2_2_summary_stats_grid_interval.Rmd` |
| Table S1, Figure S1 | `2_5_sob_enrollment_coverage_level.Rmd` |
| Figures 1, S2 | `2_5_three_datasets_map.Rmd` |
| Figure 2 | `2_2_heatmaps_DM_median.Rmd` |
| Figures 4, S5 | `2_2_prf_usdm_summary_maps_2010_2025.Rmd` |
| Figures 5, S4 | `2_2_drought_lag_length_dm_median.Rmd` |
| Figure S3 | `2_2_payout_crosstabs_DM_median.Rmd` |

---

## Citation

If you use this code or the derived data, please cite both the paper and the archive:

> Cecil, M. J., Benami, E., Carroll, A., Yu, J., & Ifft, J. (2026). *Rainfall Index
> Insurance Under Exceptional Drought: Payout Alignment and Producer Response.* Earth's
> Future. ⟨FILL: DOI⟩

> Cecil, M. J., Benami, E., Carroll, A., Yu, J., & Ifft, J. (2026). *Replication code and
> derived data for "Rainfall Index Insurance Under Exceptional Drought"* (Version 1.0.0)
> [Software]. Zenodo. ⟨FILL: Zenodo DOI⟩

A machine-readable `CITATION.cff` is included at the repository root.

---

## License

- **Code:** ⟨FILL: MIT or BSD-3-Clause — see `LICENSE`⟩
- **Derived data:** ⟨FILL: CC-BY-4.0⟩

The upstream datasets are U.S. federal government products (public domain); see each
source above for its own terms.

---

## Acknowledgments

This work was supported by the NASA Harvest Program (Award #80NSSC23M0032). We thank the
members of the Human Environment CompuTing and Ag Research (HECTARE) Lab for constructive
input.
