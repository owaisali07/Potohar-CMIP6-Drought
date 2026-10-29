# v3: parsers for the PMD daily station files and the WAPDA (SWHP) discharge yearbook sheets (used by scripts/05_read_pmd_wapda.R;
# unit tests in tests/test_pmd_wapda.R). Only parsing and gross-error QC; all statistics are in Potohar_Drought_Analysis.Rmd.
library(data.table)

# ---------------- PMD: tab-separated year, month (number or 3-letter name), day, P (mm), Tmax, Tmin (degC) ----------------
read_pmd <- function(f, station) {
  x <- fread(f, header = FALSE, sep = "\t", fill = Inf, colClasses = "character")[, 1:6]
  setnames(x, c("y", "m", "d", "prcp", "tmax", "tmin"))
  mm <- match(tolower(trimws(x$m)), tolower(month.abb)); x[, m := fifelse(is.na(mm), suppressWarnings(as.integer(m)), mm)]
  x[, date := as.IDate(sprintf("%s-%02d-%02d", trimws(y), m, as.integer(d)))]
  stopifnot(!anyNA(x$date))
  log <- list()
  # a year whose labels repeat a date but whose row count equals the days in the year is re-dated as consecutive days
  # (Islamabad 2004: 29 Feb missing, 31 Dec twice; consecutive dating raises r with Chaklala daily P from 0.15 to 0.58)
  for (yy in unique(x[duplicated(date), y])) { i <- which(x$y == yy)
    nd <- as.integer(as.IDate(paste0(as.integer(yy) + 1, "-01-01")) - as.IDate(paste0(yy, "-01-01")))
    stopifnot(length(i) == nd); x[i, date := seq(as.IDate(paste0(yy, "-01-01")), by = 1, length.out = nd)]
    log[[length(log) + 1]] <- data.table(station, variable = "date", check = paste0(yy, ": duplicated label, rows re-dated as consecutive days"), n = nd) }
  stopifnot(!anyDuplicated(x$date))
  for (v in c("prcp", "tmax", "tmin")) {
    raw <- trimws(x[[v]]); val <- suppressWarnings(as.numeric(raw))
    log[[length(log) + 1]] <- data.table(station, variable = v, check = "missing code (<= -99) or blank", n = sum(is.na(val) | val <= -99))
    val[!is.na(val) & val <= -99] <- NA
    set(x, j = v, value = val)
  }
  log[[length(log) + 1]] <- data.table(station, variable = "prcp", check = "trace (0.01 mm) set to 0", n = x[prcp > 0 & prcp < 0.05, .N])
  x[prcp > 0 & prcp < 0.05, prcp := 0]
  # gross-error limits as for the GSOD/GHCN-D records in the Rmd
  q <- list(tmax = x$tmax < -25 | x$tmax > 52, tmin = x$tmin < -25 | x$tmin > 45, prcp = x$prcp < 0 | x$prcp > 400)
  for (v in names(q)) { b <- which(q[[v]]); log[[length(log) + 1]] <- data.table(station, variable = v, check = "outside gross-error limits", n = length(b)); set(x, b, v, NA_real_) }
  b <- which(x$tmax < x$tmin); log[[length(log) + 1]] <- data.table(station, variable = "tmax,tmin", check = "Tmax < Tmin (both removed)", n = length(b))
  set(x, b, "tmax", NA_real_); set(x, b, "tmin", NA_real_)
  list(data = x[, .(date, station, prcp, tmax, tmin)], log = rbindlist(log))
}

# ---------------- WAPDA/SWHP: one block per year (title, "(Year yyyy)", unit row, DAY header, days 1-31 with optional 10-day
# "Mean" rows, "Month Mean", ...). d: the sheet as a character data.frame (first column = labels, columns 2-13 = months).
parse_wapda_sheet <- function(d, gauge) {
  a <- trimws(d[[1]]); yi <- grep("\\(Year [0-9]{4}\\)", a)
  rbindlist(lapply(yi, function(i) {
    yr <- as.integer(gsub("[^0-9]", "", a[i])); h <- i + which(toupper(a[(i + 1):(i + 4)]) == "DAY")[1]
    stopifnot(!is.na(h)); hdr <- unname(trimws(unlist(d[h, 2:13])))
    if (any(!is.na(hdr) & tolower(substr(hdr, 1, 3)) != tolower(month.abb))) stop(gauge, " ", yr, ": month header ", paste(hdr, collapse = ","))
    end <- h + which(grepl("^Month Mean", a[(h + 1):min(nrow(d), h + 45)]))[1]; rr <- (h + 1):(end - 1); rr <- rr[!grepl("^Mean", a[rr])]
    dn <- suppressWarnings(as.integer(a[rr]))   # 10-day "Mean" rows dropped; a blank day label is accepted if its position fits
    if (length(rr) != 31 || any(!is.na(dn) & dn != seq_along(rr))) stop(gauge, " ", yr, ": day column ", paste(a[rr], collapse = ","))
    blk <- d[rr, 1:13]
    rbindlist(lapply(1:12, function(m) { v <- suppressWarnings(as.numeric(blk[[m + 1]]))
      nd <- as.integer(format(seq(as.Date(sprintf("%d-%02d-01", yr, m)), by = "month", length.out = 2)[2] - 1, "%d"))
      data.table(date = as.IDate(sprintf("%d-%02d-%02d", yr, m, 1:nd)), gauge = gauge, q_m3s = v[1:nd], extra_after_month_end = sum(!is.na(v[-(1:nd)]))) }))
  }))
}
read_wapda <- function(f, gauge) {
  sh <- grep("cumecs", readxl::excel_sheets(f), value = TRUE); stopifnot(length(sh) == 1)        # m3/s sheet (the other sheet is cusecs)
  parse_wapda_sheet(as.data.frame(suppressMessages(readxl::read_excel(f, sheet = sh, col_names = FALSE, col_types = "text"))), gauge)
}
