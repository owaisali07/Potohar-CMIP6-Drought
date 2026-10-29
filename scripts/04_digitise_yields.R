# Digitise official district wheat statistics -> analysis/data/yields/district_wheat.csv
# Sources (downloaded by 01j_download_yields.py):
#   PBS "Crops area and production by districts 1981-82 to 2008-09", Table 7 (Punjab wheat), p. 16
#   Open Data Pakistan / BoS Punjab CSVs, wheat area & production by district, 2007-08 to 2019-20
#   Punjab Development Statistics 2024, Tables 1.48 (area) and 1.52 (production), 2020-21 to 2022-23
# Area in 000 ha, production in 000 t, yield = production / area (t/ha). Harvest year = second year of "YYYY-YY".
# Chakwal district was created in 1985 from Jhelum and Attock (Talagang) tehsils: 1981-82 to 1983-84 values for
# Attock/Jhelum refer to the old boundaries and Chakwal is 0 -> those three years are flagged and excluded.
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))   # run from analysis/ (or set P6_CONFIG)
RAW <- file.path(cfg$paths$raw, "yields")
OUT <- file.path(cfg$paths$root, "data", "yields"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
UNITS <- c("Attock", "Rawalpindi", "Islamabad", "Jhelum", "Chakwal")
num <- function(x) as.numeric(gsub("[^0-9.]", "", x))

# ---- PBS Table 7 ----
pg <- pdftools::pdf_text(file.path(RAW, "pbs_area_production_by_districts_28yrs.pdf"))[16]
L <- strsplit(pg, "\n")[[1]]
L <- L[grepl("^\\s*(19|20)\\d{2}-\\d{2}\\s", L)]
stopifnot(length(L) >= 56)
parse_row <- function(l) { p <- strsplit(trimws(l), "\\s+")[[1]]; c(p[1], p[2:6]) }
M <- do.call(rbind, lapply(L[1:56], parse_row))
pbs <- data.table(season = M[, 1], block = rep(c("area", "prod"), each = 28))
for (j in seq_along(UNITS)) pbs[[UNITS[j]]] <- num(M[, j + 1])
pbs <- melt(pbs, id.vars = c("season", "block"), variable.name = "district")
pbs <- dcast(pbs, season + district ~ block, value.var = "value")
pbs[, source := "PBS Crops Area & Production by Districts 1981-82 to 2008-09, Table 7"]

# ---- Open Data Pakistan (BoS Punjab) ----
rd <- function(f, what) {
  x <- fread(file.path(RAW, f), header = TRUE)
  setnames(x, 1, "district"); x[, district := trimws(gsub("\\s+", " ", district))]
  x <- x[district %in% UNITS]
  melt(x, id.vars = "district", variable.name = "season", value.name = what)[, (what) := num(get(what))][]
}
od <- merge(rd("opendata_punjab_wheat_area_districts.csv", "area"), rd("opendata_punjab_wheat_production_districts.csv", "prod"),
            by = c("district", "season"))
od[, source := "Bureau of Statistics Punjab via Open Data Pakistan, 2007-08 to 2019-20"]

# ---- PDS 2024 Tables 1.48 / 1.52 (total = first number of each season pair) ----
pds_tab <- function(page, what) {
  t <- strsplit(pdftools::pdf_text(file.path(RAW, "PDS_2024.pdf"))[page], "\n")[[1]]
  rbindlist(lapply(UNITS, function(u) { l <- grep(paste0("^\\s*", u, "\\s+[0-9]"), t, value = TRUE)[1]   # skips "Rawalpindi Divn."
    v <- strsplit(trimws(sub(u, "", l)), "\\s+")[[1]]
    data.table(district = u, season = c("2020-21", "2021-22", "2022-23"), x = num(v[c(1, 3, 5)])) }))[, setnames(.SD, "x", what)]
}
pds <- merge(pds_tab(120, "area"), pds_tab(124, "prod"), by = c("district", "season"))
pds[, source := "Punjab Development Statistics 2024, Tables 1.48 and 1.52 (Crop Reporting Service)"]

# ---- Crop Reporting Service (CRS) Punjab, Final Rabi / Kharif Estimates books (agripunjab.punjab.gov.pk) ----
# Each district table has IRRI, UN-IRRI, TOTAL for the current and the previous season (+ % change). Numbers are
# assigned to columns by their right-edge position relative to the complete PUNJAB row; empty / "--" cells are 0.
# Murree (from 2022-23) is added back to Rawalpindi and Talagang to Chakwal, to keep the 1985 boundaries.
CRSD <- file.path(RAW, "crs"); ACRE <- 0.4046856; MAUND <- 0.04            # 1 acre in ha; CRS maund = 40 kg
POT <- c(Attock = "Attock", Rawalpindi = "Rawalpindi", Muree = "Rawalpindi", Murree = "Rawalpindi",
         Islamabad = "Islamabad", Jhelum = "Jhelum", Chakwal = "Chakwal", Cahkwal = "Chakwal", Talagang = "Chakwal")
tokpos <- function(l) { m <- gregexpr("--|-?[0-9][0-9,]*\\.?[0-9]*", l)[[1]]
  if (m[1] < 0) return(data.table(v = numeric(), e = integer()))
  tk <- gsub(",", "", regmatches(l, list(m))[[1]]); v <- rep(NA_real_, length(tk)); ok <- tk != "--"; v[ok] <- as.numeric(tk[ok])   # "--" = no entry
  data.table(v = v, e = as.integer(m + attr(m, "match.length") - 1)) }
crs_page <- function(txt, book, crop) {
  L <- strsplit(txt, "\n")[[1]]
  H <- toupper(paste(L[1:min(14, length(L))], collapse = " "))   # unit label of the table (some pages have none)
  kind <- if (grepl("PRODUCTION|TONS", H)) "prod" else if (grepl("YIELD|MDS|MAUND|KG", H)) "yield" else if (grepl("HECT", H)) "area_ha" else
    if (grepl("ACRE", H)) "area" else NA_character_
  pj <- grep("^\\s*(THE )?PUNJAB\\s+[0-9]", L); pj <- pj[vapply(pj, function(i) nrow(tokpos(L[i])) >= 6, logical(1))][1]   # skip the "PUNJAB 2023-24" title
  if (is.na(pj)) return(NULL)
  ref <- tokpos(L[pj])$e
  yr <- as.integer(sub(".*?((19|20)[0-9]{2})-[0-9]{2,4}.*", "\\1", grep("(19|20)[0-9]{2}-[0-9]{2}", L, value = TRUE)[1])) + 1L
  out <- list()
  for (l in L[-(1:pj)]) {
    nm <- trimws(sub("\\s+(--|[0-9]).*$", "", l)); if (!nm %in% names(POT) || nm %in% names(out)) next
    tk <- tokpos(substring(l, nchar(nm) + regexpr(nm, l, fixed = TRUE)))
    tk[, e := e + regexpr(nm, l, fixed = TRUE) + nchar(nm) - 1L]
    tk[is.na(v), v := 0]
    # split the numbers into a current and a previous block so that each block is a valid (IRRI, UN-IRRI, TOTAL) triple:
    # 3 numbers with IRRI + UN-IRRI = TOTAL, or 2 numbers (one of IRRI / UN-IRRI blank, so the two numbers are equal),
    # or a single TOTAL; a blank block means 0. Column positions decide only when the split is ambiguous.
    v <- tk$v; n <- length(v); ok3 <- function(a) abs(a[1] + a[2] - a[3]) <= pmax(1, 0.006 * a[3])   # tables are rounded per cell
    blk <- function(a) switch(length(a) + 1, c(0, 0, 0), c(0, a, a), if (abs(a[1] - a[2]) <= pmax(0.6, 0.01 * a[2])) c(0, a) else NULL,
                              if (ok3(a)) a else NULL, NULL)
    cands <- Filter(Negate(is.null), lapply(0:min(n, 3), function(k) { b1 <- blk(v[seq_len(k)]); b2 <- blk(v[setdiff(seq_len(n), seq_len(k))])
      if (is.null(b1) || is.null(b2) || n - k > 3) NULL else list(k = k, x = c(b1, b2)) }))
    cut <- (ref[3] + ref[4]) / 2; kpos <- sum(tk$e <= cut)
    x <- if (length(cands)) cands[[which.min(sapply(cands, function(cn) abs(cn$k - kpos)))]]$x else rep(NA_real_, 6)
    out[[nm]] <- data.table(book, crop, kind, unit_name = nm, district = POT[[nm]], harvest_year = c(yr, yr - 1L),
                            irri = x[c(1, 4)], unirri = x[c(2, 5)], total = x[c(3, 6)])
  }
  r <- rbindlist(out); if (nrow(r)) r[, punjab_total := tokpos(L[pj])$v[3]]; r
}
crs_book <- function(f, crop) {
  tx <- pdftools::pdf_text(file.path(CRSD, f)); kw <- if (crop == "wheat") "WHEAT" else "GROUND ?NUT"
  pg <- which(grepl(kw, toupper(tx)) & grepl("ATTOCK", toupper(tx)) & grepl("ESTIMATE", toupper(tx)))
  r <- rbindlist(lapply(pg, function(i) crs_page(tx[i], f, crop)))
  cat(sprintf("%-24s %-9s pages %-18s rows %d\n", f, crop, paste(pg, collapse = ","), nrow(r)))
  if (!nrow(r)) return(NULL)
  # unlabelled tables: hectares if the PUNJAB total is 0.4047 x the acre table, yield if tiny, otherwise production
  a0 <- r[kind == "area", punjab_total[1]]
  r[is.na(kind), kind := fifelse(abs(punjab_total / a0 - ACRE) < 0.01, "area_ha", fifelse(punjab_total / a0 < 0.05, "yield", "prod"))]
  r[kind %in% c("area", "prod")][, .SD[1], by = .(kind, unit_name, harvest_year)]   # first acre / production table
}
CB <- rbindlist(c(lapply(list.files(CRSD, "^Rabi_.*pdf$"), crs_book, crop = "wheat"),
                  lapply(list.files(CRSD, "^Kharif_.*pdf$"), crs_book, crop = "groundnut")), fill = TRUE)
CB[, chk := abs(irri + unirri - total) <= pmax(1, 0.02 * total)]
cat("CRS book rows:", nrow(CB), "; rows that could not be split into valid IRRI/UN-IRRI/TOTAL triples:", sum(is.na(CB$total)), "\n")
if (any(is.na(CB$total))) print(CB[is.na(total), .(book, kind, unit_name, harvest_year)])
# Units are summed to the 1985 districts within each book (a book either lists Talagang / Murree separately or includes them
# in Chakwal / Rawalpindi). A district-season is complete in a book if no unit failed to parse and no unit reports area but no
# production (e.g. Talagang groundnut 2024-25 is blank in both books -> NA). Each district-season is then taken from its own
# book (current-season columns); the next book's previous-season columns are used only if the own book is incomplete.
CB[, current := harvest_year == max(harvest_year), by = book]
U <- dcast(CB[kind %in% c("area", "prod")], crop + book + current + unit_name + district + harvest_year ~ kind, value.var = c("irri", "unirri", "total"))
U[, bad := is.na(total_area) | is.na(total_prod) | (total_area > 0 & total_prod == 0)]
BD <- U[, .(irri_area = sum(irri_area), unirri_area = sum(unirri_area), total_area = sum(total_area), irri_prod = sum(irri_prod),
            unirri_prod = sum(unirri_prod), total_prod = sum(total_prod), complete = !any(bad)), by = .(crop, book, current, district, harvest_year)]
CBW <- BD[order(-complete, -current, book)][, .SD[1], by = .(crop, district, harvest_year)]
CBW[complete == FALSE, `:=`(total_prod = NA_real_, irri_prod = NA_real_, unirri_prod = NA_real_)]
cat("CRS district-seasons without complete area + production in any book:\n"); print(CBW[complete == FALSE, .(crop, district, harvest_year)])
# wheat: area '000 acres, production '000 t; groundnut: area acres, production t
CBW[, f_area := fifelse(crop == "wheat", ACRE, ACRE / 1000)][, f_prod := fifelse(crop == "wheat", 1, 1 / 1000)]
CBW[, `:=`(area_000ha = total_area * f_area, rainfed_area_000ha = unirri_area * f_area, production_000t = total_prod * f_prod,
           rainfed_prod_000t = unirri_prod * f_prod)]
CBW[, `:=`(yield_t_ha = fifelse(total_area > 0, production_000t / area_000ha, NA_real_),
           rainfed_share_area = fifelse(total_area > 0, unirri_area / total_area, NA_real_),
           yield_rainfed_t_ha = fifelse(unirri_area > 0 & unirri_prod > 0, rainfed_prod_000t / rainfed_area_000ha, NA_real_))]
bad <- CBW[total_area > 0 & (rainfed_share_area > 1.001 | yield_t_ha > 6)]
if (nrow(bad)) { cat("WARNING: implausible CRS rows\n"); print(bad[, .(crop, district, harvest_year, total_area, unirri_area, total_prod)]) }
CBW[, season := paste0(harvest_year - 1L, "-", substr(harvest_year, 3, 4))]
crs_cols <- c("district", "season", "harvest_year", "area_000ha", "rainfed_area_000ha", "rainfed_share_area", "production_000t",
              "yield_t_ha", "yield_rainfed_t_ha")
setorder(CBW, crop, district, harvest_year)
fwrite(CBW[crop == "wheat", ..crs_cols][, source := "CRS Punjab, Final Rabi Estimates books"], file.path(OUT, "district_wheat_irrigation_crs.csv"))
fwrite(CBW[crop == "groundnut", ..crs_cols][, source := "CRS Punjab, Final Kharif Estimates books"], file.path(OUT, "district_groundnut.csv"))
print(CBW[, .(seasons = paste(range(harvest_year), collapse = "-"), n = .N, rainfed_share = round(mean(rainfed_share_area, na.rm = TRUE), 3)), by = .(crop, district)])

# ---- CRS "WHEAT HISTORICAL" (1990-91..2021-22) and "Historical Data Wheat (Districtwise) 2022-25": totals by district ----
crs_hist <- function(f) {
  tx <- pdftools::pdf_text(file.path(CRSD, f))
  rbindlist(lapply(seq_along(tx), function(i) { L <- strsplit(tx[i], "\n")[[1]]
    if (!any(grepl("^\\s*Districts", L))) return(NULL)
    kind <- if (any(grepl("Production", L[1:3]))) "prod" else if (any(grepl("Yield", L[1:3]))) "yield" else "area"
    h1 <- L[grep("^\\s*Districts", L) - 1]; y0 <- as.integer(regmatches(h1, gregexpr("(19|20)[0-9]{2}", h1))[[1]])
    rbindlist(lapply(names(POT), function(u) { l <- grep(paste0("^\\s*", u, "\\s+[0-9]"), L, value = TRUE)[1]; if (is.na(l)) return(NULL)
      v <- as.numeric(strsplit(trimws(sub(u, "", l)), "\\s+")[[1]]); v <- v[seq_len(min(length(v), length(y0)))]
      data.table(kind, unit_name = u, district = POT[[u]], harvest_year = y0[seq_along(v)] + 1L, value = v) })) }))
}
CH <- rbindlist(lapply(c("WHEAT_HISTORICAL.pdf", "Historical_Wheat_districtwise_2022_25.pdf"), crs_hist))
CH <- dcast(CH[kind != "yield", .(value = sum(value)), by = .(kind, district, harvest_year)], district + harvest_year ~ kind)
CH[, `:=`(area = area * ACRE, prod = prod)][, season := paste0(harvest_year - 1L, "-", substr(harvest_year, 3, 4))]
CH[, source := "Crop Reporting Service Punjab, district-wise historical wheat data (1990-91 to 2024-25)"]
bk <- merge(CBW[crop == "wheat", .(district, harvest_year, a_book = area_000ha, p_book = production_000t)], CH[, .(district, harvest_year, area, prod)],
            by = c("district", "harvest_year"))
bk[, dev := pmax(abs(a_book / area - 1), abs(p_book / prod - 1))]
cat("Rabi books vs CRS historical data (wheat totals):", nrow(bk), "district-seasons; max deviation", round(100 * max(bk$dev), 2), "%\n")
if (any(bk$dev > 0.03)) print(bk[dev > 0.03])
# the newest CRS season(s) also come from the Rabi books (2025-26)
new <- rbind(CH[harvest_year >= 2024, .(district, season, area, prod, source)],
             CBW[crop == "wheat" & harvest_year > max(CH$harvest_year), .(district, season, area = area_000ha, prod = production_000t,
                                                                            source = "CRS Punjab, Final Rabi Estimates book")])

# ---- combine (priority: PBS to 2006-07, BoS 2007-08..2019-20, PDS 2020-21..2022-23, CRS 2023-24..) ----
all <- rbindlist(list(pbs[, .(district, season, area, prod, source)], od[, .(district, season, area, prod, source)],
                      pds[, .(district, season, area, prod, source)], new))
cc <- merge(all[, .(district, season, y_off = prod / area)], CH[, .(district, season, y_crs = prod / area)], by = c("district", "season"))
cat("Cross-check of the series against CRS historical data: r =", round(cor(cc$y_off, cc$y_crs, use = "complete.obs"), 4),
    "; median |diff| =", round(100 * median(abs(cc$y_off / cc$y_crs - 1), na.rm = TRUE), 2), "% (n =", nrow(cc), ")\n")
fwrite(cc, file.path(OUT, "crosscheck_official_vs_crs.csv"))
all[, harvest_year := as.integer(substr(season, 1, 4)) + 1L]
ov <- merge(pbs[season %in% c("2007-08", "2008-09"), .(district, season, y_pbs = prod / area)],
            od[season %in% c("2007-08", "2008-09"), .(district, season, y_bos = prod / area)], by = c("district", "season"))
cat("Overlap check PBS vs BoS (t/ha):\n"); print(ov[, .(district, season, y_pbs = round(y_pbs, 3), y_bos = round(y_bos, 3))])
all <- all[!(grepl("^PBS", source) & season %in% c("2007-08", "2008-09"))]
all[, yield_t_ha := fifelse(area > 0, prod / area, NA_real_)]
all[, flag := fifelse(harvest_year <= 1984, "pre-1985 boundaries (Chakwal not yet created): excluded", "")]
setorder(all, district, harvest_year)
fwrite(all[, .(district, season, harvest_year, area_000ha = area, production_000t = prod, yield_t_ha = round(yield_t_ha, 4), source, flag)],
       file.path(OUT, "district_wheat.csv"))
cat("written", nrow(all), "rows;", paste(range(all$harvest_year), collapse = "-"), "\n")
print(all[flag == "", .(n = .N, mean_yield = round(mean(yield_t_ha, na.rm = TRUE), 2)), by = district])
