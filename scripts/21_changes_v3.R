# v3 / v3.1 (PMD stations + WAPDA gauges; code-audit fixes): CHANGES_v3.md and ../audit/RealData_v3_headline_changes.csv
# v2.2 = results_text/key_numbers.json at git tag v2.2-pre-realdata; v3 = ../audit/key_numbers_v3.json (saved before the v3.1 rebuild);
# v3.1 = the current results_text/key_numbers.rds. Run from analysis/ after the rebuild (needs git on the PATH).
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root; AUD <- file.path(cfg$paths$paper_root, "audit")
K3 <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))
K1 <- jsonlite::fromJSON(paste(system2("git", c("-C", shQuote(ROOT), "show", "v2.2-pre-realdata:results_text/key_numbers.json"), stdout = TRUE), collapse = "\n"))
K2 <- jsonlite::fromJSON(file.path(AUD, "key_numbers_v3.json"))
KS <- list(K1, K2, K3)
dt <- function(x) as.data.table(x)
g <- function(expr) tryCatch(expr, error = function(e) "–")
f1 <- function(x, d = 1) if (length(x) == 0 || all(is.na(x))) "–" else paste(formatC(as.numeric(x), format = "f", digits = d), collapse = " / ")
E <- function(K, s, m = "d_freq", p = "far") dt(K$ens_changes)[scenario == s & period == p & metric == m]$wmean
T25 <- function(K, st, est = "bernstein") dt(K$copula_T)[T_ref == 25 & estimator == est & set == st]$T_and
EXW <- function(K, s) dt(K$exposure_graded)[district == "Potohar (all units)" & scenario == s & period == "far"]$dE_wheat_pct
HS <- function(K, yr) dt(K$hs_fractions)[grepl("^\\(a\\)", what) & year == yr & source == "model"]$frac
far_sets <- c("SSP2-4.5 far", "SSP5-8.5 far")
row <- function(lab, fun) { v <- vapply(KS, function(K) as.character(g(fun(K))), ""); data.table(Quantity = lab, `v2.2 (open data only)` = v[1], `v3 (PMD + WAPDA)` = v[2], `v3.1 (code fixes)` = v[3]) }
prop <- function(K) paste0("k = ", K$propagation$best_k, ", lag ", K$propagation$best_lag, ", r = ", f1(K$propagation$r, 2))
T <- rbindlist(list(
  row("Stations accepted (P + ET0)", function(K) paste(K$stations_v2$accepted_P_ET0, collapse = ", ")),
  row("Stations used for station-based evaluation (P / ET0)", function(K) if (is.null(K$station_eligibility)) "all accepted stations in the domain" else {
      e <- dt(K$station_eligibility); paste0(paste(e[eval_P == TRUE, station], collapse = ", "), " / ", paste(e[eval_ET0 == TRUE, station], collapse = ", ")) }),
  row("ERA5-Land PM ET0 vs station ET0: r (per evaluated station)", function(K) f1(dt(K$et0_skill)[grid == "ERA5L"]$r, 2)),
  row("Hydrological input for propagation", function(K) if (is.null(K$propagation$source)) K$glofas$source else paste0(K$propagation$source, ", ", K$propagation$period)),
  row("Propagation, Dhok Pathan: best k, lag, r", prop),
  row("Propagation, Chirah (lag 0): k, r", function(K) paste0("k = ", K$propagation$chirah_best_k, if (!is.null(K$propagation$chirah_r)) paste0(", r = ", f1(K$propagation$chirah_r, 2)) else "")),
  row("GloFAS vs WAPDA monthly KGE (Dhok Pathan / Chirah)", function(K) if (is.null(K$glofas_vs_wapda)) "not available" else f1(dt(K$glofas_vs_wapda)$KGE, 2)),
  row("Selected index (yield correlation)", function(K) paste(K$selected_index$index, K$selected_index$month, "r =", f1(K$selected_index$mean_r, 3))),
  row("Top-10 GCMs", function(K) paste(K$top_models, collapse = ", ")),
  row("Overlap with the v2.2 top 10", function(K) as.character(length(intersect(K1$top_models, K$top_models)))),
  row("Far Δ drought frequency (%-pt), SSP2-4.5 / SSP5-8.5", function(K) f1(c(E(K, "ssp245"), E(K, "ssp585")))),
  row("Far ΔP (%), SSP2-4.5 / SSP5-8.5", function(K) f1(c(E(K, "ssp245", "d_P"), E(K, "ssp585", "d_P")))),
  row("Far Δ drought frequency without / with QDM (%-pt), SSP5-8.5", function(K) if (is.null(dt(K$raw_vs_qdm)$dfreq_raw)) "–" else f1(dt(K$raw_vs_qdm)[scenario == "ssp585", c(dfreq_raw, dfreq_qdm)])),
  row("Duration margin of the pooled baseline fit", function(K) dt(K$copula_gof$pooled)[set == "Baseline (1985–2014)", marg_D]),
  row("Pooled sets passing the AD test for D", function(K) { p <- dt(K$copula_gof$pooled)[!grepl("Observed", set)]; paste0(sum(p$D_AD_p >= 0.05), " of ", nrow(p)) }),
  row("25-yr event T: baseline, Bernstein / count", function(K) f1(c(T25(K, "Baseline (1985–2014)"), T25(K, "Baseline (1985–2014)", "count")))),
  row("25-yr event T: far future (Bernstein), SSP2-4.5 / SSP5-8.5", function(K) f1(sapply(far_sets, function(s) T25(K, s)))),
  row("Table S6 baseline T (primary set) equals Table V", function(K) { m <- dt(K$model_set_sensitivity)[grepl("^primary [(]", set)]
      if (!nrow(m)) "–" else if (isTRUE(all(abs(m$T25_base / T25(K, "Baseline (1985–2014)") - 1) < 1e-4))) "yes" else "no" }),
  row("Far Δ graded rainfed-wheat exposure (%), SSP2-4.5 / SSP5-8.5", function(K) f1(c(EXW(K, "ssp245"), EXW(K, "ssp585")))),
  row("Exposure change SSP5-8.5 far: bootstrap 95% CI (%)", function(K) if (is.null(K$exposure_uncertainty)) "not computed" else
      f1(dt(K$exposure_uncertainty)[district == "Potohar (all units)" & scenario == "ssp585" & period == "far", c(ci_lo, ci_hi)])),
  row("Model share of uncertainty, drought frequency (2050 / 2095, %)", function(K) f1(c(HS(K, 2050), HS(K, 2095))))
))
T[, `Changed in v3.1` := fifelse(`v3 (PMD + WAPDA)` == `v3.1 (code fixes)`, "no", "yes")]
dir.create(AUD, showWarnings = FALSE); fwrite(T, file.path(AUD, "RealData_v3_headline_changes.csv"))
md <- c("# CHANGES v3 / v3.1 — PMD and WAPDA records, and code-audit fixes", "",
        "Generated by `scripts/21_changes_v3.R`. v2.2: `results_text/key_numbers.json` at git tag `v2.2-pre-realdata`; v3: `../audit/key_numbers_v3.json`; v3.1: the current `results_text/key_numbers.rds`. Reasons and methods: `DEVIATIONS.md`, sections v3 (D4, D22–D26) and v3.1 (C1–C9); `PREREGISTRATION.md`, post-hoc entries 7–8.", "",
        paste("|", paste(names(T), collapse = " | "), "|"), paste0(paste(rep("|---", ncol(T)), collapse = ""), "|"),
        apply(T, 1, function(r) paste("|", paste(gsub("\\|", "/", r), collapse = " | "), "|")))
writeLines(enc2utf8(md), file.path(ROOT, "CHANGES_v3.md"), useBytes = TRUE)
print(T)
