# v2.2 Item 4 (PREREGISTRATION.md): GCM ranking by compromise programming with entropy (primary), CRITIC or equal criterion
# weights, and the per-replicate metric recomputation used by the moving-block bootstrap.
library(data.table)

kge <- function(s, o) { r <- cor(s, o); a <- sd(s) / sd(o); b <- mean(s) / mean(o)
  c(KGE = 1 - sqrt((r - 1)^2 + (a - 1)^2 + (b - 1)^2), r = r, alpha = a, beta = b) }

# normalised distances d in [0, 1] (0 best) per criterion; best/worst over models with KGE >= 0 for every variable
cp_criteria <- function(EV) {
  cr <- melt(EV[, .(model, variable, KGE, PCC, nRMSD, KGE_station)], id.vars = c("model", "variable"), variable.name = "metric")
  cr[, criterion := paste(variable, metric, sep = ":")]
  cr <- cr[, if (!all(is.na(value))) .SD, by = criterion]   # v3.1: a criterion without data (no eligible station for a variable) is dropped
  ns <- EV[KGE < 0, unique(model)]
  cr[, d := { ok <- !model %in% ns
              best <- if (metric[1] == "nRMSD") min(value[ok]) else max(value[ok]); worst <- if (metric[1] == "nRMSD") max(value[ok]) else min(value[ok])
              if (best == worst) 0 else pmin(abs(best - value) / abs(best - worst), 1) }, by = criterion]
  cr
}

# criterion weights from the [model x criterion] matrix of distances M; benefit b = 1 - d
crit_weights <- function(M, weighting = "entropy") {
  B <- 1 - M; n <- nrow(B)
  w <- switch(weighting,
    equal   = rep(1 / ncol(B), ncol(B)),
    entropy = { P <- sweep(B + 1e-6, 2, colSums(B + 1e-6), "/"); e <- -colSums(P * log(P)) / log(n); (1 - e) / sum(1 - e) },
    critic  = { sdv <- apply(B, 2, sd); R <- diag(ncol(B)); ok <- sdv > 0; R[ok, ok] <- cor(B[, ok, drop = FALSE])   # constant criteria: sd = 0 -> weight 0
                cw <- sdv * colSums(1 - R); cw / sum(cw) },
    stop("unknown weighting: ", weighting))
  setNames(w, colnames(M))
}

# L = sqrt(sum_j w_j d_ij^2 / sum_j w_j); models failing the skill screen are ranked last
cp_rank <- function(EV, weighting = "entropy") {
  cr <- cp_criteria(EV); ns <- EV[KGE < 0, unique(model)]
  D <- dcast(cr, model ~ criterion, value.var = "d"); M <- as.matrix(D[, -1, with = FALSE]); rownames(M) <- D$model
  w <- crit_weights(M, weighting)
  L <- sqrt(as.numeric(M^2 %*% w) / sum(w))
  out <- data.table(model = D$model, L = L, noskill = D$model %in% ns); setorder(out, noskill, L); out[, rank := seq_len(.N)]
  list(rank = out[, .(model, L, rank, noskill)], weights = w)
}

# v3.1: station KGE of one variable = mean over 0.25 deg cells of KGE(model cell, mean of the eligible stations in that cell), so that
# stations sharing a cell (e.g. Chaklala and Islamabad) count once. clim_of(st) returns the station's 12-month climatology.
station_kge <- function(simv, clim_of, stations, cells) {
  if (!length(stations)) return(NA_real_)
  g <- split(stations, cells[stations])
  mean(vapply(names(g), function(cc) kge(simv[, as.integer(cc)], rowMeans(do.call(cbind, lapply(g[[cc]], clim_of)), na.rm = TRUE))[["KGE"]], numeric(1)), na.rm = TRUE)
}

# per-year monthly fields for the evaluation years BYRS: gridded obs and models as [year x (12 * cell)] (month fastest),
# stations as [year x month]. Uses the analysis globals (OBS, GCM, MODELS, STX, ST_EVAL, BYRS, ...).
eval_stacks <- function() {
  yr_stack <- function(M, months, years) t(sapply(BYRS, function(y) { i <- which(years == y); stopifnot(length(i) == 12); as.numeric(M[i[order(months[i])], , drop = FALSE]) }))
  obs <- list(pr = yr_stack(OBS$chirps_pr, MON_OBS, YR_OBS), tasmax = yr_stack(OBS$e5_tasmax, MON_OBS, YR_OBS),
              tasmin = yr_stack(OBS$e5_tasmin, MON_OBS, YR_OBS), ET0 = yr_stack(OBS$pm_et0, MON_OBS, YR_OBS))
  st <- lapply(setNames(ST_EVAL, ST_EVAL), function(s) {
    d <- STX[[s]]$data[year %in% BYRS, lapply(.SD, function(z) if (all(is.na(z))) NA_real_ else mean(z, na.rm = TRUE)), by = .(year, month), .SDcols = c("P", "Tmax", "Tmin", "ET0")]
    lapply(c(pr = "P", tasmax = "Tmax", tasmin = "Tmin", ET0 = "ET0"), function(v) { A <- matrix(NA_real_, length(BYRS), 12); A[cbind(match(d$year, BYRS), d$month)] <- d[[v]]; A }) })
  mod <- lapply(setNames(MODELS, MODELS), function(m) { x <- GCM[[m]]$historical; et <- gcm_et0(x, MON_H, ndays = days_in_month(D_H))
    list(pr = yr_stack(x$pr, MON_H, YR_H), tasmax = yr_stack(x$tasmax, MON_H, YR_H), tasmin = yr_stack(x$tasmin, MON_H, YR_H), ET0 = yr_stack(et, MON_H, YR_H)) })
  list(obs = obs, st = st, mod = mod)
}

# the 16 metrics of every model from year counts cnt (length(BYRS)); cnt = 1 for all years reproduces the full-sample EVAL
eval_from_counts <- function(S, cnt) {
  w <- cnt / sum(cnt)
  clim <- function(Y) matrix(crossprod(w, Y), nrow = 12)
  stc <- function(A) { ok <- !is.na(A); colSums(cnt * replace(A, !ok, 0)) / colSums(cnt * ok) }
  oc <- lapply(S$obs, clim); sc <- lapply(S$st, function(x) lapply(x, stc))
  rbindlist(lapply(names(S$mod), function(m) { sim <- lapply(S$mod[[m]], clim)
    rbindlist(lapply(names(sim), function(v) { sv <- sim[[v]][, REGC]; o <- oc[[v]][, REGC]
      k <- kge(as.numeric(sv), as.numeric(o))
      kst <- station_kge(sim[[v]], function(st) sc[[st]][[v]], ST_EVAL_V[[v]], st_cells)
      data.table(model = m, variable = v, KGE = k[["KGE"]], PCC = cor(colMeans(sv), colMeans(o)), nRMSD = sqrt(mean((sv - o)^2)) / sd(as.numeric(o)), KGE_station = kst) })) }))
}
