# Submission package (Word files) for the Potohar drought manuscript, built from manuscript/manuscript_source.txt,
# manuscript/references.txt, the figures and tables of the analysis and results_text/key_numbers.rds.
# Usage (from analysis/): Rscript scripts/23_build_submission.R <submission_dir>
# Word-only steps (line numbers, PDF export, TIFF conversion) follow in scripts/24_word_finish.ps1.
suppressMessages({ library(officer); library(flextable); library(data.table) })
args <- commandArgs(trailingOnly = TRUE); stopifnot(length(args) == 1)
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root
OUT <- args[1]; MS <- file.path(ROOT, "manuscript"); FIGD <- file.path(ROOT, "figures"); TABD <- file.path(ROOT, "tables")
K <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))
sub_dirs <- c("01_Manuscript", "02_Title_Page", "03_Figures", "04_Tables", "05_Supplementary", "06_Graphical_Abstract", "07_Cover_Letter",
              "08_Response_to_Reviewers", "09_Declarations", "10_Code_Data")
for (d in sub_dirs) dir.create(file.path(OUT, d), recursive = TRUE, showWarnings = FALSE)

# ---------------- typography ----------------
FONT <- "Times New Roman"
tx  <- function(size = 12, bold = FALSE, italic = FALSE, va = "baseline") fp_text(font.family = FONT, font.size = size, bold = bold, italic = italic, vertical.align = va)
pp  <- function(align = "justify", ls = 2, before = 0, after = 6) fp_par(text.align = align, line_spacing = ls, padding.top = before, padding.bottom = after)
new_doc <- function(landscape = FALSE) {
  d <- read_docx()
  ft <- block_list(fpar(run_word_field("PAGE", prop = tx(10)), fp_p = fp_par(text.align = "center")))
  ps <- page_size(width = 21 / 2.54, height = 29.7 / 2.54, orient = if (landscape) "landscape" else "portrait")
  body_set_default_section(d, prop_section(page_size = ps, page_margins = page_mar(top = 0.984, bottom = 0.984, left = 0.984, right = 0.984, header = 0.5, footer = 0.5, gutter = 0),
                                           footer_default = ft, type = "continuous"))
}
# text with subscripts written as X_sub (T_AND, F_D, F_S, F_o, F_h, F_p,t, x_p, X_t) -> list of ftext runs
SUBPAT <- "(SPEI|ET|T|F|G|x̂|x|X|y|σ̂|τ|R|u|e)_(AND|p,t|D|S|o|h|p|t|k|y|n|2|s|a|0|Γ)"
rich <- function(s, size = 12, bold = FALSE, italic = FALSE) {
  s <- gsub("(?<![A-Za-z])ET0(?![0-9A-Za-z])", "ET_0", s, perl = TRUE)   # ET0 -> ET with subscript 0
  m <- gregexpr(SUBPAT, s, perl = TRUE)[[1]]; if (m[1] < 0) return(list(ftext(s, tx(size, bold, italic))))
  out <- list(); pos <- 1
  for (k in seq_along(m)) { st <- m[k]; en <- st + attr(m, "match.length")[k] - 1; tok <- substr(s, st, en); b <- sub("_.*$", "", tok); sb <- sub("^[^_]*_", "", tok)
    if (st > pos) out[[length(out) + 1]] <- ftext(substr(s, pos, st - 1), tx(size, bold, italic))
    out[[length(out) + 1]] <- ftext(b, tx(size, bold, italic)); out[[length(out) + 1]] <- ftext(sb, tx(size, bold, italic, va = "subscript")); pos <- en + 1 }
  if (pos <= nchar(s)) out[[length(out) + 1]] <- ftext(substr(s, pos, nchar(s)), tx(size, bold, italic))
  out }
P   <- function(d, ..., size = 12, align = "justify", ls = 2, bold = FALSE, italic = FALSE) body_add_fpar(d, do.call(fpar, c(rich(paste0(...), size, bold, italic), list(fp_p = pp(align, ls)))))
H1  <- function(d, t) body_add_fpar(d, fpar(ftext(t, tx(12, bold = TRUE)), fp_p = pp("left", 2, 12, 6)))
H2  <- function(d, t) body_add_fpar(d, fpar(ftext(t, tx(12, bold = TRUE, italic = TRUE)), fp_p = pp("left", 2, 6, 3)))
png_dim <- function(f) { con <- file(f, "rb"); on.exit(close(con)); b <- readBin(con, "raw", 24)
  c(w = sum(as.integer(b[17:20]) * 256^(3:0)), h = sum(as.integer(b[21:24]) * 256^(3:0))) }
