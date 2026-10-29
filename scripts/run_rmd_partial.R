# Development helper: run Potohar_Drought_Analysis.Rmd up to (not including) a given chunk label.
# Usage: Rscript scripts/run_rmd_partial.R <stop_chunk_label>
args <- commandArgs(trailingOnly = TRUE)
stop_at <- if (length(args)) args[1] else "obs-grids"
setwd(yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))$paths$root)
tmp <- tempfile(fileext = ".R")
knitr::purl("Potohar_Drought_Analysis.Rmd", output = tmp, documentation = 1, quiet = TRUE)
lines <- readLines(tmp)
hdr <- grep("^## ----", lines)
labs <- sub(",.*$", "", sub("-{2,}.*$", "", sub("^## ----", "", lines[hdr])))
cut <- hdr[which(trimws(labs) == stop_at)]
if (length(cut)) lines <- lines[seq_len(cut[1] - 1)]
writeLines(lines, tmp)
t0 <- Sys.time()
source(tmp, echo = FALSE, print.eval = FALSE)
cat("\nPARTIAL RUN OK up to chunk:", stop_at, "in", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
