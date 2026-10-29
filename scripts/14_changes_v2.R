# CHANGES_v2.md: Issue | Action | Old result (v1, as reported) | New result (v2, from key_numbers.rds) | Status
suppressMessages(library(data.table))
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))   # run from analysis/ (or set P6_CONFIG)
ROOT <- cfg$paths$root
K <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))
f <- function(x, d = 1) formatC(as.numeric(x), format = "f", digits = d)
aw <- as.data.table(K$audit_wind_summary); ta <- K$trend_audit; b <- as.data.table(K$speibase_benchmark); pr <- K$propagation
E <- as.data.table(K$ens_changes); e <- function(s, m) E[scenario == s & period == "far" & metric == m, wmean]
SE <- as.data.table(K$seasonal_changes); se <- function(s, x) SE[scenario == s & period == "far" & season == x, d_freq]
CT <- as.data.table(K$copula_T); ct <- function(st, est) CT[set == st & T_ref == 25 & estimator == est, T_and]
X <- as.data.table(K$exposure); xf <- X[period == "far", .(p = 100 * sum(wheat_exp) / sum(wheat_total)), by = scenario]
hs <- as.data.table(K$hs_fractions); hm <- function(y) hs[grepl("Drought", what) & year == y & source == "model", frac]
qv <- as.data.table(K$qdm_validation_v2); v <- function(g, var, stg, col) qv[scheme_group == g & variable == var & stage == stg][[col]]
pe <- as.data.table(K$qdm_pooling_effect); pb <- K$pmd_bulletins; s3 <- if (!is.null(pb$scores)) as.data.table(pb$scores)[1] else NULL
gl <- K$glofas; cg <- K$copula_gof; es <- as.data.table(K$et0_skill)
rows <- list(
  c("1a NEX wind/radiation bias (unit or 10 m→2 m error?)", "Audited units/heights in code; recomputed raw-vs-station ratios at 8 station cells with ERA5-Land, TerraClimate and NEX",
    "NEX wind ≈3× station/TerraClimate (Chaklala 3.7 vs 2.5 and 1.2 m/s); Rs +23% vs TerraClimate; 'removed by QDM'",
    paste0("No unit/height error (all 10 m, m/s; u2 = 0.748·u10 applied in ET0). Median NEX/station wind ", f(aw$median_ratio_NEX_station), "× (", aw$n_stations, " stations), NEX/ERA5-Land ", f(aw$median_ratio_NEX_ERA5L),
           "×; NEX/ERA5-Land Rs ", f(aw$median_rs_ratio_NEX_ERA5L, 2), "×. Ratio > 1.3× so the QDM statement stands"), "fixed (verified)"),
  c("1b Trend claims", "Reported TFPW-MK p-values and the offset arithmetic",
    "P +56.4 mm/dec (p = 0.0009); ET0 +21.0 mm/dec (p = 0.0044, TerraClimate PM); 'ET0 offsets 37%'",
    paste0("P +", f(ta$P_slope_mm_dec), " mm/dec (p = ", f(ta$P_p, 4), "); ET0 +", f(ta$ET0_slope_mm_dec), " mm/dec (p = ", f(ta$ET0_p, 3), ", ERA5-Land PM); offset = ", f(ta$ET0_slope_mm_dec), "/", f(ta$P_slope_mm_dec),
           " = ", f(ta$offset_pct, 0), "% (ratio of Sen slopes; WB slope ", f(ta$WB_slope_mm_dec), " mm/dec, p = ", f(ta$WB_p, 2), ")"), "fixed"),
  c("2a ERA5-Land as primary PM input", "GEE ECMWF/ERA5_LAND MONTHLY_AGGR + HOURLY (wind speed) + DAILY_AGGR; PM ET0 primary, TerraClimate as sensitivity",
    "TerraClimate PM ET0 primary (1342 mm/yr)", paste0("ERA5-Land PM ET0 primary (", f(K$obs_annual_clim_1985_2014$ET0_pm, 0), " mm/yr); vs stations r = ", paste(f(es[grid == "ERA5L", r], 2), collapse = "/"),
                                                        ", bias ", paste(f(es[grid == "ERA5L", bias_pct], 0), collapse = "/"), "% (TerraClimate r = ", paste(f(es[grid == "TerraClimate", r], 2), collapse = "/"), ", bias ",
                                                        paste(f(es[grid == "TerraClimate", bias_pct], 0), collapse = "/"), "%)"), "fixed"),
  c("2b SPEIbase benchmark", "CSIC/SPEI/2_10 from GEE, area-weighted over the region", "CRU-based reproduction: r = 0.83 (SPEI-3)",
    paste0("SPEIbase v2.10: SPEI-3 r = ", f(b[scale == 3, r], 2), ", RMSE ", f(b[scale == 3, rmse], 2), "; SPEI-6 r = ", f(b[scale == 6, r], 2), ", RMSE ", f(b[scale == 6, rmse], 2)), "fixed"),
  c("2c CHIRPS / MODIS inputs", "Checked: CHIRPS 1981–2025 and MODIS 2000–2024 already complete locally; 3-source comparison (stations, CHIRPS, ERA5-Land) now uses ERA5-Land PM", "complete", "complete (no download needed)", "fixed"),
  c("3 Streamflow (SDI/SRI)", "GloFAS-ERA5 v4.0 historical from CEMS EWDS (cems-glofas-historical) with the provided key",
    "Open-Meteo GloFAS from 1997; SRI calibrated 1997–2024; propagation k = 1, lag 0, r = 0.53",
    paste0(gl$source, "; SRI calibrated ", paste(gl$ref, collapse = "–"), "; propagation k = ", pr$best_k, ", lag ", pr$best_lag, ", r = ", f(pr$r, 2)),
    if (identical(as.numeric(gl$ref), c(1985, 2014))) "fixed" else "limitation (EWDS download incomplete)"),
  c("4a District wheat yields", "Digitised PBS (1984-85–2008-09), BoS Punjab (2007-08–2019-20), PDS 2024 (2020-21–2022-23) and Crop Reporting Service Punjab district-wise historical data / Final Rabi Estimates (2023-24–2025-26) → data/yields/district_wheat.csv",
    "GDHY only: best SPEI-3 Dec, r = 0.665", paste0("Official (", sub(".* ", "", K$selected_index$source), "): best ", K$selected_index$index, " ", K$selected_index$month, ", r = ", f(K$selected_index$mean_r, 3), " (", K$selected_index$n_sig,
                                                     "/5 significant); GDHY with the same index r = ", f(as.data.table(K$yield_sel_in_gdhy)$mean_r, 3)), "fixed"),
  c("4a Groundnut yields", "CRS Punjab Final Kharif Estimates books 2018-19–2025-26 → data/yields/district_groundnut.csv; pooled correlation with indices ending Aug–Oct",
    "not available", { g <- K$groundnut_check; paste0(g$n, " district-seasons (sown ", g$seasons, "): SPEI-3 Sep r = ", f(as.data.table(g$reference)$r, 2), " (p = ", f(as.data.table(g$reference)$p, 3),
                                                       "); best ", as.data.table(g$best)$index, " ", as.data.table(g$best)$month, " r = ", f(as.data.table(g$best)$r, 2)) }, "fixed (short series)"),
  c("4a Rainfed share / crop areas", "CRS irrigated vs un-irrigated area by district (Rabi books 2011-12–2025-26, Kharif books 2017-18–2025-26); Table S2; exposure totals scaled to CRS rainfed area (2021-22–2023-24), SPAM2010 kept for within-district allocation",
    "SPAM2010 areas used directly (rainfed wheat ≈ 949 × 10³ ha)", { r <- K$rainfed_check; paste0("rainfed share of wheat: CRS ", f(100 * r$wheat_share_crs_2016_24, 0), "% vs SPAM ", f(100 * r$wheat_share_spam, 0),
                                                                   "%; SPAM rainfed wheat area = ", f(r$wheat_rf_kha_spam / r$wheat_rf_kha_crs_2011_13, 1), "× CRS; groundnut SPAM ", f(r$gnut_rf_kha_spam, 0), " vs CRS ", f(r$gnut_rf_kha_crs, 0), " × 10³ ha") }, "fixed"),
  c("4b Stations within 100 km", "All GSOD/ISD + GHCN-D within 100 km; ≥70% complete months; QM gap filling of P, Tmax, Tmin, dew point and wind from CHIRPS/ERA5-Land; SNHT/Pettitt rerun",
    "7 stations examined; 2 accepted (Chaklala, Jhelum; 80% rule); dew point/wind gaps filled by climatology",
    paste0(K$stations_v2$n_candidates, " stations examined; ", length(K$stations_v2$accepted_P_ET0), " accepted (", paste(K$stations_v2$accepted_P_ET0, collapse = ", "), ")"), "partly (open archives sparse before 2000)"),
  c("4c PMD/NDMC drought bulletins", "Wayback CDX snapshots of ndmc.pmd.gov.pk; English bulletins parsed for Potohar drought declarations",
    "not available (server error)", paste0(if (is.null(s3)) "monthly: none recovered" else paste0("monthly: ", pb$n_drought_bulletins, " bulletins (", pb$period, "); hit rate ", f(s3$hit_rate, 2), ", FAR ", f(s3$false_alarm_ratio, 2), " vs SPEI-3 ≤ −1"),
      { q <- K$pmd_quarterly; if (is.null(q)) "" else paste0("; quarterly (", q$period, "): ", q$n_declared, "/", q$n_quarterly, " issues declare Potohar drought/stress (", q$n_declared_boilerplate_only,
        " only verbatim-repeated text); ", q$original_with_spei3_le_m1, " of ", q$n_original, " original declarations at SPEI-3 ≤ −1") }),
    "partly (no complete archive; bulletins not discriminating)"),
  c("5 Copula weakness", "Per-GCM fits on declustered events; 8 families; Kendall-τ check; parametric-bootstrap CvM (N = 1000); Bernstein copula primary if <80% pass; three estimators with bootstrap CIs",
    "Pooled Gumbel, GoF rejected (p = 0); 25-yr event T: baseline 31.9, far 8.7 (SSP2-4.5) / 7.3 (SSP5-8.5)",
    paste0(f(cg$pass_pct, 0), "% of GCM fits pass → primary: ", cg$primary, "; 25-yr event T (Bernstein): baseline ", f(ct("Baseline (1985–2014)", "bernstein")), ", far ", f(ct("SSP2-4.5 far", "bernstein")), " / ", f(ct("SSP5-8.5 far", "bernstein"))),
    "fixed"),
  c("6 Split-sample validation", "Detrended split, odd/even years, pseudo-reality; quantile bias, KS, wet-month and drought-frequency bias",
    "Plain split: P mean abs bias 9.6% → 6.5%; Tmax 0.41 → 0.68 °C (worse)",
    paste0("Detrended: Tmax abs. median bias ", f(v("detrended split", "tasmax", "raw", "q50_abs"), 2), " → ", f(v("detrended split", "tasmax", "QDM", "q50_abs"), 2), " °C; P Q90 bias ",
           f(v("detrended split", "pr", "raw", "q90_abs"), 0), "% → ", f(v("detrended split", "pr", "QDM", "q90_abs"), 0), "%; P drought-frequency bias ", f(v("detrended split", "pr", "raw", "drought_bias")), " → ",
           f(v("detrended split", "pr", "QDM", "drought_bias")), " %-pt"), "fixed (P median/drought bias remains: limitation)"),
  c("7a QDM without pooling", "Full sensitivity run (10 GCMs)", "test cells only: raw +11.3%, per-month +19.6%, pooled +13.1%",
    paste0("far ΔP raw ", f(pe$dP_raw[1]), "/", f(pe$dP_raw[2]), "%, pooled ", f(pe$dP_pooled[1]), "/", f(pe$dP_pooled[2]), "%, per month (v2.2 primary) ", f(pe$dP_primary[1]), "/", f(pe$dP_primary[2]), "% (SSP2-4.5/SSP5-8.5)"), "fixed"),
  c("7b SDI baseline 1985–2014 vs 1997–2024", "SRI/SDI and propagation recomputed with both baselines", "1997–2024 only",
    { sb <- as.data.table(K$sdi_baseline_sens)[k == 3]; pa <- as.data.table(K$propagation_alt_1997_2024)
      paste0("SRI-3 series nearly identical (r = ", f(sb$r_SRI, 3), "), but SRI-3 drought months in 1997–2024 are ", f(sb$SRI_drought_pct_main), "% with the 1985–2014 calibration vs ",
             f(sb$SRI_drought_pct_alt), "% with 1997–2024 (discharge in 1997–2024 was low relative to 1985–2014); propagation k = ", K$propagation$best_k, ", r = ", f(K$propagation$r, 2), " (1985–2014) vs k = ", pa$k, ", r = ", f(pa$r, 2), " (1997–2024)") }, "fixed"),
  c("GCM ranking (consequence of 2a)", "Ranking recomputed with ERA5-Land ET0 reference", "top 10 incl. NorESM2-LM, CMCC-ESM2, MPI-ESM1-2-LR", paste0("top 10: ", paste(K$top_models, collapse = ", ")), "changed"),
  c("Projected drought frequency (consequence)", "Full rerun", "far Δfreq +7.7 / +10.6 %-pt (SSP2-4.5 / SSP5-8.5)", paste0("far Δfreq ", f(e("ssp245", "d_freq")), " / ", f(e("ssp585", "d_freq")), " %-pt; DJF ", f(se("ssp585", "DJF")), ", MAM ", f(se("ssp585", "MAM")), " (SSP5-8.5)"), "changed"),
  c("Exposure (consequence)", "Full rerun; crop areas scaled to CRS rainfed area", "95% of rainfed wheat exposed by 2076–2100 (SSP5-8.5); SPAM areas",
    paste0(f(xf[scenario == "ssp585", p], 0), "% (SSP5-8.5), ", f(xf[scenario == "ssp245", p], 0), "% (SSP2-4.5) of ", f(sum(X[period == "far" & scenario == "ssp585", wheat_total]) / 1e3, 0), " × 10³ ha rainfed wheat"), "changed"),
  c("Uncertainty partition (consequence)", "Full rerun", "model share 68% (2050), 75% (2095)", paste0("model share ", f(hm(2050), 0), "% (2050), ", f(hm(2095), 0), "% (2095)"), "changed")
)
D <- as.data.table(do.call(rbind, rows)); setnames(D, c("Issue", "Action", "Old result (v1)", "New result (v2)", "Status"))
esc <- function(x) gsub("\\|", "/", x)
md <- c("# CHANGES v2", "", "Every change requested in the v2 brief, with the v1 value as reported and the v2 value generated from `results_text/key_numbers.rds` (`scripts/14_changes_v2.R`).", "",
        "| Issue | Action | Old result (v1) | New result (v2) | Status |", "|---|---|---|---|---|",
        apply(D, 1, function(r) paste0("| ", paste(esc(r), collapse = " | "), " |")))
writeLines(md, file.path(ROOT, "CHANGES_v2.md"), useBytes = TRUE)
cat("CHANGES_v2.md written:", nrow(D), "rows\n")