add_img <- function(d, f, width_in = 6.2) { dm <- png_dim(f); h <- width_in * dm[["h"]] / dm[["w"]]
  if (h > 8.4) { width_in <- width_in * 8.4 / h; h <- 8.4 }
  body_add_fpar(d, fpar(external_img(f, width = width_in, height = h), fp_p = fp_par(text.align = "center", padding.bottom = 4, keep_with_next = TRUE))) }

# ---------------- references: numbered in order of first citation ----------------
REFS <- fread(file.path(MS, "references.txt"), sep = "|", header = FALSE, col.names = c("key", "text"), quote = "", encoding = "UTF-8")
SRC <- readLines(file.path(MS, "manuscript_source.txt"), encoding = "UTF-8")
SRC <- SRC[nzchar(trimws(SRC))]
brk <- unlist(regmatches(SRC, gregexpr("\\[@[^]]+\\]", SRC)))
ORDER <- unique(sub("^@", "", trimws(unlist(strsplit(gsub("^\\[|\\]$", "", brk), ";")))))
missing_keys <- setdiff(ORDER, REFS$key); if (length(missing_keys)) stop("references missing: ", paste(missing_keys, collapse = ", "))
unused <- setdiff(REFS$key, ORDER)
cite <- function(s) {
  m <- gregexpr("\\[@[^]]+\\]", s)[[1]]; if (m[1] < 0) return(s)
  rep <- vapply(regmatches(s, list(m))[[1]], function(x) { k <- sub("^@", "", trimws(strsplit(gsub("^\\[|\\]$", "", x), ";")[[1]]))
    n <- sort(match(k, ORDER)); runs <- split(n, cumsum(c(1, diff(n) != 1)))
    paste0("[", paste(vapply(runs, function(r) if (length(r) > 2) paste0(r[1], "–", r[length(r)]) else paste(r, collapse = ","), ""), collapse = ","), "]") }, "")
  regmatches(s, list(m)) <- list(rep); s }

# ---------------- figures and tables of the paper ----------------
FIGMAP <- c(`1` = "Fig01_study_area", `2` = "Fig00_methodology_flowchart", `3` = "Fig02_observed_indices_trends", `4` = "Fig03_propagation_lag",
            `5` = "Fig04_GCM_skill_ranking", `6` = "Fig06_projected_change_maps", `7` = "Fig08_copula_return_periods", `8` = "Fig09_district_exposure",
            `9` = "Fig10_uncertainty_partition")   # for reference; the @@FIG markers of the manuscript source are authoritative
SFIGMAP <- c(`1` = "FigS1_ET0_comparison_VHI", `2` = "Fig05_QDM_validation", `3` = "Fig07_GWL_response")
mn <- function(x) gsub("(?<![A-Za-z0-9])-(?=[0-9])", "−", x, perl = TRUE)              # typographic minus
fmt_num <- function(v, d = 2) { if (!is.numeric(v)) return(mn(as.character(v))); out <- formatC(v, format = "f", digits = d); out[is.na(v)] <- "–"; mn(out) }
# ET0 in table headers and cells -> ET with subscript 0
et0_sub <- function(ft) {
  for (part in c("header", "body")) { d <- ft[[part]]$dataset
    for (j in ft$col_keys) { v <- as.character(d[[j]]); rows <- which(grepl("ET0", v, fixed = TRUE))
      for (i in rows) { z <- strsplit(v[i], "ET0", fixed = TRUE)[[1]]; if (endsWith(v[i], "ET0")) z <- c(z, "")
        ch <- list(); for (k in seq_along(z)) { ch <- c(ch, list(as_chunk(z[k]))); if (k < length(z)) ch <- c(ch, list(as_chunk("ET"), as_sub("0"))) }
        ft <- compose(ft, i = i, j = j, part = part, value = do.call(as_paragraph, ch)) } } }
  ft }
