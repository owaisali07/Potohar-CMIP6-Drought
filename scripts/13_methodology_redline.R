# Methodology_v2_redline.docx: every methodology sentence that must change to match what was actually done (v2).
# Original sentences are quoted verbatim from Paper6_Methodology_IEEE.docx (struck through, red); replacements are
# underlined (blue). Values that depend on the analysis are read from results_text/key_numbers.rds.
suppressMessages({ library(officer); library(data.table) })
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))   # run from analysis/ (or set P6_CONFIG)
ROOT <- cfg$paths$root
K <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))
meth <- officer::docx_summary(read_docx(cfg$paths$methodology_docx))$text
meth <- paste(meth[!is.na(meth)], collapse = " ")
st <- K$stations_v2; stations <- paste(st$accepted_P_ET0, collapse = ", ")
cop <- K$copula_gof; prim <- if (identical(cop$primary, "bernstein")) "the empirical Bernstein (beta) copula" else "the AIC-selected parametric copula"
gl <- K$glofas
CH <- list(
  list("II-B Datasets", "PMD stations in and around the plateau (e.g., Islamabad, Rawalpindi, Murree and Jhelum; the final list depends on record availability) provide daily precipitation, temperature, humidity, wind and sunshine.",
       paste0("PMD daily precipitation, maximum and minimum temperature for Islamabad and Murree (1961–2010) were merged with the NOAA GSOD/ISD and GHCN-Daily [14] records of all stations within 100 km of the plateau (", st$n_candidates,
              " stations), which also provide dew point and wind; stations with at least 70% complete months in 1985–2014 were retained (", stations, ").")),
  list("II-B Datasets", "CHIRPS [6] and ERA5-Land [7] provide spatial coverage and Penman–Monteith inputs, with CRU TS4 [8] as an independent check.",
       "CHIRPS [6] provides precipitation and ERA5-Land [7] the Penman–Monteith inputs (Tmax, Tmin, dew point, solar radiation and the monthly mean of hourly 10 m wind speed, aggregated in Google Earth Engine); TerraClimate [18] provides an independent Penman–Monteith estimate used as a sensitivity run, and CRU TS4 [8] an independent check."),
  list("II-B Datasets", "WAPDA streamflow at Chirah and Dhok Pathan supports hydrological drought analysis,",
       paste0("WAPDA (SWHP) daily discharge at Chirah, Dhok Pathan and on the Sil River near Chahan (", paste(range(substr(K$wapda$records$first, 1, 4)), collapse = "/"), "–", max(substr(K$wapda$records$last, 1, 4)),
              ") supports hydrological drought analysis, with GloFAS-ERA5 [21] daily discharge (", gl$source, ") at the matching grid cells, validated against the gauges, extending it to 2024,")),
  list("II-B Datasets", "and district yields from the Crop Reporting Service, Punjab, support impact validation.",
       "and district wheat yields of the Crop Reporting Service, Punjab (published by the Pakistan Bureau of Statistics, the Bureau of Statistics Punjab and the Agriculture Department Punjab, 1985–2024), support impact validation, with GDHY [23] as a check; district groundnut yields (2017-18 onwards) provide a Kharif check, and the reported irrigated / un-irrigated areas set the rainfed crop areas."),
  list("Table I", "PMD station network | Precipitation, Tmax, Tmin, humidity, wind, sunshine | Daily; regional stations | 1981–2024 | Pakistan Meteorological Department",
       "PMD stations Islamabad and Murree (1961–2010) and GSOD/ISD and GHCN-Daily stations within 100 km | Precipitation, Tmax, Tmin (PMD); dew point, wind (GSOD) | Daily | 1981–2024 | Pakistan Meteorological Department; NOAA NCEI"),
  list("Table I", "Soan River streamflow | Discharge at Chirah and Dhok Pathan | Daily | 1983–2024 | WAPDA",
       paste0("Soan and Sil River streamflow | Discharge at Chirah, Dhok Pathan and Sil near Chahan | Daily | ", min(substr(K$wapda$records$first, 1, 4)), "–", max(substr(K$wapda$records$last, 1, 4)),
              " | WAPDA (SWHP); extended with GloFAS-ERA5 v4.0 (0.05°, ", gl$start, "–2024, Copernicus EMS)")),
  list("Table I", "Crop statistics | Wheat and groundnut yield and area | District; annual | 1981–2024 | Crop Reporting Service, Punjab",
       "Crop statistics | Wheat (1985–2024) and groundnut (2017–2024) area, production, irrigated / un-irrigated area | District; annual | 1985–2024 | Crop Reporting Service, Punjab (via PBS, BoS Punjab and Agriculture Dept. Punjab)"),
  list("III-F Return periods", "Drought hotspots are overlaid with the WorldCover cropland mask to estimate the area of rainfed wheat and groundnut exposed in each district.",
       "Drought hotspots are overlaid with the WorldCover cropland mask to estimate the area of rainfed wheat and groundnut exposed in each district; SPAM2010 [24] allocates each crop within a district, and district totals are set to the un-irrigated area reported by the Crop Reporting Service, Punjab (mean 2021-22 to 2023-24)."),
  list("III-B Preprocessing", "Station records are quality-controlled and tested for inhomogeneity with the SNHT [30] and the Pettitt test [31];",
       "Station records are quality-controlled and tested for inhomogeneity with the SNHT [30] and the Pettitt test [31], applied to station/reference ratios (precipitation, ET0) or differences (temperature) with CHIRPS and ERA5-Land at the station point and TerraClimate at the station cell as references; a series flagged by both tests against both references, a station whose elevation differs by more than 500 m from its 0.25° cell, and station ET0 without observed humidity and wind are not used for model or product evaluation;"),
  list("III-D Propagation", "The propagation lag from meteorological to hydrological drought is the lag of maximum cross-correlation between SPEI-k and SRI-1, as in [5],",
       "The propagation lag from meteorological to hydrological drought is the lag of maximum cross-correlation between the SPEI-k of each gauge's catchment and its SRI-1, as in [5],"),
  list("III-F Return periods", "Joint duration–severity return periods use copulas [42]:",
       "Joint duration–severity return periods use copulas [42], with discrete margins for the duration (a whole number of months) and semiparametric margins (empirical body with a generalized Pareto tail) for the severity minus its lower bound of 1, the copula being selected by the Akaike information criterion:"),
  list("III-B Preprocessing", "short gaps are filled from quantile-mapped CHIRPS and ERA5-Land values,",
       "gaps of up to 15 days are filled by month-wise empirical quantile mapping of co-located daily CHIRPS (precipitation) and ERA5-Land (temperature, dew point, wind) values,"),
  list("III-B Preprocessing", "where the symbols follow [33]; the Hargreaves method is used only as a sensitivity test.",
       "where the symbols follow [33]; station solar radiation, which is not observed, is estimated from the temperature range (FAO-56 Eq. 50), and the Hargreaves method is used only as a sensitivity test."),
  list("III-C Drought indices", "All indices are calibrated on a common 1985–2014 baseline for observed and simulated series.",
       paste0("All indices are calibrated on a common 1985–2014 baseline for observed and simulated series, except the VHI, whose extremes come from the MODIS record (2000–2024), and the gauge SRI and SDI, calibrated on ", paste(K$wapda$ref, collapse = "–"), " because the WAPDA records end in 2003.")),
  list("III-E GCM evaluation", "Models are ranked by compromise programming, the ten best are retained and weighted by skill,",
       "Models without skill (KGE < 0 for any variable) are ranked last; the others are ranked by compromise programming, and the ten best are retained and weighted by skill,"),
  list("III-E Bias correction", "residual biases are removed with quantile delta mapping (QDM) [41], which preserves the projected change in each quantile:",
       "residual biases relative to CHIRPS and ERA5-Land are removed with quantile delta mapping (QDM) [41], applied per grid cell and calendar month with quantile functions estimated from a pooled three-month window, which preserves the projected change in each quantile:"),
  list("III-E Bias correction", "The correction is validated on split periods (1985–1999 and 2000–2014).",
       "The correction is validated by a detrended split-sample test (1985–1999 and 2000–2014), odd/even-year cross-validation and a pseudo-reality experiment in which each GCM serves in turn as the truth."),
  list("III-F Projections", "and also at +1.5, +2 and +3 °C global warming levels.",
       "and also at +1.5, +2 and +3 °C global warming levels, using each model's published 20-year crossing windows (Hauser et al.)."),
  list("III-F Return periods", "where μ is the mean inter-arrival time and C the copula selected by the Akaike information criterion.",
       paste0("where μ is the mean inter-arrival time. Marginals and C are fitted separately for each GCM to declustered events; C is selected by the Akaike information criterion among eight families (Gaussian, t, Clayton, Gumbel, Frank, Joe, BB1, BB7) and tested with a parametric-bootstrap Cramér–von Mises test (N = 1000). Because ",
              round(cop$pass_pct), "% of the fits passed, ", prim, " is used as the primary estimator, with the parametric copula and the count-based return period as checks.")),
  list("IV Validation", "Observed indices are compared between stations, CHIRPS and ERA5-Land, and validated against detrended yields and PMD drought bulletins.",
       "Observed indices are compared between stations, CHIRPS and ERA5-Land, and validated against detrended district yields and the NDMC/PMD drought bulletins recovered from Internet Archive snapshots (hit rate and false-alarm ratio against SPEI-3 ≤ −1).")
)
red <- fp_text(color = "#C00000", strike = TRUE, font.family = "Times New Roman", font.size = 10)
blue <- fp_text(color = "#0033CC", underlined = TRUE, font.family = "Times New Roman", font.size = 10)
lab <- fp_text(bold = TRUE, font.family = "Times New Roman", font.size = 10)
norm <- fp_text(font.family = "Times New Roman", font.size = 10)
doc <- read_docx()
doc <- body_add_fpar(doc, fpar(ftext("Methodology v2 — redline of sentences that change to match the analysis", fp_text(bold = TRUE, font.size = 13, font.family = "Times New Roman"))))
doc <- body_add_fpar(doc, fpar(ftext("Red strikethrough = original text of Paper6_Methodology_IEEE.docx; blue underline = replacement. All other sentences are unchanged. Reasons for each change are in DEVIATIONS.md and CHANGES_v2.md.", norm)))
found <- logical(length(CH))
for (i in seq_along(CH)) { x <- CH[[i]]
  found[i] <- grepl(gsub(" \\| ", " ", substr(x[[2]], 1, 40)), gsub(" \\| ", " ", meth), fixed = TRUE)
  doc <- body_add_fpar(doc, fpar(ftext(paste0(i, ". ", x[[1]], if (!found[i]) " (table row)" else ""), lab)))
  doc <- body_add_fpar(doc, fpar(ftext(x[[2]], red), ftext("  ", norm), ftext(x[[3]], blue)))
}
print(doc, target = file.path(dirname(ROOT), "analysis", "Methodology_v2_redline.docx"))
cat("redline written:", length(CH), "changes; original text located for", sum(found), "of", length(CH), "\n")
