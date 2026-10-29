# Install every R package used by Potohar_Drought_Analysis.Rmd (CRAN Windows binaries).
# Usage: Rscript install_r_packages.R
# Exact versions used for v2.1: renv::restore(lockfile = "renv.lock", prompt = FALSE)  (run from analysis/)
lib <- Sys.getenv("R_LIBS_USER")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))
pkgs <- c(
  "rmarkdown", "knitr", "yaml", "data.table", "ncdf4", "terra", "sf",
  "SPEI", "trend", "modifiedmk", "lmomco", "fitdistrplus", "MBC",
  "copula", "VineCopula", "ggplot2", "patchwork", "scales", "viridisLite",
  "RColorBrewer", "ggspatial", "ggrepel", "officer", "flextable", "zoo",
  "matrixStats", "tidyterra", "cowplot", "ragg", "svglite", "metR",
  "ggnewscale", "kableExtra", "DT", "lubridate", "dplyr", "tidyr", "purrr",
  "forcats", "stringr", "sp", "Kendall", "boot", "pracma", "whitebox", "elevatr",
  "pdftools", "jsonlite", "png", "renv"            # pdftools: 04_digitise_yields.R; renv: exact versions
)
need <- setdiff(pkgs, rownames(installed.packages()))
if (length(need)) install.packages(need, lib = lib, type = "binary", dependencies = c("Depends", "Imports", "LinkingTo"))
miss <- setdiff(pkgs, rownames(installed.packages()))
cat("missing after install:", if (length(miss)) miss else "none", "\n")
