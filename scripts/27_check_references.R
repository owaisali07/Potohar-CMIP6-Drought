# Cross-check every reference with a DOI against Crossref (title, first author, journal, volume, pages, year).
# Usage (from analysis/): Rscript scripts/27_check_references.R      -> manuscript/reference_check.csv
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root
R <- fread(file.path(ROOT, "manuscript", "references.txt"), sep = "|", header = FALSE, col.names = c("key", "text"), quote = "", encoding = "UTF-8")
R[, doi := sub("[).,;]+$", "", regmatches(text, regexpr("10\\.[0-9]{4,9}/[^ \\[]+", text)) [1]), by = key]
R[!grepl("10\\.", text), doi := NA_character_]
norm <- function(s) { s <- iconv(enc2utf8(as.character(s)), "UTF-8", "ASCII//TRANSLIT", sub = ""); s[is.na(s)] <- ""; tolower(gsub("[^A-Za-z0-9]", "", s)) }
chk <- rbindlist(lapply(seq_len(nrow(R)), function(i) { r <- R[i]
  if (is.na(r$doi)) return(data.table(ref = r$key, doi = NA, status = "no DOI", cr_title = NA, cr_first_author = NA, cr_journal = NA, cr_volume = NA, cr_pages = NA, cr_year = NA,
                                      title_match = NA, author_match = NA, year_match = NA, volume_match = NA, pages_match = NA))
  w <- tryCatch(jsonlite::fromJSON(paste0("https://api.crossref.org/works/", utils::URLencode(r$doi, reserved = TRUE)), simplifyVector = TRUE)$message, error = function(e) NULL)
  Sys.sleep(0.3)
  if (is.null(w)) return(data.table(ref = r$key, doi = r$doi, status = "DOI not found in Crossref (check DataCite/Zenodo)", cr_title = NA, cr_first_author = NA, cr_journal = NA,
                                    cr_volume = NA, cr_pages = NA, cr_year = NA, title_match = NA, author_match = NA, year_match = NA, volume_match = NA, pages_match = NA))
  g1 <- function(v) if (length(v) && !is.na(v[1])) as.character(v[1]) else NA_character_
  has <- function(p, t) !is.na(p) && nzchar(p) && grepl(p, t, fixed = TRUE)
  ti <- paste(w$title, collapse = " "); fa <- g1(w$author$family)
  yr <- tryCatch(as.character(w$issued$`date-parts`[[1]][1]), error = function(e) NA)
  jn <- paste(c(w$`container-title`, ""), collapse = "")[1]
  vol <- g1(w$volume); pg <- g1(c(w$page, w$`article-number`))
  txt <- r$text
  data.table(ref = r$key, doi = r$doi, status = "found", cr_title = ti, cr_first_author = fa, cr_journal = jn, cr_volume = vol, cr_pages = pg, cr_year = yr,
             title_match = grepl(substr(norm(ti), 1, 40), norm(txt), fixed = TRUE),
             author_match = has(norm(fa), norm(txt)),
             year_match = !is.na(yr) && grepl(paste0("(", yr, ")"), txt, fixed = TRUE),
             volume_match = is.na(vol) || grepl(paste0(" ", vol, ","), txt, fixed = TRUE) || grepl(paste0(" ", vol, " "), txt, fixed = TRUE),
             pages_match = is.na(pg) || grepl(norm(sub("-.*", "", pg)), norm(txt), fixed = TRUE))
}))
fwrite(chk, file.path(ROOT, "manuscript", "reference_check.csv"))
cat("references:", nrow(R), "| with DOI:", sum(!is.na(R$doi)), "| found:", sum(chk$status == "found"), "\n")
print(chk[status != "found" | !title_match | !author_match | !year_match | !volume_match | !pages_match, .(ref, status, cr_first_author, cr_year, cr_volume, cr_pages, title_match, author_match, year_match, volume_match, pages_match)])
