# Results and Discussion (IEEE style, past tense) -> results_text/Results_Discussion.docx   [v2.2]
# Every number is read from results_text/key_numbers.rds (written by Potohar_Drought_Analysis.Rmd) and printed through a
# logging formatter (f, sg, pc, n_, lit); the log is results_text/Number_Trace.csv and is checked by
# scripts/16_check_number_trace.R. Every directional or comparative word comes from scripts/R/wording.R (PREREGISTRATION Item 1).
suppressMessages({ library(officer); library(data.table) })
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))   # run from analysis/ (or set P6_CONFIG)
ROOT <- cfg$paths$root
source(file.path(ROOT, "scripts", "R", "wording.R"))
K <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))

# ---------------- number formatting with trace log ----------------
TRACE <- list(); CUR_SEC <- "title"
.log <- function(printed, value, expr) { for (i in seq_along(printed))
  TRACE[[length(TRACE) + 1]] <<- data.table(section = CUR_SEC, printed = printed[i], value = as.numeric(value)[min(i, length(value))], expression = expr) ; printed }
.fmt <- function(x, d) sub("^-", "−", formatC(as.numeric(x), format = "f", digits = d))                 # typographic minus
f  <- function(x, d = 1) .log(.fmt(x, d), x, paste(deparse(substitute(x)), collapse = ""))
sg <- function(x, d = 1) { x <- as.numeric(x); .log(ifelse(x >= 0, paste0("+", .fmt(x, d)), paste0("−", .fmt(abs(x), d))), x, paste(deparse(substitute(x)), collapse = "")) }
pc <- function(x, d = 0) { s <- .fmt(100 * as.numeric(x), d); .log(s, 100 * as.numeric(x), paste(deparse(substitute(x)), collapse = "")); paste0(s, "%") }
n_ <- function(x) .log(as.character(as.integer(round(as.numeric(x)))), x, paste(deparse(substitute(x)), collapse = ""))   # counts
lit <- function(x, why) { z <- gsub("[^0-9.+-]", "", gsub("−", "-", x)); .log(as.character(x), if (grepl("^[+-]?[0-9]+\\.?[0-9]*$", z)) as.numeric(z) else NA_real_, paste0("constant: ", why)) }   # method constants (v3.1: signed)

TNR <- fp_text(font.family = "Times New Roman", font.size = 10)
doc <- read_docx()
H1 <- function(t) doc <<- body_add_fpar(doc, fpar(ftext(toupper(t), fp_text(font.family = "Times New Roman", font.size = 10)), fp_p = fp_par(text.align = "center", padding.top = 6, padding.bottom = 3)))
H2 <- function(t) { CUR_SEC <<- t; doc <<- body_add_fpar(doc, fpar(ftext(t, fp_text(font.family = "Times New Roman", font.size = 10, italic = TRUE)), fp_p = fp_par(padding.top = 4, padding.bottom = 2))) }
P <- function(...) doc <<- body_add_fpar(doc, fpar(ftext(paste0(...), TNR), fp_p = fp_par(text.align = "justify", padding.bottom = 3)))
doc <- body_add_fpar(doc, fpar(ftext("Future Droughts in the Potohar Plateau under CMIP6 Scenarios — Results and Discussion",
                                     fp_text(font.family = "Times New Roman", font.size = 12, bold = TRUE)), fp_p = fp_par(text.align = "center")))
H1("V. Results and Discussion")
yrs_rec <- function(a, b) (b - a + 1) / 10          # record length in decades (trend rule, PREREGISTRATION post-hoc 1)
trend_word <- function(slope_dec, mean_val, kind, p, decades) {
  if (kind == "relative") describe_change(mean_val, mean_val + slope_dec * decades, "relative", p = p) else describe_change(0, slope_dec * decades, kind, p = p) }
mon <- setNames(month.name, month.abb)

# ---------------- A. Observed climate and drought ----------------
cl <- K$obs_annual_clim_1985_2014; ta <- K$trend_audit; tr <- as.data.table(K$trends)
row <- function(pat) tr[grepl(pat, Variable, fixed = TRUE) & grepl("gridded", Series)][1]
st <- K$stations_v2; aw <- as.data.table(K$audit_wind_summary); es <- as.data.table(K$et0_skill)
sel <- K$selected_index; SEL <- sel$index
H2("A. Observed Climate and Drought, 1981–2024")
P("Over the four districts and ICT, the 1985–2014 mean annual precipitation was ", f(cl$P_chirps, 0), " mm in CHIRPS, ", f(cl$P_cru, 0),
  " mm in CRU TS 4.10 and ", f(cl$P_e5l, 0), " mm in ERA5-Land; June–September contributed ", f(K$monsoon_share_pct, 0),
  "% of the CHIRPS total, ", range_word(K$monsoon_share_pct, 70, 75), " the ", lit("70", "published range [4]"), "–", lit("75", "published range [4]"),
  "% reported for the Soan basin [4]. FAO-56 Penman–Monteith ET0 computed from the ERA5-Land inputs amounted to ", f(cl$ET0_pm, 0),
  " mm yr⁻¹, compared with ", f(cl$ET0_pm_tc, 0), " mm yr⁻¹ from TerraClimate inputs, ", f(cl$PET_tc, 0), " mm yr⁻¹ TerraClimate PET and ", f(cl$PET_cru, 0),
  " mm yr⁻¹ CRU TS PET. The Hargreaves estimate was ", f(cl$ET0_hg, 0), " mm yr⁻¹ (Fig. S1).")
ps <- as.data.table(K$pmd_share_days); e5k <- es[grid == "ERA5L"]; tck <- es[grid == "TerraClimate"]
EL <- as.data.table(K$station_eligibility); HO <- as.data.table(K$homogeneity)
el_sentence <- function() {   # v3.1: which stations enter the station-based evaluations, and why the others do not
  nrep <- EL[in_domain == TRUE & representative == FALSE]; nhw <- EL[hum_wind_obs_pct < 70]
  susp <- HO[class == "suspect" & station %in% EL$station]
  paste0("Station-based evaluations (GCM station skill, ET0 skill and station versus gridded indices) used only representative, homogeneous records, and stations in the same 0.25° cell were averaged into one value",
    if (nrow(nrep)) paste0("; ", paste0(nrep$station, " (", sg(nrep$dz_cell_m, 0), " m relative to its cell mean)", collapse = " and "), " exceeded the ", n_(K$station_dz_max), " m elevation limit") else "",
    if (nrow(susp)) paste0("; the relative homogeneity tests against two references (CHIRPS/ERA5-Land and TerraClimate) flagged ", paste0(susp$station, " ", susp$variable, collapse = ", "), " as suspect (both tests rejecting against both references), and these series were not used") else
      "; no series was flagged as suspect by the relative homogeneity tests against two references (CHIRPS/ERA5-Land and TerraClimate)",
    if (nrow(nhw)) paste0("; ET0 was not evaluated at ", paste(nhw$station, collapse = " and "), ", where less than ", lit("70", "completeness rule (%)"), "% of the months had observed humidity and wind") else "", ".") }
P("Fig. 1 shows the study area, the Soan basin and the station network. The PMD daily records of Islamabad and Murree (precipitation, Tmax and Tmin, 1961–2010) were merged into their WMO stations and supplied ",
  paste0(f(ps$pmd_pct_P_1981_2010, 0), "% of the 1981–2010 precipitation days at ", ps$station, collapse = " and "), ". Of the ", n_(st$n_candidates), " stations within ", lit("100", "station search radius (km)"),
  " km of the plateau, ", n_(length(st$accepted_P_ET0)), " (", paste(st$accepted_P_ET0, collapse = ", "), ") had at least ", lit("70", "completeness rule (%)"),
  "% complete months in 1985–2014 after quantile-mapping gap filling (Table I)", if (length(st$accepted_P_only)) paste0(", and ", paste(st$accepted_P_only, collapse = ", "), " met the rule for precipitation only") else "",
  ". ", el_sentence(), " Against the station Penman–Monteith ET0, ERA5-Land ET0 at the station cell gave ", paste0(e5k$station, " r = ", f(e5k$r, 2), " (bias ", sg(e5k$bias_pct, 0), "%)", collapse = "; "),
  ", and TerraClimate ", paste0(tck$station, " r = ", f(tck$r, 2), " (", sg(tck$bias_pct, 0), "%)", collapse = "; "),
  ". The ", lit("10", "wind measurement height (m)"), " m wind of ERA5-Land was ", compare_word(aw$median_ratio_ERA5L_station, 1), " the station mean (median ratio ",
  f(aw$median_ratio_ERA5L_station, 2), ") and that of TerraClimate ", compare_word(aw$median_ratio_TC_station, 1), " it (", f(aw$median_ratio_TC_station, 2), ").")
