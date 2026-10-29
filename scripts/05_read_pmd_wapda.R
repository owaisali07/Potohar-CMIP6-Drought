# v3: PMD daily station records and WAPDA (SWHP) daily discharge supplied by the author ("Real dataset/", 2026-10-23)
#   -> data/pmd/pmd_stations_daily.csv      date, station, prcp, tmax, tmin (mm, degC; missing = NA)
#   -> data/wapda/wapda_discharge_daily.csv date, gauge, q_m3s
#   -> data/pmd/pmd_qc_log.csv, data/wapda/wapda_qc_log.csv
# Parsers: scripts/R/pmd_wapda_helpers.R (unit tests: tests/test_pmd_wapda.R). All statistics are in Potohar_Drought_Analysis.Rmd.
# Usage (from analysis/): Rscript scripts/05_read_pmd_wapda.R
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))
ROOT <- cfg$paths$root; SRC <- file.path(cfg$paths$paper_root, "Real dataset")
source(file.path(ROOT, "scripts", "R", "pmd_wapda_helpers.R"))
dir.create(file.path(ROOT, "data", "pmd"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ROOT, "data", "wapda"), recursive = TRUE, showWarnings = FALSE)

P <- list(read_pmd(file.path(SRC, "ISLAMABAD.txt"), "Islamabad"), read_pmd(file.path(SRC, "MURREE.txt"), "Murree"))
PMD <- rbindlist(lapply(P, `[[`, "data")); PLOG <- rbindlist(lapply(P, `[[`, "log"))
fwrite(PMD, file.path(ROOT, "data", "pmd", "pmd_stations_daily.csv")); fwrite(PLOG, file.path(ROOT, "data", "pmd", "pmd_qc_log.csv"))
print(PLOG[n > 0])

W <- rbindlist(list(read_wapda(file.path(SRC, "Soan Rive at Dhok Pathan.xls"), "Dhok Pathan"),
                    read_wapda(file.path(SRC, "Soan River at Chirah.xls"), "Chirah"),
                    read_wapda(file.path(SRC, "Sil River Near Chahan.xls"), "Sil (Chahan)")))
stopifnot(!anyDuplicated(W[, .(date, gauge)]))
WLOG <- W[, .(first = min(date), last = max(date), n_days = .N, n_missing = sum(is.na(q_m3s)), n_negative = sum(q_m3s < 0, na.rm = TRUE),
              n_zero = sum(q_m3s == 0, na.rm = TRUE), values_after_month_end = sum(extra_after_month_end[!duplicated(paste(year(date), month(date)))]), mean_q = mean(q_m3s, na.rm = TRUE),
              max_q = max(q_m3s, na.rm = TRUE)), by = gauge]
W[q_m3s < 0, q_m3s := NA]
fwrite(W[, .(date, gauge, q_m3s)], file.path(ROOT, "data", "wapda", "wapda_discharge_daily.csv")); fwrite(WLOG, file.path(ROOT, "data", "wapda", "wapda_qc_log.csv"))
print(WLOG)
print(W[, .(missing_days = sum(is.na(q_m3s))), by = .(gauge, year = year(date))][missing_days > 0])
