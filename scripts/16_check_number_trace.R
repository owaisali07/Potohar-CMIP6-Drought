# v2.2 Item 1 (PREREGISTRATION.md): every number printed in results_text/Results_Discussion.docx must be in
# results_text/Number_Trace.csv (written by 12_results_discussion.R) with an identical printed value, sign included (multiset match).
# Excluded by fixed patterns: years (1900-2100), GCM names, figure/table/equation/citation labels, dataset/version identifiers, SSP and
# index names, FAO-56, the 0.25°/0.05° grid labels and degree units of coordinates. Exit status 1 if any number is unmatched.
suppressMessages({ library(officer); library(data.table) })
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root
tx <- docx_summary(read_docx(file.path(ROOT, "results_text", "Results_Discussion.docx")))$text
tx <- tx[!grepl("^Traceability:", tx)]
# GCM identifiers (e.g. INM-CM4-8, CNRM-CM6-1) are names, not numbers: removed before extraction
GCMN <- unique(c(as.data.frame(readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))$gcm_rank)$model, names(cfg$models)))
for (g in GCMN[order(-nchar(GCMN))]) tx <- gsub(g, " ", tx, fixed = TRUE)
TR <- fread(file.path(ROOT, "results_text", "Number_Trace.csv"), colClasses = c(printed = "character"))
strip <- function(s) {
  pats <- c("\\[[0-9, –-]+\\]",                                   # citations [4], [4], [5]
            "(Fig\\.|Figs\\.|Table|Eq\\.) ?S?[0-9IVX]+[a-z,]*( ?[a-e](–[a-e])?)?",   # labels
            "SSP[0-9]-[0-9.]+", "(SPI|SPEI|RDI|RDIst|SRI|SDI)-k?[0-9]*", "SPEI-k", "SRI-1", "FAO-56", "CMIP6", "ERA5", "C3S", "GLO-[0-9]+",
            "v[0-9]+\\.[0-9]+", "CSIC/SPEI/2_10", "CRU TS 4\\.10", "SPAM2010", "WorldCover 2021", "MOD[0-9A-Z]+", "PM ET0", "ET0", "r1i1p1f[0-9]",
            "0\\.25°", "0\\.05°", "0\\.5°", "10th–90th", "(19[0-9][0-9]|20[0-9][0-9])-[0-9]{2}\\b", "\\b(19[0-9][0-9]|20[0-9][0-9]|2100)\\b",
            "km²", "m s⁻¹", "mm yr⁻¹", "× 10³", "decade⁻¹")
  keep_units <- c("km²", "m s⁻¹", "mm yr⁻¹", "× 10³", "decade⁻¹")
  for (p in pats) s <- if (p %in% keep_units) gsub(p, " ", s, fixed = TRUE) else gsub(p, " ", s, perl = TRUE)
  s }
nums <- unlist(lapply(tx, function(s) regmatches(strip(s), gregexpr("(?<![A-Za-z0-9_.])[+−-]?[0-9]+(\\.[0-9]+)?(?![0-9A-Za-z])", strip(s), perl = TRUE))[[1]]))
nums <- sub("^-", "−", nums)
logged <- TR$printed
avail <- table(logged); need <- table(nums)
bare <- function(x) sub("^[+−]", "", x)                     # a logged "+3.1" also covers a printed "3.1" after a typographic sign
avail_b <- table(bare(logged))
res <- rbindlist(lapply(names(need), function(n) { a <- if (n %in% names(avail)) avail[[n]] else 0L
  ab <- if (bare(n) %in% names(avail_b)) avail_b[[bare(n)]] else 0L
  data.table(number = n, printed_count = as.integer(need[[n]]), logged_count = a, logged_bare = ab, matched = a >= need[[n]]) }))   # v3.1: exact, sign-sensitive match (logged_bare kept for information)
out <- file.path(ROOT, "results_text", "Number_Trace_check.csv"); fwrite(res, out)
cat("numbers in text:", length(nums), "| distinct:", nrow(res), "| unmatched distinct:", sum(!res$matched), "\n")
if (any(!res$matched)) { print(res[matched == FALSE]); quit(status = 1) }