style_ft <- function(ft, size = 9, keep = TRUE) {
  ft <- et0_sub(ft)
  ft <- ft |> font(fontname = FONT, part = "all") |> fontsize(size = size, part = "all") |> bold(part = "header") |>
    align(align = "center", part = "header") |> border_remove() |> hline_top(border = fp_border(width = 1), part = "header") |>
    hline_bottom(border = fp_border(width = 0.5), part = "header") |> hline_bottom(border = fp_border(width = 1), part = "body") |>
    padding(padding = 1.5, part = "all") |> set_table_properties(layout = "autofit", width = 1)
  if (keep) paginate(ft, init = TRUE, hdr_ftr = TRUE) else ft   # short tables kept on one page; long ones flow with a repeated header
}
read_tab <- function(name) fread(file.path(TABD, paste0(name, ".csv")), encoding = "UTF-8")
TABLES <- list(
  `1` = function() { x <- read_tab("Table4_projected_changes"); x[, names(x) := lapply(.SD, mn)]; x },
  `2` = function() { x <- read_tab("Table5_return_periods")
    x <- x[, .(Set, Events = `Pooled events`, `L (model-yr)` = `Model-years L`, Copula = `Copula (AIC)`, `CvM p` = `CvM p`, `D margin, AD p` = `D: margin, AD p`,
               `S margin, AD p` = `S: margin, AD p`, `Events beyond reference` = `Events beyond the 25-yr reference`,
               `T_AND Bernstein (yr)` = `T_AND 25-yr, Bernstein`, `T_AND parametric (yr)` = `T_AND 25-yr, parametric`, `T_AND count (yr)` = `T_AND 25-yr, count`)]
    x[, names(x) := lapply(.SD, function(v) mn(as.character(v)))]; x },
  `3` = function() { x <- read_tab("Table6_exposure_by_district"); nm <- names(x)
    g <- function(p) x[[grep(p, nm, fixed = TRUE)[1]]]
    data.table(District = x$district, `Rainfed wheat (10³ ha)` = fmt_num(x$`Rainfed wheat (ha)` / 1e3, 1), `Rainfed groundnut (10³ ha)` = fmt_num(x$`Rainfed groundnut (ha)` / 1e3, 1),
               `Wheat ΔE, SSP2-4.5 mid (%)` = fmt_num(g("dE_wheat_pct_ssp245_mid"), 1), `Wheat ΔE, SSP2-4.5 far (%)` = fmt_num(g("dE_wheat_pct_ssp245_far"), 1),
               `Wheat ΔE, SSP5-8.5 mid (%)` = fmt_num(g("dE_wheat_pct_ssp585_mid"), 1), `Wheat ΔE, SSP5-8.5 far (%)` = fmt_num(g("dE_wheat_pct_ssp585_far"), 1),
               `Wheat share ≥ 1.5×, SSP5-8.5 far (%)` = fmt_num(g("share_wheat_ge15_ssp585_far"), 1),
               `Groundnut ΔE, SSP5-8.5 far (%)` = if (any(grepl("dE_gnut_pct_ssp585_far", nm))) fmt_num(g("dE_gnut_pct_ssp585_far"), 1) else "–") })
num_df <- function(x, d = 2) { x <- copy(as.data.table(x))
  for (j in names(x)) { v <- x[[j]]; whole <- is.numeric(v) && all(is.na(v) | abs(v - round(v)) < 1e-9); set(x, j = j, value = fmt_num(v, if (whole) 0 else d)) }
  setnames(x, gsub("_", " ", names(x))); x }   # whole numbers without decimals; readable headers
