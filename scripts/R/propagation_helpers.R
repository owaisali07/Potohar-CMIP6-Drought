# v3.1: meteorological-to-hydrological drought propagation (methodology III-D): lag of maximum cross-correlation between
# catchment SPEI-k (k = 1-12) and SRI-1, lags 0-6 months. Each gauge is paired with the SPEI of its own catchment.
# ym: year * 12 + month of the SRI series; sri: named list of SRI-1 vectors; spei: named list (same names) of
# lists SPEI1..SPEI12 (one column each) on the observed months yr_obs/mon_obs; from/to: years of SRI used.
prop_tab <- function(ym, sri, spei, yr_obs, mon_obs, from = -Inf, to = Inf, lags = 0:6, ks = 1:12) {
  stopifnot(identical(sort(names(sri)), sort(names(spei))))
  keep <- ym >= from * 12 + 1 & ym <= to * 12 + 12
  rbindlist(lapply(ks, function(k) rbindlist(lapply(lags, function(L) {
    out <- data.table(k = k, lag = L)
    for (g in names(sri)) {
      s <- data.table(ym = yr_obs * 12L + mon_obs + L, spei = as.numeric(spei[[g]][[paste0("SPEI", k)]][, 1]))   # SPEI at t paired with SRI at t + L
      m <- merge(s, data.table(ym = ym[keep], sri = sri[[g]][keep]), by = "ym")
      set(out, j = paste0("r_", g), value = cor(m$spei, m$sri, use = "complete.obs"))
      set(out, j = paste0("n_", g), value = sum(stats::complete.cases(m)))
    }
    out }))))
}
# best k and lag for gauge g (max r over all lags), and best k at lag 0
prop_best <- function(P, g) {
  r <- P[[paste0("r_", g)]]; b <- which.max(r); i0 <- which(P$lag == 0); b0 <- i0[which.max(r[i0])]
  list(best_k = P$k[b], best_lag = P$lag[b], r = r[b], n = P[[paste0("n_", g)]][b], best_k_lag0 = P$k[b0], r_lag0 = r[b0])
}
