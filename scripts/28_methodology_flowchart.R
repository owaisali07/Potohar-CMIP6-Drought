# Methodology workflow figure for the manuscript (same layout and colours as ../scripts/methodology_flowchart.py, labels updated
# to the final analysis, Times New Roman). Usage (from analysis/): Rscript scripts/28_methodology_flowchart.R
suppressMessages({ library(ggplot2); library(data.table) })
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root
FONT <- "Times New Roman"
COL <- list(inp = c("#E3EEF8", "#2E6AA6"), proc = c("#FDF0DC", "#C98A2E"), dec = c("#FBE1E1", "#B03A3A"), int = c("#ECE6F4", "#6A4C9C"), out = c("#E5F1E2", "#3E8A3A"))
box <- function(x, y, w, h, txt, k) data.table(x = x, y = y, w = w, h = h, txt = txt, fill = COL[[k]][1], col = COL[[k]][2], shape = k)
L <- 25; R <- 75; W <- 44
B <- rbind(
  box(L, 118, W, 13, "PMD stations (Islamabad, Murree) with GSOD/GHCN-D;\nWAPDA gauges (Soan, Sil); CHIRPS, ERA5-Land,\nTerraClimate, CRU TS; MODIS, ESA CCI; district yields", "inp"),
  box(R, 118, W, 13, "27 NEX-GDDP-CMIP6 models\n(historical, SSP2-4.5, SSP5-8.5);\nbaseline 1985–2014", "inp"),
  box(L, 99, W, 10, "QC, relative homogeneity (SNHT, Pettitt),\ngap filling; ET₀ by FAO-56 Penman–Monteith", "proc"),
  box(L, 84, W, 10, "SPI, SPEI, RDI (1–12 months); SRI and SDI\n(WAPDA gauges, GloFAS-ERA5); VHI", "proc"),
  box(L, 69, W, 10, "Trends (TFPW–Mann–Kendall, Sen, FDR);\nrun theory; propagation lag", "proc"),
  box(L, 54, W, 10, "Index selection with detrended wheat yields\n→ SPEI-3 ending in December", "proc"),
  box(R, 99, W, 10, "Evaluation against CHIRPS, ERA5-Land and stations\n(KGE, pattern correlation, nRMSD)", "proc"),
  box(R, 84, 30, 11, "Top 10 in bootstrap\ncompromise programming?", "dec"),
  box(R, 69, W, 10, "Quantile delta mapping (per cell and month);\nsplit-sample and pseudo-reality validation", "proc"),
  box(R, 54, W, 10, "SPEI-3 projections: 2025–2050, 2051–2075,\n2076–2100; +1.5, +2 and +3 °C", "proc"),
  box(50, 35, 90, 11, "Change in drought frequency, duration and severity; robustness (≥ 80% agreement, FDR);\njoint duration–severity return periods (Bernstein copula, parametric copula, count)", "int"),
  box(50, 20, 70, 10, "Graded drought exposure of rainfed wheat and groundnut by district,\nwith model range and bootstrap confidence intervals", "int"),
  box(17, 5, 30, 9, "Projected drought characteristics\nand return periods", "out"),
  box(50, 5, 30, 9, "District exposure\nand hotspot maps", "out"),
  box(83, 5, 30, 9, "Uncertainty partition and\nsensitivity tests", "out"))
B[, id := .I]
poly <- rbindlist(lapply(seq_len(nrow(B)), function(i) { b <- B[i]
  if (b$shape == "inp") data.table(id = i, px = c(b$x - b$w / 2 + 2, b$x + b$w / 2 + 2, b$x + b$w / 2 - 2, b$x - b$w / 2 - 2), py = c(b$y + b$h / 2, b$y + b$h / 2, b$y - b$h / 2, b$y - b$h / 2))
  else if (b$shape == "dec") data.table(id = i, px = c(b$x, b$x + b$w / 2, b$x, b$x - b$w / 2), py = c(b$y + b$h / 2, b$y, b$y - b$h / 2, b$y))
  else data.table(id = i, px = c(b$x - b$w / 2, b$x + b$w / 2, b$x + b$w / 2, b$x - b$w / 2), py = c(b$y + b$h / 2, b$y + b$h / 2, b$y - b$h / 2, b$y - b$h / 2)) }))
poly <- merge(poly, B[, .(id, fill, col)], by = "id")
arr <- function(x1, y1, x2, y2) data.table(x1 = x1, y1 = y1, x2 = x2, y2 = y2)
A <- rbind(arr(L, 111.5, L, 104), arr(L, 94, L, 89), arr(L, 79, L, 74), arr(L, 64, L, 59), arr(L, 49, L, 40.5),
           arr(R, 111.5, R, 104), arr(R, 94, R, 89.5), arr(R, 78.5, R, 74), arr(R, 64, R, 59), arr(R, 49, R, 40.5),
           arr(50, 29.5, 50, 25), arr(50, 15, 17, 9.5), arr(50, 15, 50, 9.5), arr(50, 15, 83, 9.5))
p <- ggplot() +
  geom_polygon(data = poly, aes(px, py, group = id, fill = fill, colour = col), linewidth = 0.6) + scale_fill_identity() + scale_colour_identity() +
  geom_segment(data = A, aes(x = x1, y = y1, xend = x2, yend = y2), linewidth = 0.45, colour = "grey25", arrow = arrow(length = unit(0.12, "cm"), type = "closed")) +
  geom_text(data = B, aes(x, y, label = txt), family = FONT, size = 2.55, lineheight = 0.95, fontface = "bold", colour = "grey10") +
  annotate("text", x = R + 17.5, y = 84, label = "No: not\nretained", family = FONT, size = 2.3, fontface = "italic", hjust = 0, colour = "grey30") +
  annotate("text", x = R + 2, y = 76.3, label = "Yes", family = FONT, size = 2.3, fontface = "italic", hjust = 0, colour = "grey30") +
  annotate("text", x = L, y = 128, label = "Observed drought (1981–2024)", family = FONT, size = 3.2, fontface = "bold", colour = "grey25") +
  annotate("text", x = R, y = 128, label = "Future drought (CMIP6, 2025–2100)", family = FONT, size = 3.2, fontface = "bold", colour = "grey25") +
  annotate("text", x = 50, y = 44, label = "Integration and change detection", family = FONT, size = 3, fontface = "bold", colour = "grey25") +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 131), expand = FALSE) + theme_void() + theme(plot.background = element_rect(fill = "white", colour = NA))
for (dev in c("png", "pdf")) ggsave(file.path(ROOT, "figures", paste0("Fig00_methodology_flowchart.", dev)), p, width = 180, height = 205, units = "mm", dpi = 600,
                                    device = if (dev == "png") ragg::agg_png else cairo_pdf, bg = "white")
cat("flowchart written\n")