DT <- as.data.table(K$district_trends); fs <- K$fine_trend_sig_pct
dv <- function(pat) DT[grepl(pat, Variable, fixed = TRUE)]
dmean <- K$district_means_1981_2024                                      # district record means (for the relative trend rule)
dword <- function(d, kind) sapply(seq_len(nrow(d)), function(i) trend_word(d$`Sen slope`[i], if (kind == "relative") dmean[[d$var_key[i]]][[d$unit_key[i]]] else 0, kind, d$p_BH[i], yrs_rec(1981, 2024)))
dP <- dv("Annual precipitation"); dE <- dv("Annual PM ET0"); dW <- dv("Annual P − ET0"); dS <- dv("SPEI-12"); dM <- dv("Drought months")
wP <- dword(dP, "relative"); wE <- dword(dE, "relative"); wW <- dword(dW, "relative"); wS <- dword(dS, "index")
P("District-mean series were the primary basis for trend inference (TFPW–Mann–Kendall with Benjamini–Hochberg control across the five units; Table II). ",
  "Annual precipitation ", verb("increased"), " in ", n_(sum(wP == "increased")), " and ", verb("decreased"), " in ", n_(sum(wP == "decreased")), " of the ", n_(length(wP)), " units (Sen slopes ",
  sg(min(dP$`Sen slope`), 0), " to ", sg(max(dP$`Sen slope`), 0), " mm decade⁻¹); PM ET0 ", verb("increased"), " in ", n_(sum(wE == "increased")), " and ", verb("decreased"), " in ",
  n_(sum(wE == "decreased")), " units (", sg(min(dE$`Sen slope`), 0), " to ", sg(max(dE$`Sen slope`), 0), " mm decade⁻¹). The water balance P − ET0 ", verb("increased"), " in ",
  n_(sum(wW == "increased")), " units, December SPEI-12 in ", n_(sum(wS == "increased")), " and the number of ", SEL, " drought months was ", sig_word(0.5), " in ",
  n_(sum(dM$p_BH >= WCFG$alpha)), " units. On the 0.05° maps (Fig. 2c–e), Benjamini–Hochberg control left ", f(fs$P, 1), "% of the cells significant for precipitation, ",
  f(fs$ET0, 1), "% for ET0 and ", f(fs$SPEI12, 1), "% for SPEI-12", if (fs$SPEI12 == 0) "; the gridded SPEI-12 trend pattern is therefore not interpreted." else ".")
yrA <- yrs_rec(1981, 2024)
P("Averaged over all five units, annual precipitation ", verb(trend_word(ta$P_slope_mm_dec, cl$P_chirps, "relative", ta$P_p, yrA)), " (", sg(ta$P_slope_mm_dec), " mm decade⁻¹, p = ",
  f(ta$P_p, 4), "), PM ET0 ", verb(trend_word(ta$ET0_slope_mm_dec, cl$ET0_pm, "relative", ta$ET0_p, yrA)), " (", sg(ta$ET0_slope_mm_dec), " mm decade⁻¹, p = ", f(ta$ET0_p, 3),
  ") and the water balance P − ET0 ", verb(trend_word(ta$WB_slope_mm_dec, cl$P_chirps - cl$ET0_pm, "relative", ta$WB_p, yrA)), " (", sg(ta$WB_slope_mm_dec), " mm decade⁻¹, p = ", f(ta$WB_p, 2),
  "). The ET0 slope was ", f(ta$offset_pct, 0), "% of the precipitation slope (", f(ta$ET0_slope_mm_dec), "/", f(ta$P_slope_mm_dec), "). Tmax ",
  verb(trend_word(row("Mean Tmax")$`Sen slope`, 0, "degC", row("Mean Tmax")$p, yrA)), " (", sg(row("Mean Tmax")$`Sen slope`, 2), " °C decade⁻¹) and Tmin ",
  verb(trend_word(row("Mean Tmin")$`Sen slope`, 0, "degC", row("Mean Tmin")$p, yrA)), " (", sg(row("Mean Tmin")$`Sen slope`, 2), " °C decade⁻¹). December SPI-12 ",
  verb(trend_word(row("SPI-12")$`Sen slope`, 0, "index", row("SPI-12")$p, yrA)), " (", sg(row("SPI-12")$`Sen slope`, 2), " decade⁻¹, p = ", f(row("SPI-12")$p, 3), ") and December SPEI-12 ",
  verb(trend_word(row("SPEI-12")$`Sen slope`, 0, "index", row("SPEI-12")$p, yrA)), " (", sg(row("SPEI-12")$`Sen slope`, 2), " decade⁻¹, p = ", f(row("SPEI-12")$p, 2), ").")
yg <- as.data.table(K$yield_sel_in_gdhy); yo <- as.data.table(K$yield_top5); ygt <- as.data.table(K$yield_top5_gdhy)
same_gdhy <- isTRUE(ygt$index[1] == gsub("-", "", SEL) && ygt$month[1] == sel$month)
P("The official district wheat yields (Crop Reporting Service figures published by PBS, the Bureau of Statistics Punjab and the Agriculture Department Punjab, ",
  sub(".* ([0-9]{4}–[0-9]{4})$", "\\1", sel$source), ") correlated most strongly with ", SEL, " ending in ", mon[[sel$month]], " (mean r = ", f(sel$mean_r, 2), "; ", sig_word(0.01),
  " in ", n_(sel$n_sig), " of ", lit("5", "number of units"), " units; Fig. 3c), followed by ", sub("([A-Z]+)([0-9]+)", "\\1-\\2", yo$index[2]), " ending in ", mon[[yo$month[2]]],
  " (r = ", f(yo$mean_r[2], 2), "). With GDHY, the same index and month gave r = ", f(yg$mean_r, 2), if (same_gdhy) " and ranked first" else
    paste0(", and ", sub("([A-Z]+)([0-9]+)", "\\1-\\2", ygt$index[1]), " ending in ", mon[[ygt$month[1]]], " ranked first (r = ", f(ygt$mean_r[1], 2), ")"),
  "; the detrended official and GDHY yield anomalies were correlated at r = ", f(min(K$yield_off_vs_gdhy_r$r), 2), "–", f(max(K$yield_off_vs_gdhy_r$r), 2),
  " across districts. ", SEL, " was therefore used for the characteristics, projections and return periods.")
gn <- K$groundnut_check; gr <- as.data.table(gn$reference); gb <- as.data.table(gn$best)
P("For groundnut, the main Kharif crop, pooled yield anomalies of ", n_(length(gn$districts)), " districts (", n_(gn$n), " district-seasons, sowing years ", gn$seasons,
  ") correlated with SPEI-3 ending in September at r = ", f(gr$r, 2), " (p = ", f(gr$p, 3), ", ", sig_word(gr$p), "); the strongest correlation was with ",
  sub("([A-Z]+)([0-9]+)", "\\1-\\2", gb$index), " ending in ", mon[[gb$month]], " (r = ", f(gb$r, 2), ").")
