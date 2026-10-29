# v2.2 Item 3 (PREREGISTRATION.md): quantile delta mapping helpers shared by production, validation and diagnostics.
qdm1 <- function(oc, mc, mp, ratio, ratio.max = 2, trace = 0.05, n.tau = NULL) {
  ok <- !is.na(oc); oc <- oc[ok]; mc <- mc[!is.na(mc)]
  if (length(oc) < 10 || length(mc) < 10 || !length(mp)) return(mp)
  as.numeric(MBC::QDM(oc, mc, mp, ratio = ratio, trace = if (ratio) trace else 0, jitter.factor = if (ratio) 0.01 else 0,
                      ratio.max = ratio.max, n.tau = n.tau)$mhat.p)
}
NB3 <- function(m) ((c(m - 1, m, m + 1) - 1) %% 12) + 1     # calendar month and its two neighbours (sensitivities S1, S2)
QDM_METHODS <- c(primary = "permonth", S1 = "pooled_std", S2 = "pooled")
mclim <- function(z, zm) sapply(1:12, function(k) mean(z[zm == k], na.rm = TRUE))
# v2.2 Item 3 (PREREGISTRATION.md): QDM of one cell. o/Om and h/Hm are the calibration-period observations and model values
# with their calendar months; x/Xm are the values to correct. method:
#   "permonth"   primary (methodology III-E): quantile functions of each calendar month from that month only (~30 values);
#   "pooled"     S2 (v2.1, DEVIATIONS D13): the month and its two neighbours pooled (~90 values), values kept for the target month;
#   "pooled_std" S1: as "pooled", after standardising each month by its own calibration climatology (ratio for multiplicative,
#                anomaly for additive variables; model values by the model climatology), back-transformed with the target
#                month's observed climatology.
qdm_cell <- function(o, Om, h, Hm, x, Xm, ratio, method = "permonth", ...) {
  out <- x; xs <- x
  if (method == "pooled_std") { co <- mclim(o, Om); ch <- mclim(h, Hm)
    st <- function(z, zm, cl) if (ratio) z / pmax(cl[zm], 1e-6) else z - cl[zm]
    o <- st(o, Om, co); h <- st(h, Hm, ch); xs <- st(x, Xm, ch) }
  nb <- if (method == "permonth") function(m) m else NB3
  for (m in 1:12) { it <- Xm == m; if (!any(it)) next
    iw <- Xm %in% nb(m); r <- qdm1(o[Om %in% nb(m)], h[Hm %in% nb(m)], xs[iw], ratio, ...)[Xm[iw] == m]
    out[it] <- if (method == "pooled_std") { if (ratio) r * co[m] else r + co[m] } else r }
  out
}