STABLES <- list(   # supplementary tables in citation order: number, csv, title, note
  list("Table1_station_QC_homogeneity", "Station quality control, completeness and relative homogeneity.", "Stations within 100 km of the plateau (GSOD/ISD, GHCN-Daily and PMD). Completeness counts months complete after short-gap filling. Homogeneity: SNHT and Pettitt tests at the 5% significance level on station/reference ratios (P, ET0) or differences (Tmax, Tmin) against CHIRPS/ERA5-Land and TerraClimate; suspect = both tests reject against both references. Evaluated for: variables used in the model and product evaluation."),
  list("Table2_trends", "Observed trends, 1981–2024.", "TFPW–Mann–Kendall test and Sen's slope per decade; district means with Benjamini–Hochberg control across the five units (p_BH)."),
  list("TableS5_soil_moisture", "Correlation of drought indices with standardised C3S/ESA CCI soil moisture.", "Regional series; Rabi: October–April."),
  list("TableS7_glofas_vs_wapda", "GloFAS-ERA5 v4.0 discharge against the WAPDA gauges (monthly).", "Gauge SRI-3 calibrated on 1985–2003 and GloFAS SRI-3 on 1985–2014; SRI-3 scores over 1985–2003. Source of gauge data: SWHP, WAPDA."),
  list("Table3_GCM_metrics_ranks", "Skill metrics and ranks of the 27 NEX-GDDP-CMIP6 models, 1985–2014.", "KGE, pattern correlation (PCC), normalised RMSD and station KGE per variable; rank from entropy-weighted compromise programming."),
  list("TableS2b_GCM_rank_stability", "Rank stability of the models in 1,000 moving-block bootstrap samples.", "P(top 10): share of samples in which a model ranked in the top 10; the ten models with the highest P(top 10) were retained."),
  list("TableS1_QDM_validation_v2", "Out-of-sample validation of QDM.", "Detrended split sample, odd/even-year cross-validation and pseudo-reality; mean absolute bias over cells and months, raw versus QDM."),
  list("TableS1b_QDM_plain_split_permonth", "Pre-registered acceptance test of QDM (plain split sample, per calendar month).", "Calibration 1985–1999, validation 2000–2014, 27 models; regional series after cell-level correction."),
  list("TableS4_district_robustness", "Robustness of the far-future change in drought frequency by district.", "Robust: at least 80% sign agreement and Benjamini–Hochberg-adjusted Wilcoxon p < 0.05."),
  list("TableS8_exposure_uncertainty", "Uncertainty of the change in drought exposure of rainfed wheat.", "Per-model change from each model's own cell drought frequencies; weights proportional to 1/L; model range: weighted 10th–90th percentiles; CI: 1,000 model-level bootstrap resamples."),
  list("TableS2_rainfed_check_CRS", "Rainfed crop areas: SPAM2010 against the Crop Reporting Service Punjab.", "Un-irrigated (barani) areas reported by the Crop Reporting Service; SPAM2010 rainfed areas."),
  list("TableS3_exposure_binary", "Binary exposure of rainfed crops to robust increases in drought frequency.", "Exposed = area inside 0.25° cells with a robust increase (at least 80% sign agreement and Benjamini–Hochberg-adjusted Wilcoxon p < 0.05)."),
  list("Table7_sensitivity", "Sensitivity of the far-future change in drought frequency.", "Change in the frequency of SPEI-3 ≤ −1 months, 2076–2100 relative to 1985–2014; skill-weighted mean with the 10th–90th percentile model range."),
  list("TableS6_model_set_sensitivity", "Sensitivity of the key far-future results to the model set.", "Weights proportional to 1/L within each set. † robust. T_AND: Bernstein copula return period of the baseline 25-year event.")
)
fig_caption <- function(d, lab, title, body) body_add_fpar(d, do.call(fpar, c(list(ftext(paste0(lab, ". "), tx(11, bold = TRUE))), rich(paste0(title, " "), 11, bold = TRUE),
                                                                            rich(cite(body), 11), list(fp_p = pp("justify", 1.15, 0, 12)))))
tab_caption <- function(d, lab, title) body_add_fpar(d, do.call(fpar, c(list(ftext(paste0(lab, ". "), tx(11, bold = TRUE))), rich(title, 11, bold = TRUE),
  list(fp_p = fp_par(text.align = "left", line_spacing = 1.15, padding.top = 6, padding.bottom = 3, keep_with_next = TRUE)))))
tab_note <- function(d, note) body_add_fpar(d, do.call(fpar, c(rich(cite(note), 9), list(fp_p = pp("justify", 1.0, 2, 12)))))
sens_dedup <- function(x) { x <- copy(x); x <- x[!grepl("^SPEI-3 with PM ET0$", Test)]; x }

# ---------------- Word equations and continuous line numbers ----------------
# Equations (1)-(8) are the Office Math (OMML) objects of the methodology document (cfg$paths$methodology_docx), in the same
# order. Each placeholder paragraph "@@EQMARKn@@" becomes: tab, equation, tab, "(n)" with a centre tab stop in the middle of the
# text width and a right tab stop at the margin. Line numbering restarts nowhere (w:restart="continuous").
METH_EQ <- local({ tmp <- tempfile(); zip::unzip(cfg$paths$methodology_docx, files = "word/document.xml", exdir = tmp)
  x <- paste(readLines(file.path(tmp, "word", "document.xml"), warn = FALSE, encoding = "UTF-8"), collapse = "")
  regmatches(x, gregexpr("<m:oMath>.*?</m:oMath>", x, perl = TRUE))[[1]] })