oc <- as.data.table(K$obs_char)[index == gsub("-", "", SEL)]; ev <- as.data.table(K$obs_events_sel); cc <- as.data.table(K$concurrent_obs)[scale == 3]
vs <- as.data.table(K$vhi_spei_cor); vbest <- vs[which.max(r_SPEI)]
P("Run theory (threshold ", lit("−1", "run threshold"), ") identified ", n_(oc$n_events), " ", SEL, " events in 1981–2024 (", f(oc$events_per_decade), " per decade) with a mean duration of ",
  f(oc$D_mean), " months and mean severity of ", f(oc$S_mean, 2), "; the most severe began in ", format(as.Date(ev$start[1]), "%B %Y"), " (D = ", n_(ev$D[1]), ", S = ", f(ev$S[1]),
  ") and the second in ", format(as.Date(ev$start[2]), "%B %Y"), ". Concurrent drought (SPI-3 and SPEI-3 ≤ ", lit("−1.5", "concurrent threshold"), ") occurred in ", n_(cc$months_conc),
  " months (", f(cc$pct), "%). The cropland VHI was below ", lit("40", "VHI drought threshold"), " in ", f(K$vhi_drought_months_pct, 0), "% of months; among SPEI-k it correlated most strongly with SPEI-",
  n_(vbest$scale), " (r = ", f(vbest$r_SPEI, 2), ").")
b <- as.data.table(K$speibase_benchmark)
P("Against SPEIbase v2.10 (CSIC/SPEI/2_10, 1981–2023), the regional SPEI agreed with r = ", f(b[scale == 3, r], 2), " (RMSE ", f(b[scale == 3, rmse], 2), ") at ", lit("3", "SPEI accumulation scale (months)"), " months and r = ",
  f(b[scale == 6, r], 2), " (RMSE ", f(b[scale == 6, rmse], 2), ") at ", lit("6", "SPEI accumulation scale (months)"), " months, with ", pc(b[scale == 3, agree_drought]), " agreement in drought/no-drought classification; SPEIbase uses CRU TS inputs at 0.5° and the 1901–2023 calibration.")
cr <- as.data.table(K$crosscomp_regional); cs <- as.data.table(K$crosscomp_station)
cix <- if (nrow(cs[index == "SPEI3"])) "SPEI3" else "SPI3"; cixl <- sub("([0-9]+)$", "-\\1", cix)   # v3.1: SPEI only where a station has eligible P and ET0
rch <- cs[gridded == "CHIRPS" & index == cix, r]; re5 <- cs[gridded == "ERA5-Land" & index == cix, r]
P("Among the observational sources, regional SPEI-3 from ERA5-Land precipitation and ET0 correlated with the CHIRPS-based series at r = ", f(cr[`vs CHIRPS-PM` == "ERA5-Land" & index == "SPEI3", r], 2),
  " and that from CRU at r = ", f(cr[`vs CHIRPS-PM` == "CRU" & index == "SPEI3", r], 2), "; at the station cells, the CHIRPS-based ", cixl, " correlated with station ", cixl, " at r = ", f(rch, 2),
  ", ", compare_word(rch, re5, "relative"), " the ERA5-Land-based value (r = ", f(re5, 2), ")", if (cix == "SPI3") " (no station had both precipitation and ET0 eligible after the homogeneity tests, so SPEI was not compared at stations)" else "", ".")
RR <- as.data.table(K$rainfall_range)
if (nrow(RR)) { RR[, word := mapply(function(s, m, p) trend_word(s, m, "relative", p, yrs_rec(1985, 2024)), P_trend_mm_dec, P_1985_2014, P_trend_p)]
  P("Adding PERSIANN-CDR to CHIRPS, ERA5-Land and CRU TS (Table II rainfall-uncertainty range) gave 1985–2014 mean annual precipitation of ", f(min(RR$P_1985_2014), 0), "–", f(max(RR$P_1985_2014), 0),
    " mm across the four sources and SPI-3 drought frequencies of ", f(min(RR$SPI3_drought_pct_1985_2024), 1), "–", f(max(RR$SPI3_drought_pct_1985_2024), 1),
    "% (1985–2024); PERSIANN-CDR SPI-3 correlated with the CHIRPS series at r = ", f(RR[source == "PERSIANN-CDR", r_SPI3_vs_CHIRPS], 2), ". The 1985–2024 precipitation trend was: ",
    paste0(RR$source, " ", sg(RR$P_trend_mm_dec, 0), " mm decade⁻¹ (p = ", f(RR$P_trend_p, 3), "; ", RR$word, ")", collapse = "; "), ". ",
    if (length(unique(RR$word)) > 1) "The direction of the observed precipitation trend therefore depended on the product." else "All four products gave the same classification.") }
sm <- K$soil_moisture_check
if (!is.null(sm)) { smt <- as.data.table(sm$table); sb <- as.data.table(sm$best)
  P("Standardised C3S/ESA CCI soil-moisture anomalies (", sm$period, ", Table S5) correlated most strongly with ", sb$index, " (r = ", f(sb$r_all, 2), "; Rabi season r = ", f(sb$r_rabi, 2),
    "); SPEI-3 reached r = ", f(smt[index == "SPEI-3", r_all], 2), ", ", compare_word(smt[index == "SPEI-3", r_all], smt[index == "SPI-3", r_all]), " SPI-3 (r = ", f(smt[index == "SPI-3", r_all], 2),
    "), with ", pc(smt[index == "SPEI-3", drought_agree]), " agreement in drought/no-drought classification.") }
pb <- K$pmd_bulletins
if (!is.null(pb$scores)) { s3 <- as.data.table(pb$scores)[1]
  P("The ", n_(pb$n_drought_bulletins), " English-language NDMC drought bulletins recovered from Internet Archive snapshots (", pb$period, ") declared drought for the Potohar units in ",
    n_(s3$hits + s3$false_alarms), " months. Against regional SPEI-3 ≤ ", lit("−1", "run threshold"), ", the hit rate was ", f(s3$hit_rate, 2), " and the false-alarm ratio ", f(s3$false_alarm_ratio, 2), ".") }
pq <- K$pmd_quarterly
if (!is.null(pq)) P("The ", n_(pq$n_quarterly), " quarterly NDMC bulletins recovered for ", pq$period, " reported drought or moisture stress for the Potohar in ", n_(pq$n_declared),
  " issues; in ", n_(pq$n_declared_boilerplate_only), " of them the statement was repeated word for word from other years. Of the ", n_(pq$n_original),
  " original statements, ", n_(pq$original_with_spei3_le_m1), " coincided with regional SPEI-3 ≤ ", lit("−1", "run threshold"), " and ", n_(pq$original_with_spei3_lt_0), " with SPEI-3 < ", lit("0", "sign"),
  ". Of the ", n_(pq$spei3_le_m1_quarters), " quarters with SPEI-3 ≤ ", lit("−1", "run threshold"), ", ", n_(pq$spei3_le_m1_quarters_declared_original), " carried an original declaration.")

# ---------------- B. Propagation ----------------
pr <- K$propagation; pa <- as.data.table(K$propagation_alt_1997_2024); gl <- K$glofas
H2("B. Propagation from Meteorological to Hydrological Drought")
mo_ <- function(k) if (k == 1) " month" else " months"
wp <- K$wapda; pg <- K$propagation_glofas; pg0 <- K$propagation_glofas_1981_2003; gv <- as.data.table(K$glofas_vs_wapda); pt <- as.data.table(K$wapda_pettitt)
g_ <- function(x, col) gv[gauge == x][[col]]
P("WAPDA (SWHP) daily discharge was available for the Soan at Dhok Pathan (", substr(wp$records[gauge == "Dhok Pathan"]$first, 1, 4), "–", substr(wp$records[gauge == "Dhok Pathan"]$last, 1, 4),
  "), the Soan at Chirah and the Sil River near Chahan (", substr(wp$records[gauge == "Chirah"]$first, 1, 4), "–", substr(wp$records[gauge == "Chirah"]$last, 1, 4),
  "); gauge SRI and SDI were calibrated on ", paste(wp$ref, collapse = "–"), ", the part of the common baseline covered by the records. Each gauge was paired with the SPEI of its own catchment (the Soan basin to Dhok Pathan and the ",
  f(pr$chirah_catchment_km2, 0), " km² catchment of Chirah); the Sil gauge could not be located, so its catchment is undefined and it was used for SRI and SDI only. Catchment-mean SPEI-k correlated most strongly with SRI-1 at Dhok Pathan for k = ",
  n_(pr$best_k), mo_(pr$best_k), " at lag ", n_(pr$best_lag), " (r = ", f(pr$r, 2), ", ", pr$period, "; Fig. 3a,b); at lag ", lit("0", "lag (months)"), " the maximum occurred at k = ", n_(pr$chirah_best_k), mo_(pr$chirah_best_k),
  " at Chirah (r = ", f(pr$chirah_r, 2), "). With GloFAS-ERA5 SRI-1 over the same years, the maximum was at k = ",
  n_(pg0$best_k), mo_(pg0$best_k), ", lag ", n_(pg0$best_lag), " (r = ", f(pg0$r, 2), "), and over ", pg$period, " at k = ", n_(pg$best_k), mo_(pg$best_k), ", lag ", n_(pg$best_lag), " (r = ", f(pg$r, 2), ").",
  if (identical(as.numeric(gl$ref), c(1985, 2014))) paste0(" With GloFAS calibration and evaluation on 1997–2024 instead, the maximum was at k = ", n_(pa$k), ", lag ", n_(pa$lag), " (r = ", f(pa$r, 2), ").") else "")
