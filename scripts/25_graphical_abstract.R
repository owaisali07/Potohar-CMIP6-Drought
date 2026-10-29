# Graphical abstract for the submission (Times New Roman; values from results_text/key_numbers.rds).
# Usage (from analysis/): Rscript scripts/25_graphical_abstract.R <submission_dir>
suppressMessages({ library(data.table); library(ggplot2); library(patchwork) })
args <- commandArgs(trailingOnly = TRUE); stopifnot(length(args) == 1)
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml")); ROOT <- cfg$paths$root; OUT <- file.path(args[1], "06_Graphical_Abstract")
K <- readRDS(file.path(ROOT, "results_text", "key_numbers.rds"))
th <- theme_bw(base_size = 9, base_family = "Times New Roman") +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 9, face = "bold", hjust = 0.5), axis.title = element_text(size = 8),
        legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = 7), legend.key.size = unit(0.3, "cm"))
SC <- c(ssp245 = "SSP2-4.5", ssp585 = "SSP5-8.5"); COL <- c(`SSP2-4.5` = "#0072B2", `SSP5-8.5` = "#D55E00")
s <- as.data.table(K$seasonal_changes)[period == "far" & season %in% c("DJF", "MAM", "JJA", "SON")]
s[, `:=`(season = factor(season, levels = c("DJF", "MAM", "JJA", "SON"), labels = c("Winter\n(DJF)", "Spring\n(MAM)", "Monsoon\n(JJA)", "Autumn\n(SON)")), sc = SC[scenario])]
pa <- ggplot(s, aes(season, d_freq, fill = sc)) + geom_col(position = position_dodge(0.75), width = 0.7) + geom_hline(yintercept = 0, linewidth = 0.3) +
  scale_fill_manual(values = COL) + labs(x = NULL, y = "Δ drought frequency (%-points)", title = "Drought shifts to winter–spring") + th
ct <- as.data.table(K$copula_T)[T_ref == 25 & estimator == "bernstein" & set %in% c("Baseline (1985–2014)", "SSP2-4.5 far", "SSP5-8.5 far")]
ct[, lab := factor(c(`Baseline (1985–2014)` = "1985–2014", `SSP2-4.5 far` = "2076–2100\nSSP2-4.5", `SSP5-8.5 far` = "2076–2100\nSSP5-8.5")[set],
                   levels = c("1985–2014", "2076–2100\nSSP2-4.5", "2076–2100\nSSP5-8.5"))]
ct[, hi_p := pmin(hi, 2 * model_years)]
pb <- ggplot(ct, aes(lab, T_and)) + geom_point(size = 2.2, colour = c("grey30", COL)) + geom_errorbar(aes(ymin = lo, ymax = hi_p), width = 0.15, linewidth = 0.4, colour = c("grey30", COL)) +
  geom_point(data = ct[hi > 2 * model_years], aes(y = hi_p), shape = 2, size = 1.6) +
  geom_text(aes(label = sprintf("%.0f yr", T_and)), hjust = -0.35, family = "Times New Roman", size = 2.6) + scale_y_log10(breaks = c(5, 10, 20, 50, 100, 300)) +
  labs(x = NULL, y = "Return period (years, log)", title = "7-month drought: ~1-in-10 yr") + th
e <- as.data.table(K$exposure_uncertainty)[district == "Potohar (all units)" & period == "far"][, sc := SC[scenario]]
pc <- ggplot(e, aes(sc, dE_wmean, fill = sc)) + geom_col(width = 0.55) + geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.18, linewidth = 0.3) +
  geom_text(aes(label = sprintf("+%.0f%%", dE_wmean)), vjust = -0.6, hjust = -0.3, family = "Times New Roman", size = 2.6) +
  scale_fill_manual(values = COL, guide = "none") + labs(x = NULL, y = "Δ wheat drought exposure (%)", title = "Wheat exposure +62–71%") + th
ga <- (pa | pb | pc) + plot_annotation(title = "Future droughts over the rainfed Potohar Plateau (10 CMIP6 models, 2076–2100 vs 1985–2014)",
                                       theme = theme(plot.title = element_text(family = "Times New Roman", size = 10, face = "bold", hjust = 0.5)))
for (dev in c("png", "pdf")) ggsave(file.path(OUT, paste0("Graphical_Abstract.", dev)), ga, width = 17, height = 7.2, units = "cm", dpi = 600,
                                    device = if (dev == "png") ragg::agg_png else cairo_pdf, bg = "white")
cat("graphical abstract written\n")