stopifnot(length(METH_EQ) == 8)
# Eq. (2): the gamma distribution is written G_Γ, because G is the soil heat flux in Eq. (1)
METH_EQ[2] <- sub("<m:r><m:t>G(x),</m:t></m:r>", "<m:sSub><m:e><m:r><m:t>G</m:t></m:r></m:e><m:sub><m:r><m:t>Γ</m:t></m:r></m:sub></m:sSub><m:r><m:t>(x),</m:t></m:r>", METH_EQ[2], fixed = TRUE)
stopifnot(grepl("<m:t>Γ</m:t>", METH_EQ[2], fixed = TRUE))
finalize_docx <- function(path) {
  tmp <- tempfile(); dir.create(tmp); zip::unzip(path, exdir = tmp)
  f <- file.path(tmp, "word", "document.xml"); x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  TW <- 9070   # text width in twips (21 cm - 2 x 2.5 cm)
  for (n in seq_along(METH_EQ)) {
    pat <- paste0("(?s)<w:p>(?:(?!</w:p>).)*?@@EQMARK", n, "@@(?:(?!</w:p>).)*?</w:p>")   # (?s): the XML is pretty-printed
    if (!grepl(pat, x, perl = TRUE)) next
    # display equation with Word's own numbering: a one-row equation array whose content ends in "#(n)" (number at the right margin)
    inner <- sub("^<m:oMath>", "", sub("</m:oMath>$", "", METH_EQ[n]))
    eqp <- paste0('<w:p><w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr><m:oMathPara><m:oMath><m:eqArr><m:eqArrPr><m:maxDist m:val="1"/><m:ctrlPr/></m:eqArrPr><m:e>',
                  inner, '<m:r><m:t>#(', n, ')</m:t></m:r></m:e></m:eqArr></m:oMath></m:oMathPara></w:p>')
    x <- sub(pat, eqp, x, perl = TRUE)
  }
  if (grepl("@@EQMARK", x, fixed = TRUE)) stop("equation placeholder left in ", path)
  x <- gsub("<w:lnNumType[^>]*/>", "", x)
  stopifnot(grepl("<w:pgMar[^>]*/>", x))
  x <- sub("(<w:pgMar[^>]*/>)", '\\1<w:lnNumType w:countBy="1" w:restart="continuous"/>', x)   # continuous line numbers (schema order: after pgMar)
  writeLines(x, f, useBytes = TRUE)
  old <- getwd(); setwd(tmp); on.exit(setwd(old)); file.remove(path)
  zip::zip(path, files = list.files(".", recursive = TRUE, all.files = TRUE), mode = "mirror"); invisible(path)
}

# ---------------- main manuscript ----------------
build_manuscript <- function(target, embed = TRUE) {
  d <- new_doc(); fig_store <- list(); tab_store <- list()
  for (line in SRC) {
    if (startsWith(line, "@@TITLE ")) d <- body_add_fpar(d, fpar(ftext(sub("^@@TITLE ", "", line), tx(16, bold = TRUE)), fp_p = pp("center", 1.5, 0, 12)))
    else if (startsWith(line, "@@AUTHORS ")) d <- body_add_fpar(d, fpar(ftext("Owais Ali", tx(12, bold = TRUE)), ftext("1*", tx(12, va = "superscript")), fp_p = pp("center", 1.5, 0, 6)))
    else if (startsWith(line, "@@AFFIL ")) d <- body_add_fpar(d, fpar(ftext("1", tx(11, va = "superscript")), ftext(sub("^@@AFFIL \\^1", "", line), tx(11)), fp_p = pp("center", 1.5, 0, 3)))
    else if (startsWith(line, "@@CORR ")) d <- body_add_fpar(d, fpar(ftext(sub("^@@CORR ", "", line), tx(11)), fp_p = pp("center", 1.5, 0, 12)))
    else if (startsWith(line, "@@KEYWORDS ")) d <- body_add_fpar(d, fpar(ftext("Keywords: ", tx(12, bold = TRUE)), ftext(sub("^@@KEYWORDS Keywords: ", "", line), tx(12)), fp_p = pp("left", 2, 6, 6)))
    else if (startsWith(line, "#! ")) d <- H1(d, sub("^#! ", "", line))
    else if (startsWith(line, "## ")) d <- H2(d, sub("^## ", "", line))
    else if (startsWith(line, "# ")) d <- H1(d, sub("^# ", "", line))
    else if (startsWith(line, "@@EQ ")) { z <- strsplit(sub("^@@EQ ", "", line), "|", fixed = TRUE)[[1]]   # placeholder, replaced by a Word equation in finalize_docx()
      d <- body_add_fpar(d, fpar(ftext(paste0("@@EQMARK", gsub("[^0-9]", "", z[1]), "@@"), tx(12)), fp_p = pp("center", 2, 3, 3))) }
    else if (startsWith(line, "@@FIG ")) { z <- strsplit(sub("^@@FIG ", "", line), "|", fixed = TRUE)[[1]]
      fig_store[[length(fig_store) + 1]] <- z
      if (embed) { d <- add_img(d, file.path(FIGD, paste0(z[2], ".png"))); d <- fig_caption(d, paste0("Figure ", z[1]), z[3], z[4]) } }
    else if (startsWith(line, "@@TAB ")) { z <- strsplit(sub("^@@TAB ", "", line), "|", fixed = TRUE)[[1]]
      tab_store[[length(tab_store) + 1]] <- z
      if (embed) { d <- tab_caption(d, paste0("Table ", z[1]), z[3]); d <- body_add_flextable(d, style_ft(flextable(TABLES[[z[1]]]()), 8)); d <- tab_note(d, z[4]) } }
    else d <- P(d, cite(line))
  }
  d <- H1(d, "References")
  for (i in seq_along(ORDER)) d <- body_add_fpar(d, fpar(ftext(paste0(i, ". "), tx(11)), ftext(REFS[key == ORDER[i], text], tx(11)), fp_p = pp("left", 1.5, 0, 4)))
  print(d, target = target); finalize_docx(target); invisible(list(figs = fig_store, tabs = tab_store))
}
st <- build_manuscript(file.path(OUT, "01_Manuscript", "Manuscript_clean.docx"))