P("Against the gauges (Table S7), monthly GloFAS-ERA5 discharge reached KGE = ", f(g_("Dhok Pathan", "KGE"), 2), " at Dhok Pathan and ", f(g_("Chirah", "KGE"), 2), " at Chirah (r = ", f(g_("Dhok Pathan", "r_Q"), 2), " and ",
  f(g_("Chirah", "r_Q"), 2), "; mean bias ", sg(g_("Dhok Pathan", "bias_pct"), 0), "% and ", sg(g_("Chirah", "bias_pct"), 0), "%). GloFAS SRI-3 correlated with gauge SRI-3 at r = ", f(g_("Dhok Pathan", "r_SRI3"), 2),
  " and ", f(g_("Chirah", "r_SRI3"), 2), ", and detected ", pc(g_("Dhok Pathan", "POD_SRI3")), " and ", pc(g_("Chirah", "POD_SRI3")), " of the gauge SRI-3 drought months (CSI ", f(g_("Dhok Pathan", "CSI_SRI3"), 2), " and ",
  f(g_("Chirah", "CSI_SRI3"), 2), "). The Pettitt test on annual mean flow gave ", paste0(pt$gauge, " p = ", f(pt$p, 3), " (", sapply(pt$p, sig_word), "; most probable change ", n_(pt$change_year), ")", collapse = ", "), ".")
if (identical(as.numeric(gl$ref), c(1985, 2014))) { sb <- as.data.table(K$sdi_baseline_sens)[k == 3]
  P("The SRI-3 series from the two calibrations correlated at r = ", f(sb$r_SRI, 2), "; the share of 1997–2024 months in SRI-3 drought was ", f(sb$SRI_drought_pct_main),
    "% with the 1985–2014 calibration and ", f(sb$SRI_drought_pct_alt), "% with the 1997–2024 calibration, i.e. ", compare_word(sb$SRI_drought_pct_main, sb$SRI_drought_pct_alt, "pp"),
    " with the recent-period baseline.") }

# ---------------- C. GCMs and bias correction ----------------
rk <- as.data.table(K$gcm_rank)[order(rank)]; top <- K$top_models; ov <- as.data.table(K$selection_overlap)
H2("C. GCM Performance and Bias Correction")
P("The ", n_(nrow(rk)), " NEX-GDDP-CMIP6 models were evaluated against CHIRPS (precipitation), ERA5-Land (Tmax, Tmin and PM ET0, the dataset that also provides the QDM targets) and the stations (Table III, Fig. 4). ",
  if (length(K$no_skill_models)) paste0(paste(K$no_skill_models, collapse = ", "), " had a negative precipitation KGE and was ranked last. ") else "No model had a negative KGE. ",
  "Models were selected by their probability of a top-", lit("10", "selection size"), " rank in ", n_(K$n_boot), " moving-block bootstrap replicates of 1985–2014 (entropy-weighted compromise programming, Table S2b). ",
  "The models retained were ", paste(top, collapse = ", "), "; ", rk$model[1], " came first (P(top ", lit("10", "selection size"), ") = ", f(rk$p_top10[1], 2), ", L = ", f(rk$L[1], 3), "). ",
  "The selection shared ", n_(ov[comparison == "v2.1 primary set", n_common]), " models with the v2.1 set (", if (nzchar(ov[comparison == "v2.1 primary set", dropped])) paste0("not retained: ", ov[comparison == "v2.1 primary set", dropped], "; added: ", ov[comparison == "v2.1 primary set", added]) else "identical", ") and ",
  n_(ov[comparison == "CRITIC-weighted selection", n_common]), " and ", n_(ov[comparison == "equal-weight selection", n_common]), " models with the selections under CRITIC and equal criterion weights.")
P("Unit and measurement-height checks of the inputs found no conversion error: all winds are ", lit("10", "wind measurement height (m)"), " m speeds in m s⁻¹ and are converted to ", lit("2", "FAO-56 reference height (m)"),
  " m with FAO-56 Eq. 47 inside the ET0 routine. The raw NEX-GDDP ", lit("10", "wind measurement height (m)"), " m wind was ", compare_word(aw$median_ratio_NEX_station, 1), " the station wind (median ratio ",
  f(aw$median_ratio_NEX_station, 1), ", ", n_(aw$n_stations), " stations) and ", compare_word(aw$median_ratio_NEX_ERA5L, 1), " ERA5-Land (", f(aw$median_ratio_NEX_ERA5L, 1),
  "); NEX-GDDP shortwave radiation was ", compare_word(aw$median_rs_ratio_NEX_ERA5L, 1), " ERA5-Land (ratio ", f(aw$median_rs_ratio_NEX_ERA5L, 2), ").")
qv <- as.data.table(K$qdm_validation_v2); v <- function(g, var, stg, col) qv[scheme_group == g & variable == var & stage == stg][[col]]
bw <- function(g, var, col = "q50_abs") describe_bias(v(g, var, "raw", col), v(g, var, "QDM", col), if (var %in% c("pr", "rsds", "sfcWind")) "relative" else if (var == "hurs") "pp" else "degC")
bsent <- function(g, var, col, unit, d) paste0(verb(bw(g, var, col)), " from ", f(v(g, var, "raw", col), d), unit, " to ", f(v(g, var, "QDM", col), d), unit)
ac <- as.data.table(K$qdm_acceptance)[binding == TRUE]; a_ <- function(st, var, col) ac[stage == st & variable == var][[col]]
ukind <- function(var) if (var %in% c("pr", "rsds", "sfcWind")) "relative" else if (var == "hurs") "pp" else "degC"
uunit <- function(var) if (var %in% c("pr", "rsds", "sfcWind")) "%" else if (var == "hurs") " %-points" else " °C"
vname <- c(pr = "precipitation", tasmax = "Tmax", tasmin = "Tmin", hurs = "humidity", rsds = "radiation", sfcWind = "wind")
asent <- function(var, d = 1) paste0(verb(describe_bias(a_("raw", var, "A_mean_abs"), a_("primary", var, "A_mean_abs"), ukind(var))), " from ", f(a_("raw", var, "A_mean_abs"), d), uunit(var), " to ",
                                      f(a_("primary", var, "A_mean_abs"), d), uunit(var), " for ", vname[[var]])
