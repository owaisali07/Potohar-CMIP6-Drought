# v3 rebuild (PMD + WAPDA): parse the supplied files, render the full analysis from an empty cache_R/, then the checks
# (unit tests, 17 paths, 16 number trace, 18 warnings) and 21_changes_v3.R. Log: logs/rebuild_v3.log.
# Usage (from analysis/): Rscript scripts/22_rebuild_v3.R <lib1;lib2;...>   libraries searched in that order, then .Library
# On this machine the first library holds a pure-R goftest placeholder (goftest.dll is blocked by Smart App Control; lmomco
# imports goftest::pCvM, which SPEI never reaches) and a ragg 1.5.2 build that the policy allows (DEVIATIONS D25).
args <- commandArgs(trailingOnly = TRUE); stopifnot(length(args) == 1)
libs <- strsplit(args[1], ";", fixed = TRUE)[[1]]
stopifnot(nzchar(Sys.getenv("P6_RESUME")) || length(list.files("cache_R")) == 0)   # P6_RESUME: continue from cache_R/ written by this code
log <- file.path("logs", "rebuild_v3.log"); cat("", file = log)
say <- function(...) { m <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", ...); cat(m, "\n"); cat(m, "\n", file = log, append = TRUE) }
if (nzchar(Sys.getenv("P6_PANDOC"))) Sys.setenv(RSTUDIO_PANDOC = Sys.getenv("P6_PANDOC"))   # folder holding pandoc.exe (e.g. the p6drought conda env Library/bin)
rscript <- file.path(R.home("bin"), "Rscript"); t0 <- Sys.time()
run <- function(label, lines) {
  f <- tempfile(fileext = ".R"); writeLines(c(sprintf(".libPaths(c(%s, .Library))", paste(deparse(libs), collapse = "")), lines), f)
  out <- file.path("logs", paste0("rebuild_v3_", label, ".out")); t1 <- Sys.time()
  st <- system2(rscript, c("--vanilla", f), stdout = out, stderr = out)
  say(label, ": exit ", st, " in ", round(difftime(Sys.time(), t1, units = "mins"), 1), " min (", out, ")"); st }
say("libraries: ", paste(libs, collapse = " ; "))
st <- c(parse = run("parse", c('.libPaths(c(.libPaths(), Sys.getenv("R_LIBS_USER")))', 'source("scripts/05_read_pmd_wapda.R")')))
for (i in 1:3) { st["render"] <- run(paste0("render_try", i), 'rmarkdown::render("Potohar_Drought_Analysis.Rmd", quiet = TRUE)')
  if (st["render"] == 0) break }      # a retry resumes from the cache_R/ files already written
if (st["render"] != 0) { say("render failed; checks not run"); quit(status = 1) }
st["tests"] <- run("tests", c('r <- as.data.frame(testthat::test_dir("tests", stop_on_failure = FALSE))',
  'cat("tests:", sum(r$passed), "passed,", sum(r$failed), "failed,", sum(r$error), "errors\\n"); if (sum(r$failed) + sum(r$error)) quit(status = 1)'))
for (s in c("17_check_paths.R", "16_check_number_trace.R", "18_explain_warnings.R", "21_changes_v3.R")) st[s] <- run(sub("\\.R$", "", s), sprintf('source("scripts/%s")', s))
say("total ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min; status: ", paste(names(st), st, sep = "=", collapse = ", "))
if (any(st != 0)) quit(status = 1)