# ---------------- separate figure files (copies; TIFF conversion in 24_word_finish.ps1) and tables ----------------
for (z in st$figs) file.copy(file.path(FIGD, paste0(z[2], ".pdf")), file.path(OUT, "03_Figures", paste0("Fig", z[1], ".pdf")), overwrite = TRUE)
for (z in st$figs) file.copy(file.path(FIGD, paste0(z[2], ".png")), file.path(OUT, "03_Figures", paste0("Fig", z[1], ".png")), overwrite = TRUE)
for (z in st$tabs) { d <- new_doc(); d <- tab_caption(d, paste0("Table ", z[1]), z[3]); d <- body_add_flextable(d, style_ft(flextable(TABLES[[z[1]]]()), 8)); d <- tab_note(d, z[4])
  print(d, target = file.path(OUT, "04_Tables", paste0("Table", z[1], ".docx"))) }
caps <- rbindlist(lapply(st$figs, function(z) data.table(figure = paste0("Figure ", z[1]), file = paste0("Fig", z[1]), source = z[2], title = z[3], legend = cite(z[4]))))
d <- new_doc(); d <- H1(d, "Figure legends")
for (i in seq_len(nrow(caps))) d <- fig_caption(d, caps$figure[i], caps$title[i], caps$legend[i])
print(d, target = file.path(OUT, "03_Figures", "Figure_legends.docx"))

# ---------------- supplementary material ----------------
SFIGCAP <- list(
  `1` = c("Reference evapotranspiration and vegetation health.", "(a) Mean annual cycle (1985–2014) of regional ET0 from the FAO-56 Penman–Monteith equation with ERA5-Land and TerraClimate inputs, TerraClimate and CRU TS potential evapotranspiration, and the Hargreaves method. (b) Cropland Vegetation Health Index (VHI, MODIS) and the regional SPEI-3 rescaled as 50 + 15·SPEI-3, 2000–2024; the dashed line is the VHI drought threshold of 40."),
  `2` = c("Out-of-sample validation of quantile delta mapping.", "(a) Mean absolute median and 90th-percentile bias and the Kolmogorov–Smirnov distance over cells and months for precipitation (P), Tmax, Tmin, relative humidity (RH), shortwave radiation (Rs) and wind, raw and after QDM, for the detrended split sample, odd/even-year cross-validation and the pseudo-reality test (27 models). (b) Bias in the frequency of drought months (SPI-3 ≤ −1) and of wet months (P ≥ 5 mm)."),
  `3` = c("Response at global warming levels.", "Change relative to 1985–2014 of drought frequency (SPEI-3 ≤ −1), duration D, severity S, annual precipitation and annual Penman–Monteith ET0 at +1.5, +2 and +3 °C global warming (relative to 1850–1900), using each model's 20-year window around the crossing year. Dots are the ten retained models; boxes show the median and interquartile range."))