failA <- ac[stage == "primary" & pass_A == FALSE, variable]; oc <- as.data.table(K$qdm_october)[cal == "1985–1999" & variable == "pr"]
P("The pre-registered acceptance test of the primary QDM (per calendar month) used a plain split sample: calibration 1985–1999, validation 2000–2014, ", n_(a_("raw", "pr", "n_models")), " GCMs, regional series formed after cell-level correction (Table S1b). ",
  "The mean over months of the GCM-mean absolute median monthly bias ", paste(sapply(c("pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"), asent), collapse = ", "), ". ",
  "Criterion A (lower than raw for every variable) was ", if (length(failA)) paste0("not met for ", paste(vname[failA], collapse = ", ")) else "met", ". ",
  "The largest monthly precipitation bias after correction was ", f(a_("primary", "pr", "max_month"), 1), "% (", a_("primary", "pr", "max_month_name"), "), so criterion B (no month above ", lit("25", "pre-registered pr monthly bias limit (%)"), "%) was ",
  if (isTRUE(a_("primary", "pr", "pass_B"))) "met" else "not met", ". In October the precipitation bias was ", f(oc[stage == "raw", mean_abs], 1), "% raw and ", f(oc[stage == "primary", mean_abs], 1), "% after the primary QDM (",
  f(oc[stage == "S1", mean_abs], 1), "% and ", f(oc[stage == "S2", mean_abs], 1), "% with the standardised and unstandardised pooled windows, which are sensitivities only).",
  if (length(failA) || !isTRUE(a_("primary", "pr", "pass_B"))) " As pre-registered, the primary method was kept despite the failed criterion; the failure is discussed in Section V." else "")
P("QDM was validated with three schemes (Fig. 5, Table S1); in the detrended split sample the trend and climatology were fitted on the calibration half only. ",
  "In this test the mean absolute median bias ", bsent("detrended split", "sfcWind", "q50_abs", "%", 1), " for wind, ", bsent("detrended split", "rsds", "q50_abs", "%", 1), " for radiation, ",
  bsent("detrended split", "hurs", "q50_abs", " %-points", 1), " for humidity, ", bsent("detrended split", "tasmax", "q50_abs", " °C", 2), " for Tmax and ",
  bsent("detrended split", "tasmin", "q50_abs", " °C", 2), " for Tmin. For precipitation, the 90th-percentile bias ", bsent("detrended split", "pr", "q90_abs", "%", 0),
  ", the median bias ", bsent("detrended split", "pr", "q50_abs", "%", 1), " and the drought-frequency bias ", verb(describe_bias(v("detrended split", "pr", "raw", "drought_bias"), v("detrended split", "pr", "QDM", "drought_bias"), "pp")),
  " in magnitude from ", sg(v("detrended split", "pr", "raw", "drought_bias")), " to ", sg(v("detrended split", "pr", "QDM", "drought_bias")), " %-points.")
if (!is.null(K$qdm_precip_diag)) { dg <- as.data.table(K$qdm_precip_diag$decomposition); mon1 <- dg[cal == "1985–1999" & grepl("monsoon", season)]
  P("Between the two halves, the observed monsoon median precipitation changed by ", sg(mon1$obs_shift, 0), "% (calibration 1985–1999 → validation 2000–2014) and that of the raw models by ",
    sg(mon1$mod_shift, 0), "%; after QDM the signed monsoon median bias was ", sg(mon1$signed_qdm, 0), "% against ", sg(mon1$signed_raw, 0), "% for the raw models. In odd/even-year cross-validation, the precipitation median bias ",
    bsent("odd/even", "pr", "q50_abs", "%", 1), ", the 90th-percentile bias ", bsent("odd/even", "pr", "q90_abs", "%", 0), " and the drought-frequency bias ",
    verb(describe_bias(v("odd/even", "pr", "raw", "drought_bias"), v("odd/even", "pr", "QDM", "drought_bias"), "pp")), " in magnitude from ", sg(v("odd/even", "pr", "raw", "drought_bias")), " to ",
    sg(v("odd/even", "pr", "QDM", "drought_bias")), " %-points. In the pseudo-reality test, the precipitation median bias of the future period ", bsent("pseudo-reality", "pr", "q50_abs", "%", 0),
    ". Every index was recalibrated on each model's own 1985–2014 baseline, which removes a constant bias in drought frequency but not a bias that changes between the baseline and the future period.") }
pe <- as.data.table(K$qdm_pooling_effect); s7 <- as.data.table(K$sensitivity)[grepl("No QDM", Test, fixed = TRUE)]
rq <- as.data.table(K$raw_vs_qdm)
P("The far-future precipitation change was ", sg(pe[scenario == "ssp245", dP_raw]), "% and ", sg(pe[scenario == "ssp585", dP_raw]), "% (SSP2-4.5, SSP5-8.5) in the published NEX-GDDP, ",
  sg(pe[scenario == "ssp245", dP_primary]), "% and ", sg(pe[scenario == "ssp585", dP_primary]), "% after the primary QDM, ",
  sg(pe[scenario == "ssp245", dP_pooled_std]), "% and ", sg(pe[scenario == "ssp585", dP_pooled_std]), "% after QDM with standardised pooled windows and ",
  sg(pe[scenario == "ssp245", dP_pooled]), "% and ", sg(pe[scenario == "ssp585", dP_pooled]), "% after QDM with unstandardised pooled windows. Without QDM the far-future drought-frequency change was ",
  sg(s7[Scenario == "SSP2-4.5"]$`Δ freq far (%-pt)`), " and ", sg(s7[Scenario == "SSP5-8.5"]$`Δ freq far (%-pt)`), " %-points (Table VII); model by model, the change was ",
  sg(rq[scenario == "ssp245", dfreq_raw]), " and ", sg(rq[scenario == "ssp585", dfreq_raw]), " %-points from the published series and ", sg(rq[scenario == "ssp245", dfreq_qdm]), " and ",
  sg(rq[scenario == "ssp585", dfreq_qdm]), " %-points after QDM",
  if (all(rq$dfreq_qdm < rq$dfreq_raw)) "; the wetter QDM precipitation therefore reduced the projected increase in drought frequency, and the primary result is the more conservative of the two."
  else if (all(rq$dfreq_qdm > rq$dfreq_raw)) "; part of the projected increase in drought frequency therefore comes from the bias correction." else "; the effect of QDM on the drought signal differed between the scenarios.")

# ---------------- D. Projections ----------------
E <- as.data.table(K$ens_changes); g <- function(s, p, m) E[scenario == s & period == p & metric == m]
gword <- function(s, p, m, kind = "pp") { x <- g(s, p, m); describe_delta(x$wmean, kind, p = x$wilcox_p, agree = x$agree, base = 1) }   # d is already a % change: base cancels
SE <- as.data.table(K$seasonal_changes); s_ <- function(s, p, x) SE[scenario == s & period == p & season == x]
G <- as.data.table(K$ens_gwl); gw <- function(l, m) G[gwl == l & metric == m]; rc <- as.data.table(K$robust_cells_pct); mb <- K$model_baseline_char
H2("D. Projected Changes in Drought Characteristics")
P("Relative to the model baseline (", f(mb$freq), "% of months in drought, D = ", f(mb$D, 2), " months, S = ", f(mb$S, 2), "), the ", SEL, " drought frequency in 2025–2050 ",
  verb(gword("ssp245", "near", "d_freq")), " under SSP2-4.5 (", sg(g("ssp245", "near", "d_freq")$wmean), " percentage points) and ", verb(gword("ssp585", "near", "d_freq")), " under SSP5-8.5 (",
  sg(g("ssp585", "near", "d_freq")$wmean), "). By 2076–2100 it ", verb(gword("ssp245", "far", "d_freq")), " by ", sg(g("ssp245", "far", "d_freq")$wmean), " percentage points under SSP2-4.5 (10th–90th model range ",
  f(g("ssp245", "far", "d_freq")$p10), " to ", f(g("ssp245", "far", "d_freq")$p90), "; ", robust_word(g("ssp245", "far", "d_freq")$robust), ") and ", verb(gword("ssp585", "far", "d_freq")), " by ",
  sg(g("ssp585", "far", "d_freq")$wmean), " under SSP5-8.5 (", f(g("ssp585", "far", "d_freq")$p10), " to ", f(g("ssp585", "far", "d_freq")$p90), "; ", robust_word(g("ssp585", "far", "d_freq")$robust),
  "; Table IV). Mean severity changed by ", sg(g("ssp245", "far", "d_S")$wmean, 2), " and ", sg(g("ssp585", "far", "d_S")$wmean, 2), ". The change was ", robust_word(TRUE), " after Benjamini–Hochberg control in ",
  f(rc[scenario == "ssp245" & period == "far", pct_robust], 0), "% (SSP2-4.5) and ", f(rc[scenario == "ssp585" & period == "far", pct_robust], 0), "% (SSP5-8.5) of the 0.25° cells (Fig. 6; ",
  f(rc[scenario == "ssp245" & period == "far", pct_robust_noFDR], 0), "% and ", f(rc[scenario == "ssp585" & period == "far", pct_robust_noFDR], 0), "% without FDR control).")
