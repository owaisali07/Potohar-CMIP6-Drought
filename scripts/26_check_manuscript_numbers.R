# Every number in manuscript/manuscript_source.txt must match a traced number (results_text/Number_Trace.csv, printed form or
# value rounded to the printed decimals), a value in the analysis tables (tables/*.csv, rounded) or an allowed constant.
# Writes manuscript/number_check.csv and lists the unmatched numbers for manual review.
# Usage (from analysis/): Rscript scripts/26_check_manuscript_numbers.R
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root
src <- readLines(file.path(ROOT, "manuscript", "manuscript_source.txt"), encoding = "UTF-8")
src <- src[!grepl("^@@(TITLE|AUTHORS|AFFIL|CORR|KEYWORDS)|^#", src)]
src <- gsub("\\[@[^]]+\\]", " ", src)                                                       # citations
src <- gsub("\\b(19|20)[0-9]{2}([–-](19|20)?[0-9]{2})?\\b", " ", src, perl = TRUE)          # years and year ranges
src <- gsub("(Fig\\.|Figs\\.|Table|Tables|Supplementary Table|Supplementary Fig\\.|Eq\\.|Figure) ?[0-9]+[a-e]?", " ", src, perl = TRUE)
src <- gsub("SSP[0-9]-[0-9.]+|CMIP6|ERA5(-Land)?|SPEI-?[0-9]+|SPI-?[0-9]+|RDIst-?[0-9]*|SRI-?[0-9]+|SDI|SRI|FAO-56|GLO-[0-9]+|v[0-9.]+|CRU TS 4\\.10|WMO 41577|ISIMIP3b|SPAM2010|WorldCover 2021|COD-AB|MOD[0-9A-Z]+|T_AND|F_[A-Za-z]|x_p|X_t|u2|NEX-GDDP-CMIP6|GDHY|[0-9]+(st|nd|th)", " ", src, perl = TRUE)
nums <- unlist(regmatches(src, gregexpr("(?<![A-Za-z0-9_.])[+−-]?[0-9]+(\\.[0-9]+)?(?![0-9A-Za-z])", src, perl = TRUE)))
nums <- sub("^[+−-]", "", nums)
TR <- fread(file.path(ROOT, "results_text", "Number_Trace.csv"), colClasses = c(printed = "character"))
known <- unique(sub("^[+−-]", "", TR$printed))
for (f in list.files(file.path(ROOT, "tables"), pattern = "[.]csv$", full.names = TRUE)) {
  x <- unlist(lapply(fread(f, colClasses = "character"), as.character))
  v <- suppressWarnings(as.numeric(unlist(regmatches(x, gregexpr("[0-9]+(\\.[0-9]+)?", x)))))
  v <- v[!is.na(v)]; known <- c(known, formatC(v, format = "f", digits = 0), formatC(v, format = "f", digits = 1), formatC(v, format = "f", digits = 2), as.character(v)) }
CONST <- c("1", "2", "3", "4", "5", "6", "7", "10", "12", "15", "16", "20", "25", "27", "40", "50", "70", "80", "90", "95", "100", "0.05", "0.25", "0.05", "1.5", "0.5",
           "0.408", "900", "273", "0.34", "0.01", "99.9", "11", "500", "1000", "1,000", "9.2", "2.5", "8", "0.14", "30", "2000")
known <- unique(c(known, CONST))
res <- data.table(number = nums)[, .(n = .N), by = number][, matched := number %in% known]
fwrite(res, file.path(ROOT, "manuscript", "number_check.csv"))
cat("numbers:", length(nums), "| distinct:", nrow(res), "| unmatched:", sum(!res$matched), "\n"); print(res[matched == FALSE])