d <- new_doc()
d <- body_add_fpar(d, fpar(ftext("Supplementary Information", tx(16, bold = TRUE)), fp_p = pp("center", 1.5, 0, 6)))
d <- body_add_fpar(d, fpar(ftext(SRC[startsWith(SRC, "@@TITLE ")] |> sub(pattern = "^@@TITLE ", replacement = ""), tx(12, italic = TRUE)), fp_p = pp("center", 1.5, 0, 6)))
d <- body_add_fpar(d, fpar(ftext("Owais Ali", tx(12)), fp_p = pp("center", 1.5, 0, 18)))
d <- H1(d, "Supplementary Figures")
for (i in names(SFIGMAP)) { d <- add_img(d, file.path(FIGD, paste0(SFIGMAP[[i]], ".png"))); d <- fig_caption(d, paste0("Supplementary Figure ", i), SFIGCAP[[i]][1], SFIGCAP[[i]][2])
  file.copy(file.path(FIGD, paste0(SFIGMAP[[i]], ".pdf")), file.path(OUT, "05_Supplementary", paste0("FigS", i, ".pdf")), overwrite = TRUE)
  file.copy(file.path(FIGD, paste0(SFIGMAP[[i]], ".png")), file.path(OUT, "05_Supplementary", paste0("FigS", i, ".png")), overwrite = TRUE) }
d <- H1(d, "Supplementary Tables")
for (i in seq_along(STABLES)) { s <- STABLES[[i]]; x <- read_tab(s[[1]]); if (s[[1]] == "Table7_sensitivity") x <- sens_dedup(x)
  x <- num_df(x); ft <- style_ft(flextable(x), if (ncol(x) > 10) 6.5 else 7.5, keep = nrow(x) <= 25)
  d <- tab_caption(d, paste0("Supplementary Table ", i), s[[2]]); d <- body_add_flextable(d, ft); d <- tab_note(d, s[[3]])
  dd <- new_doc(); dd <- tab_caption(dd, paste0("Supplementary Table ", i), s[[2]]); dd <- body_add_flextable(dd, ft); dd <- tab_note(dd, s[[3]])
  print(dd, target = file.path(OUT, "05_Supplementary", sprintf("TableS%d.docx", i))) }
print(d, target = file.path(OUT, "05_Supplementary", "Supplementary_Material.docx"))

# ---------------- title page ----------------
i0 <- which(SRC == "# Introduction"); i1 <- which(SRC == "#! Acknowledgements") - 1; body <- SRC[i0:i1]; body <- body[!grepl("^(#|@@)", body)]
WC_MAIN <- sum(lengths(strsplit(trimws(gsub("\\[[0-9,–]+\\]", "", vapply(body, cite, ""))), "\\s+")))
WC_ABS <- length(strsplit(trimws(SRC[which(SRC == "# Abstract") + 1]), "\\s+")[[1]])
title <- sub("^@@TITLE ", "", SRC[startsWith(SRC, "@@TITLE ")])
d <- new_doc()
d <- body_add_fpar(d, fpar(ftext("Title page", tx(12, bold = TRUE)), fp_p = pp("left", 2, 0, 12)))
d <- body_add_fpar(d, fpar(ftext(title, tx(16, bold = TRUE)), fp_p = pp("center", 1.5, 0, 12)))
d <- body_add_fpar(d, fpar(ftext("Owais Ali", tx(12, bold = TRUE)), ftext("1*", tx(12, va = "superscript")), fp_p = pp("center", 1.5, 0, 6)))
d <- body_add_fpar(d, fpar(ftext("1", tx(11, va = "superscript")), ftext("Department of Space Science, Institute of Space Technology, Islamabad, Pakistan", tx(11)), fp_p = pp("center", 1.5, 0, 12)))
for (l in c("Corresponding author: Owais Ali, Department of Space Science, Institute of Space Technology, Islamabad, Pakistan. E-mail: owais.ali.bahria@gmail.com",
            "ORCID: [AUTHOR CHECK: ORCID iD]",
            paste0("Running title: Future droughts over the Potohar Plateau"),
            paste0("Word count (main text from Introduction to Conclusions, excluding abstract, equations, references, figure and table legends): ", WC_MAIN, "; abstract: ", WC_ABS, " words"),
            paste0("Figures: ", length(st$figs), "; Tables: ", length(st$tabs), "; Supplementary Figures: ", length(SFIGMAP), "; Supplementary Tables: ", length(STABLES))))
  d <- P(d, l, align = "left", ls = 1.5)
print(d, target = file.path(OUT, "02_Title_Page", "Title_Page.docx"))

# ---------------- highlights ----------------
HL <- c("Drought months rise 10–11 points by 2076–2100 despite 16–32% more rain",
        "The increase falls in winter and spring, the season of rainfed wheat",
        "December SPEI-3 tracks official district wheat yields best (r = 0.60)",
        "A 1-in-33–50-year seven-month drought becomes about a 1-in-10-year event",
        "Drought exposure of rainfed wheat grows 62–71%; model spread dominates")