sw <- function(x) verb(describe_delta(s_("ssp585", "far", x)$d_freq, "pp", agree = s_("ssp585", "far", x)$agree, p = s_("ssp585", "far", x)$wilcox_p))
P("Annual precipitation ", verb(gword("ssp245", "far", "d_P", "relative")), " by ", sg(g("ssp245", "far", "d_P")$wmean), "% and ", sg(g("ssp585", "far", "d_P")$wmean), "% and ET0 by ",
  sg(g("ssp245", "far", "d_ET0")$wmean), "% and ", sg(g("ssp585", "far", "d_ET0")$wmean), "% (SSP2-4.5, SSP5-8.5). Under SSP5-8.5, JJA precipitation changed by ", sg(s_("ssp585", "far", "JJA")$d_P),
  "% and DJF precipitation by ", sg(s_("ssp585", "far", "DJF")$d_P), "%, with DJF ET0 ", sg(s_("ssp585", "far", "DJF")$d_ET0), "%. Drought frequency ", sw("DJF"), " in DJF (",
  sg(s_("ssp585", "far", "DJF")$d_freq), " %-points), ", sw("MAM"), " in MAM (", sg(s_("ssp585", "far", "MAM")$d_freq), "), ", sw("JJA"), " in JJA (", sg(s_("ssp585", "far", "JJA")$d_freq), "), ",
  sw("SON"), " in SON (", sg(s_("ssp585", "far", "SON")$d_freq), ") and ", sw("Dec (sowing)"), " for December ", SEL, " (", sg(s_("ssp585", "far", "Dec (sowing)")$d_freq),
  "). At ", lit("+1.5", "GWL"), ", ", lit("+2", "GWL"), " and ", lit("+3", "GWL"), " °C global warming the drought-frequency change was ", sg(gw(1.5, "d_freq")$wmean), " (",
  robust_word(gw(1.5, "d_freq")$robust), "), ", sg(gw(2, "d_freq")$wmean), " (", robust_word(gw(2, "d_freq")$robust), ") and ", sg(gw(3, "d_freq")$wmean), " %-points (",
  robust_word(gw(3, "d_freq")$robust), "), and ET0 changed by ", sg(gw(1.5, "d_ET0")$wmean), "%, ", sg(gw(2, "d_ET0")$wmean), "% and ", sg(gw(3, "d_ET0")$wmean), "% (Fig. 7).")

# ---------------- E. Return periods ----------------
cg <- K$copula_gof; CT <- as.data.table(K$copula_T); ref <- as.data.table(K$ref_events)
t_ <- function(st, e, col = "T_and") { x <- CT[set == st & T_ref == 25 & estimator == e]
  if (isTRUE(x$extrapolated) && col == "T_and") return("not reported (> 2L)")
  if (col %in% c("lo", "hi") && (!is.finite(x[[col]]) || x[[col]] > 2 * x$model_years)) return("> 2L")   # v3.1: same rule as Table V
  f(x[[col]]) }
tw <- function(st, e) { a <- CT[set == "Baseline (1985–2014)" & T_ref == 25 & estimator == e, T_and]; b <- CT[set == st & T_ref == 25 & estimator == e, T_and]; describe_change(a, b, "years") }
H2("E. Joint Duration–Severity Return Periods")
NKEEP_TXT <- nrow(as.data.table(K$gcm_rank)[weight > 0])
PF <- as.data.table(cg$pooled); pb0 <- PF[set == "Baseline (1985–2014)"]; pmod <- PF[set != "Observed (1981–2024)"]
P("Drought events (run theory, threshold ", lit("−1", "run threshold"), ", runs separated by a single non-drought month merged) of the ", n_(NKEEP_TXT), " retained GCMs were pooled for each period and warming level, ",
  "giving ", n_(min(pmod$n)), "–", n_(max(pmod$n)), " events per set (baseline: ", n_(pb0$n), " events from ", n_(pb0$model_years), " model-years). ",
  "The parametric-bootstrap tests gave p < ", lit("0.05", "alpha"), " for the duration marginal (Anderson–Darling) in ", n_(sum(pmod$D_AD_p < 0.05)), ", for the severity marginal in ", n_(sum(pmod$S_AD_p < 0.05)),
  " and for the copula (Cramér–von Mises) in ", n_(sum(pmod$cvm_p < 0.05)), " of the ", n_(nrow(pmod)), " sets. ",
  if (cg$primary == "bernstein") "Under the pre-specified rule the empirical Bernstein (beta) copula was the primary estimator. " else "Under the pre-specified rule the parametric copula was the primary estimator. ",
  "The reference event was exceeded by ", n_(min(pmod$n_exceed_25yr)), "–", n_(max(pmod$n_exceed_25yr)), " pooled events per set; durations were compared in whole months by one rule for all three estimators. ",
  "Return periods longer than twice the pooled record length L were not reported (", n_(sum(CT$extrapolated & CT$set != "Observed (1981–2024)")), " of ", n_(nrow(CT[set != "Observed (1981–2024)"])), " estimates).")
P("The baseline ", n_(ref$T[2]), "-year event (D ≥ ", n_(ref$k[2]), " months and S ≥ ", f(ref$s[2]), ") had a pooled-ensemble T_AND of ", t_("Baseline (1985–2014)", "bernstein"), " years (Bernstein; ", lit("95", "confidence level (%)"), "% CI ",
  t_("Baseline (1985–2014)", "bernstein", "lo"), "–", t_("Baseline (1985–2014)", "bernstein", "hi"), "), ", t_("Baseline (1985–2014)", "parametric"), " (parametric) and ", t_("Baseline (1985–2014)", "count"),
  " (counting). By 2076–2100 it ", verb(tw("SSP2-4.5 far", "bernstein"), up = "lengthened", down = "shortened"), " to ", t_("SSP2-4.5 far", "bernstein"), " (", t_("SSP2-4.5 far", "bernstein", "lo"), "–",
  t_("SSP2-4.5 far", "bernstein", "hi"), ") years under SSP2-4.5 and ", verb(tw("SSP5-8.5 far", "bernstein"), up = "lengthened", down = "shortened"), " to ", t_("SSP5-8.5 far", "bernstein"), " (",
  t_("SSP5-8.5 far", "bernstein", "lo"), "–", t_("SSP5-8.5 far", "bernstein", "hi"), ") years under SSP5-8.5; the parametric estimates were ", t_("SSP2-4.5 far", "parametric"), " and ",
  t_("SSP5-8.5 far", "parametric"), " years and the counting estimates ", t_("SSP2-4.5 far", "count"), " and ", t_("SSP5-8.5 far", "count"), " years (Table V, Fig. 8). At ", lit("+1.5", "GWL"), ", ",
  lit("+2", "GWL"), " and ", lit("+3", "GWL"), " °C the Bernstein estimates were ", t_("+1.5 °C", "bernstein"), ", ", t_("+2 °C", "bernstein"), " and ", t_("+3 °C", "bernstein"),
  " years, and in 2025–2050 ", t_("SSP2-4.5 near", "bernstein"), " (SSP2-4.5) and ", t_("SSP5-8.5 near", "bernstein"), " (SSP5-8.5) years.")

