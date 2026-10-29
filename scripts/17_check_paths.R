# v2.2 Item 6 (PREREGISTRATION.md): no absolute paths in code. Scans *.R, *.Rmd, *.py and *.ps1 under analysis/ (excluding
# archive/, renv/ and caches) for a path that starts with a drive letter, a colon and a slash, and exits with status 1 if any is found.
# Machine-specific locations live in config.yaml (read at run time) or come from environment variables.
root <- if (nzchar(Sys.getenv("P6_ROOT"))) Sys.getenv("P6_ROOT") else "."
files <- list.files(root, pattern = "\\.(R|Rmd|py|ps1)$", recursive = TRUE, full.names = TRUE)
files <- files[!grepl("(^|/)(archive|renv|cache_R|cache|\\.git)/", files)]
pat <- "(^|[^A-Za-z0-9])[A-Za-z]:[\\\\/]"
hits <- do.call(rbind, lapply(files, function(f) { x <- readLines(f, warn = FALSE, encoding = "UTF-8"); i <- grep(pat, x, perl = TRUE)
  if (length(i)) data.frame(file = f, line = i, text = substr(trimws(x[i]), 1, 160)) else NULL }))
cat("files scanned:", length(files), "| lines with an absolute path:", if (is.null(hits)) 0 else nrow(hits), "\n")
if (!is.null(hits)) { print(hits, right = FALSE); quit(status = 1) }