stopifnot(all(nchar(HL) <= 85))
d <- new_doc(); d <- H1(d, "Highlights")
for (h in HL) d <- body_add_fpar(d, fpar(ftext(paste0("•  ", h), tx(12)), fp_p = pp("left", 1.5, 0, 6)))
print(d, target = file.path(OUT, "06_Graphical_Abstract", "Highlights.docx"))
writeLines(c("Highlights (each <= 85 characters):", paste0("- ", HL, "  [", nchar(HL), " characters]")), file.path(OUT, "06_Graphical_Abstract", "Highlights.txt"), useBytes = TRUE)

# ---------------- cover letter ----------------
d <- new_doc()
cl <- c("Owais Ali", "Department of Space Science, Institute of Space Technology, Islamabad, Pakistan", "owais.ali.bahria@gmail.com", "",
        format(Sys.Date(), "%d %B %Y"), "", "The Editor", "[AUTHOR CHECK: journal name]", "",
        "Dear Editor,", "",
        paste0("I am pleased to submit the manuscript \"", title, "\" for consideration as an original research article."),
        "The Potohar Plateau of northern Punjab grows almost all of its wheat without irrigation, and its harvest depends on rain that falls in the cool season. The manuscript presents the first drought projection for the plateau with bias-corrected CMIP6 models under the Shared Socioeconomic Pathways. It chooses the drought index by its link to official district wheat yields, uses station records of the Pakistan Meteorological Department and gauged discharge of WAPDA, and estimates joint duration–severity return periods and the drought exposure of rainfed crops with their uncertainty.",
        "The main findings are as follows. Drought months become 10–11 percentage points more frequent by 2076–2100 under SSP2-4.5 and SSP5-8.5, although annual rainfall increases. The increase falls in winter and spring, the growing season of rainfed wheat, because rainfall then barely changes while evaporative demand rises. A seven-month drought that recurred about once in 33–50 years in 1985–2014 recurs about once in 10 years, and the drought exposure of rainfed wheat grows by 62–71%. The result holds in every sensitivity test, in a second downscaling chain and across model sets. The rules for model selection and bias correction were fixed before the projections were computed, and every number is generated from the analysis outputs.",
        "These results matter for food security and drought planning in Pakistan and for semi-arid South Asia more generally, where a wetter monsoon may be accompanied by drier cropping seasons. They show that drought assessments based on rainfall alone understate the risk.",
        "I confirm that this manuscript is original, has not been published elsewhere and is not under consideration by another journal. I have approved the submission and declare no competing interests. The data sources are public, except the PMD station and WAPDA discharge records, which were obtained from these agencies; the analysis code will be made available.",
        "Suggested reviewers: [AUTHOR CHECK: name, affiliation and e-mail of 3–5 independent experts in drought projection, CMIP6 bias correction or South Asian hydroclimate].", "",
        "Thank you for considering this manuscript.", "", "Sincerely,", "", "Owais Ali")
for (l in cl) d <- P(d, l, align = "left", ls = 1.15)
print(d, target = file.path(OUT, "07_Cover_Letter", "Cover_Letter.docx"))

# ---------------- declarations ----------------
grab <- function(h) { i <- which(SRC == paste0("#! ", h)); if (!length(i)) return(character()); cite(SRC[i + 1]) }
d <- new_doc(); d <- H1(d, "Declarations")
DEC <- list(`CRediT authorship contribution statement` = "Owais Ali: Conceptualization, Methodology, Software, Validation, Formal analysis, Investigation, Data curation, Writing – original draft, Writing – review & editing, Visualization, Project administration.",
            Funding = grab("Funding"), `Competing interests` = grab("Competing interests"), `Data availability` = grab("Data availability"),
            `Code availability` = grab("Code availability"), `Use of AI tools` = grab("Use of AI tools"), Acknowledgements = grab("Acknowledgements"),
            `Ethics approval` = "Not applicable: the study uses climate, hydrological and agricultural statistics only.")
for (h in names(DEC)) { d <- H2(d, h); d <- P(d, DEC[[h]], ls = 1.5) }
print(d, target = file.path(OUT, "09_Declarations", "Declarations.docx"))

writeLines(c("Not applicable: this is a new submission.", "Tracked-changes manuscript and response to reviewers are prepared only for revisions."),
           file.path(OUT, "08_Response_to_Reviewers", "README.txt"))
cat("built:", OUT, "| references cited:", length(ORDER), "| unused references:", if (length(unused)) paste(unused, collapse = ", ") else "none", "\n")