# ---------------- F. Exposure ----------------
X <- as.data.table(K$exposure); xf <- X[period == "far", .(w = sum(wheat_exp), wt = sum(wheat_total)), by = scenario]
H2("F. Exposure of Rainfed Crops")
EG <- as.data.table(K$exposure_graded); eg <- function(s, d = "Potohar (all units)", p = "far") EG[scenario == s & period == p & district == d]
egd <- EG[period == "far" & district != "Potohar (all units)"]; e5 <- egd[scenario == "ssp585"]
ew <- function(s) describe_change(eg(s)$E0_wheat, eg(s)$E1_wheat, "relative")
P("Exposure was graded by weighting the rainfed area with the drought frequency of its 0.25° cell. In the baseline, ", f(eg("ssp245")$E0_wheat / 1e3, 0), " × 10³ ha of the ",
  f(eg("ssp245")$wheat_total / 1e3, 0), " × 10³ ha of rainfed wheat were in ", SEL, " drought in an average month. By 2076–2100 this frequency-weighted exposure ", verb(ew("ssp245")), " by ",
  sg(eg("ssp245")$dE_wheat_pct, 0), "% under SSP2-4.5 and ", verb(ew("ssp585")), " by ", sg(eg("ssp585")$dE_wheat_pct, 0), "% under SSP5-8.5 (groundnut ", sg(eg("ssp245")$dE_gnut_pct, 0), "% and ",
  sg(eg("ssp585")$dE_gnut_pct, 0), "%; Table VI, Fig. 9). Under SSP5-8.5 the change was largest in ", e5[which.max(dE_wheat_pct)]$district, " (", sg(max(e5$dE_wheat_pct), 0), "%) and smallest in ",
  e5[which.min(dE_wheat_pct)]$district, " (", sg(min(e5$dE_wheat_pct), 0), "%). Drought frequency reached at least ", lit("1.5", "exposure class break (x baseline)"), " times its baseline value on ",
  f(eg("ssp245")$share_wheat_ge15, 0), "% (SSP2-4.5) and ", f(eg("ssp585")$share_wheat_ge15, 0), "% (SSP5-8.5) of the wheat area and at least twice its baseline value on ",
  f(eg("ssp245")$share_wheat_ge2, 1), "% and ", f(eg("ssp585")$share_wheat_ge2, 1), "%.")
eu <- as.data.table(K$exposure_uncertainty)[district == "Potohar (all units)" & period == "far"]; eu_ <- function(s) eu[scenario == s]
P("Computed model by model, the far-future change in frequency-weighted wheat exposure had a skill-weighted mean of ", sg(eu_("ssp245")$dE_wmean, 0), "% (model range ", sg(eu_("ssp245")$p10, 0), " to ",
  sg(eu_("ssp245")$p90, 0), "%, bootstrap ", lit("95", "confidence level (%)"), "% CI ", sg(eu_("ssp245")$ci_lo, 0), " to ", sg(eu_("ssp245")$ci_hi, 0), "%) under SSP2-4.5 and ", sg(eu_("ssp585")$dE_wmean, 0), "% (", sg(eu_("ssp585")$p10, 0), " to ",
  sg(eu_("ssp585")$p90, 0), "%; CI ", sg(eu_("ssp585")$ci_lo, 0), " to ", sg(eu_("ssp585")$ci_hi, 0), "%) under SSP5-8.5; ", pc(eu_("ssp245")$agree_increase), " and ", pc(eu_("ssp585")$agree_increase),
  " of the model weight projected an increase (Table S8).")
P("By the binary measure (Table S3), cells with a robust increase after FDR control covered ", f(xf[scenario == "ssp245", w] / 1e3, 0), " × 10³ ha (", f(100 * xf[scenario == "ssp245", w] / xf[scenario == "ssp245", wt], 0),
  "%) of the rainfed wheat area under SSP2-4.5 and ", f(xf[scenario == "ssp585", w] / 1e3, 0), " × 10³ ha (", f(100 * xf[scenario == "ssp585", w] / xf[scenario == "ssp585", wt], 0), "%) under SSP5-8.5 by 2076–2100.")
rcw <- K$rainfed_check; rsh <- as.data.table(K$rainfed_share_by_district)
P("Crop areas were taken from the Crop Reporting Service un-irrigated (barani) statistics and allocated within each district with SPAM2010. ",
  "The SPAM2010 rainfed share of wheat (", f(100 * rcw$wheat_share_spam, 0), "%) was ", compare_word(rcw$wheat_share_spam, rcw$wheat_share_crs_2016_24), " the reported share (", f(100 * rcw$wheat_share_crs_2016_24, 0),
  "%, 2016–2024), but its rainfed wheat area for the five units was ", f(rcw$wheat_rf_kha_spam / rcw$wheat_rf_kha_crs_2011_13, 1), " times the reported area (", f(rcw$wheat_rf_kha_spam, 0), " vs ",
  f(rcw$wheat_rf_kha_crs_2011_13, 0), " × 10³ ha in 2011–2013), and its groundnut area was ", f(rcw$gnut_rf_kha_spam, 0), " vs ", f(rcw$gnut_rf_kha_crs, 0), " × 10³ ha (Table S2). ",
  rsh[which.min(wheat_share)]$district, " had the largest irrigated share of wheat (", f(100 * (1 - min(rsh$wheat_share)), 0), "%); the rainfed share of groundnut was ", f(100 * rcw$gnut_share_crs, 1), "%.")

# ---------------- G. Uncertainty and sensitivity ----------------
hs <- as.data.table(K$hs_fractions); hf <- function(w, y, s) hs[grepl(w, what) & year == y & source == s, frac]
T7 <- as.data.table(K$sensitivity); t7 <- function(p) T7[grepl(p, Test, fixed = TRUE)]$`Δ freq far (%-pt)`
H2("G. Uncertainty and Sensitivity")
src <- c("internal", "model", "scenario"); big <- function(y) src[which.max(sapply(src, function(s) hf("Drought", y, s)))]
P("The largest source of uncertainty in the decadal drought frequency was ", big(2050), " uncertainty in 2050 (", f(hf("Drought", 2050, big(2050)), 0), "%) and ", big(2095), " uncertainty in 2095 (",
  f(hf("Drought", 2095, big(2095)), 0), "%); internal variability ", verb(describe_change(hf("Drought", 2030, "internal"), hf("Drought", 2095, "internal"), "pp")), " from ", f(hf("Drought", 2030, "internal"), 0),
  "% in 2030 to ", f(hf("Drought", 2095, "internal"), 0), "% in 2095 and scenario uncertainty was ", f(hf("Drought", 2095, "scenario"), 0), "% in 2095 (Fig. 10). ",
  "The far-future change in drought frequency was ", f(t7("Reference")[1]), " and ", f(t7("Reference")[2]), " %-points in the reference configuration, ", f(t7("Hargreaves")[1]), " and ", f(t7("Hargreaves")[2]),
  " with Hargreaves ET0, ", f(t7("Threshold")[1]), " and ", f(t7("Threshold")[2]), " with threshold ", lit("−1.5", "sensitivity threshold"), ", ", f(t7("Alternative baseline")[1]), " and ", f(t7("Alternative baseline")[2]),
  " with the 1981–2010 baseline and ", f(t7("No QDM")[1]), " and ", f(t7("No QDM")[2]), " without QDM (Table VII); ", n_(sum(T7$`Δ freq far (%-pt)` > 0, na.rm = TRUE)), " of ", n_(sum(!is.na(T7$`Δ freq far (%-pt)`))),
  " sensitivity estimates were positive. The ISIMIP3b chain gave ", f(mean(K$isimip_chain$isimip_dfreq)), " %-points for its five GCMs under SSP5-8.5, against ", f(mean(K$isimip_chain$nex_dfreq)),
  " from NEX-GDDP with QDM for the same GCMs.")
