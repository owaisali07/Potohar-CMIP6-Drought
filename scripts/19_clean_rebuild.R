# v2.2 clean rebuild (PREREGISTRATION.md, "Rebuild"): restore the R library from renv.lock into an empty library, run the
# full analysis from an empty cache_R/ with only that library on the search path, then the checks:
#   unit tests (tests/), absolute-path check (17), number-trace check (16, 0 unmatched), warning explanations (18).
# Usage (from analysis/): Rscript scripts/19_clean_rebuild.R <new_library_dir>
# cache_R/ must be empty (move the old cache aside first; this script never deletes anything). Python steps are not re-run.
args <- commandArgs(trailingOnly = TRUE); stopifnot(length(args) == 1)
lib <- normalizePath(args[1], mustWork = FALSE); dir.create(lib, recursive = TRUE, showWarnings = FALSE)
stopifnot(length(list.files("cache_R")) == 0)
log <- file.path("logs", "rebuild_v22.log"); say <- function(...) { m <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", ...); cat(m, "\n"); cat(m, "\n", file = log, append = TRUE) }
cat("", file = log)
t0 <- Sys.time()
# Repositories: P6_RESTORE_REPOS (comma-separated URLs, tried in order) or the lockfile's. Without Rtools, locked versions
# that CRAN has since replaced exist only as source there; dated Posit Package Manager snapshots serve their Windows binaries.
rr <- Sys.getenv("P6_RESTORE_REPOS"); repos <- if (nzchar(rr)) setNames(strsplit(rr, ",")[[1]], paste0("R", seq_along(strsplit(rr, ",")[[1]]))) else NULL
say("restoring renv.lock into ", lib, if (length(repos)) paste0(" from ", paste(repos, collapse = " ; ")) else "")
renv::restore(lockfile = "renv.lock", library = lib, prompt = FALSE, clean = FALSE, repos = repos)
lk <- jsonlite::fromJSON("renv.lock")$Packages
bad <- names(lk)[vapply(names(lk), function(p) { v <- tryCatch(as.character(packageVersion(p, lib.loc = c(lib, .Library))), error = function(e) NA_character_)   # recommended packages live in .Library
  is.na(v) || package_version(v) != package_version(lk[[p]]$Version) }, TRUE)]
say("version check against renv.lock: ", length(lk) - length(bad), " of ", length(lk), " match", if (length(bad)) paste0("; MISMATCH: ", paste(bad, collapse = ", ")) else "")
if (length(bad)) quit(status = 1)
say("library restored: ", length(list.dirs(lib, recursive = FALSE)), " packages, ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
rscript <- file.path(R.home("bin"), "Rscript")
Sys.setenv(R_LIBS = lib, R_LIBS_USER = lib, R_LIBS_SITE = lib)   # child processes see only the restored library (+ .Library); system2(env=) is unsupported on Windows
run <- function(label, expr_file, args = character()) {
  t1 <- Sys.time(); out <- file.path("logs", paste0("rebuild_", label, ".out"))
  st <- system2(rscript, c("--vanilla", expr_file, args), stdout = out, stderr = out)
  say(label, ": exit ", st, " in ", round(difftime(Sys.time(), t1, units = "mins"), 1), " min (", out, ")"); st }
tmp <- tempfile(fileext = ".R")
writeLines(c(sprintf('.libPaths(%s)', deparse(lib)), 'cat("libPaths:", .libPaths(), "\\n")', 'rmarkdown::render("Potohar_Drought_Analysis.Rmd", quiet = TRUE)'), tmp)
st <- c(render = run("render", tmp))
tt <- tempfile(fileext = ".R"); writeLines(c(sprintf('.libPaths(%s)', deparse(lib)), 'r <- as.data.frame(testthat::test_dir("tests", stop_on_failure = FALSE))',
  'cat("tests:", sum(r$passed), "passed,", sum(r$failed), "failed,", sum(r$error), "errors\\n"); if (sum(r$failed) + sum(r$error)) quit(status = 1)'), tt)
st["tests"] <- run("tests", tt)
for (s in c("17_check_paths.R", "16_check_number_trace.R", "18_explain_warnings.R")) st[s] <- run(sub("\\.R$", "", s), file.path("scripts", s))
say("total ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min; status: ", paste(names(st), st, sep = "=", collapse = ", "))
if (any(st != 0)) quit(status = 1)