MS <- as.data.table(K$model_set_sensitivity); ms <- function(st, sc, col) MS[grepl(st, set, fixed = TRUE) & scenario == sc][[col]]
DR <- as.data.table(K$district_robustness)[period == "far"]; dsc <- K$discontinuity_fix
P("Across the model sets of Table S6, the far-future change in drought frequency ranged from ", f(min(MS[scenario == "SSP2-4.5", d_freq])), " to ", f(max(MS[scenario == "SSP2-4.5", d_freq])),
  " %-points under SSP2-4.5 and from ", f(min(MS[scenario == "SSP5-8.5", d_freq])), " to ", f(max(MS[scenario == "SSP5-8.5", d_freq])), " under SSP5-8.5, and it was ", robust_word(TRUE), " in ",
  n_(sum(MS$robust)), " of the ", n_(nrow(MS)), " set × scenario cases. ",
  if (!is.null(dsc) && NROW(dsc)) paste0("In the NASA files, the ", lit("10", "wind measurement height (m)"), " m wind of ", paste(unique(as.data.table(dsc)$model), collapse = ", "), " changed by ",
    sg(min(as.data.table(dsc)$change), 0), " to ", sg(max(as.data.table(dsc)$change), 0), "% between 2005–2014 and 2015–2024, a discontinuity flagged by the outlier rule; the scenario wind of these models was rescaled to remove the step (Table S6 also gives the primary set without them). ") else "",
  "At district level the far-future change was ", robust_word(TRUE), " after Benjamini–Hochberg control in ", n_(sum(DR[scenario == "ssp245"]$robust)), " of ", lit("5", "number of units"), " units under SSP2-4.5 and ",
  n_(sum(DR[scenario == "ssp585"]$robust)), " of ", lit("5", "number of units"), " under SSP5-8.5 (Table S4).")

# ---------------- H. Comparison with previous studies ----------------
H2("H. Comparison with Previous Studies")
top_exp <- egd[scenario == "ssp585"][order(-dE_wheat_pct)]$district[1:2]
rabi_up <- all(sapply(c("DJF", "MAM"), function(x) s_("ssp585", "far", x)$d_freq > s_("ssp585", "far", "JJA")$d_freq))
P("The evaluation-to-projection chain followed [1], with multi-model CMIP6 evaluation and Penman–Monteith-based SPEI. Ain et al. [2] analysed Kharif and Rabi droughts of the Potwar Plateau with two CORDEX models under RCP scenarios; in the present CMIP6 ensemble the far-future change in drought frequency under SSP5-8.5 was ",
  if (rabi_up) "larger in DJF and MAM than in JJA. " else "not larger in DJF and MAM than in JJA. ",
  "The CHIRPS- and MODIS-based risk mapping of Goheer et al. [3] is extended here by the VHI–SPEI-3 link, official district yields and graded future exposure, with the largest exposure change under SSP5-8.5 in ",
  paste(top_exp, collapse = " and "), ". For the Soan basin, Abbas et al. [4] and Sarwar et al. [5] characterised meteorological and hydrological droughts and their propagation from gauge data; here the propagation was likewise estimated from WAPDA gauge records (", pr$period, "), and GloFAS-ERA5 extended the hydrological drought record to 2024.")

# ---------------- I. Limitations (unresolved only) ----------------
H2("I. Limitations")
pw <- describe_bias(v("detrended split", "pr", "raw", "q50_abs"), v("detrended split", "pr", "QDM", "q50_abs"))
P("Several limitations remain. PMD daily records were available for only ", lit("2", "number of PMD stations"), " stations (Islamabad and Murree, to 2010) and contain no humidity, wind or sunshine, so their dew point and wind came from GSOD (Murree, completed by quantile-mapped ERA5-Land) and from Chaklala (Islamabad); ",
  n_(length(st$accepted_P_ET0)), " stations met the completeness rule in total, and station solar radiation had to be estimated from the temperature range. ",
  "The WAPDA gauge records end in 2003, so gauge SRI and SDI were calibrated on ", paste(wp$ref, collapse = "–"), " rather than the full 1985–2014 baseline, and hydrological drought after 2003 relies on GloFAS-ERA5 (monthly KGE ",
  f(min(gv$KGE), 2), "–", f(max(gv$KGE), 2), " against the gauges); the coordinates of the Sil gauge near Chahan were not available, so it is neither mapped nor used for propagation. ",
  "District groundnut statistics were available only from 2017-18, so groundnut served as a check rather than for index selection, and the within-district crop allocation relies on SPAM2010. ",
  "The NDMC monthly bulletins could only be recovered for ", if (!is.null(pb$period)) pb$period else "a few months", " and the quarterly bulletins for ", if (!is.null(pq)) pq$period else "a few years", ". ",
  "In the leak-free detrended split, QDM ", verb(pw), " the out-of-sample precipitation median bias. In the pooled ensemble, the parametric copula test gave p < ", lit("0.05", "alpha"), " in ",
  n_(sum(pmod$cvm_p < 0.05)), " of ", n_(nrow(pmod)), " sets, and the return periods rest on the empirical Bernstein copula with the counting estimate as a check. ",
  n_(NROW(K$discontinuity_fix)), " GCMs required a correction of a wind discontinuity in the source data, and the direction of the observed precipitation trend differed among rainfall products.")
# v3.1: limitations that come from the data rather than the code (station validation, post-2003 discharge, post-hoc re-freeze)
noev <- K$station_vars_without_eligible_station; vlab <- c(pr = "precipitation", tasmax = "Tmax", tasmin = "Tmin", ET0 = "ET0")
st_list <- function(col) { s <- EL[get(col) == TRUE, station]; if (length(s)) paste(s, collapse = " and ") else "no station" }
ms <- K$model_sets; ov_v3 <- length(intersect(K$top_models, ms[["v3 primary (before the v3.1 code fixes)"]])); ov_v22 <- length(intersect(K$top_models, ms[["v2.2 primary (open-data stations only)"]]))
MSd <- as.data.table(K$model_set_sensitivity)
P("Some limitations come from the data rather than the analysis. Station validation is thin: after the representativeness and homogeneity screening, only ", st_list("eval_P"),
  " could be used for precipitation and only ", st_list("eval_ET0"), " for ET0",
  if (length(noev)) paste0(", and ", paste(vlab[noev], collapse = " and "), " was flagged as inhomogeneous against both references at every evaluated station, so the station ",
                           paste(vlab[noev], collapse = " and "), " criterion was dropped from the GCM ranking") else "",
  ". Hydrological drought after ", substr(wp$records[gauge == "Dhok Pathan"]$last, 1, 4), " relies on GloFAS-ERA5, which matched the gauges only moderately at Dhok Pathan (KGE ",
  f(g_("Dhok Pathan", "KGE"), 2), ") and poorly at Chirah (KGE ", f(g_("Chirah", "KGE"), 2), ", mean bias ", sg(g_("Chirah", "bias_pct"), 0),
  "%), so the post-", substr(wp$records[gauge == "Dhok Pathan"]$last, 1, 4), " hydrological results, especially for Chirah, are less certain than the gauge-based ones. ",
  "Finally, the GCM selection was frozen again after the v3 projections had been computed, because the station inputs of the ranking were corrected (PREREGISTRATION post-hoc entry ", lit("8", "post-hoc entry number"), "); this re-freeze was therefore not results-blind. ",
  "The selection shares ", n_(ov_v3), " of ", lit("10", "selection size"), " models with the v3 selection and ", n_(ov_v22), " with the v2.2 selection, and across all model sets of Table S6 the far-future change in drought frequency ranged from ",
  f(min(MSd[scenario == "SSP5-8.5", d_freq])), " to ", f(max(MSd[scenario == "SSP5-8.5", d_freq])), " %-points under SSP5-8.5, so the main conclusion does not depend on the selection.")
doc <- body_add_fpar(doc, fpar(ftext("Traceability: every number is logged with its source expression in results_text/Number_Trace.csv (key_numbers.rds from Potohar_Drought_Analysis.Rmd).",
                                     fp_text(font.family = "Times New Roman", font.size = 8, italic = TRUE))))
print(doc, target = file.path(ROOT, "results_text", "Results_Discussion.docx"))
fwrite(rbindlist(TRACE), file.path(ROOT, "results_text", "Number_Trace.csv"))
cat("Results_Discussion.docx written;", length(TRACE), "numbers logged\n")
