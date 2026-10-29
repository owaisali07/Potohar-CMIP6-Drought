# v2.2 Item 2 (PREREGISTRATION.md): one duration rule for every return-period estimator.
# Durations are whole months. A continuous reference quantile d_ref is converted once to k = round(d_ref) (>= 1); an event
# exceeds it if D >= k. Copula estimators evaluate the D marginal at the continuity-corrected value k - 0.5, so that
# P(D >= k) = 1 - F_D(k - 0.5) refers to the same events as the counting estimator. S is continuous (S >= s_ref).
ref_duration_k     <- function(d_ref) pmax(1L, as.integer(round(d_ref)))
exceeds_duration   <- function(D, d_ref) D >= ref_duration_k(d_ref)
duration_cdf_point <- function(d_ref) ref_duration_k(d_ref) - 0.5

# v3.1 margins. Discrete: "geom1", "pois1", "nbinom1" model D - 1 for D >= 1 (whole months): P(D <= q) = F(floor(q) - 1).
# Continuous with a known lower bound of 1: "<dist>.loc1" models S - 1 (S >= 1 because every drought month adds |index| >= 1).
shifted <- function(m) grepl("^(geom|pois|nbinom)1$", m$dist)
loc1 <- function(m) grepl("\\.loc1$", m$dist)
base_dist <- function(m) sub("\\.loc1$|1$", "", m$dist)
# Semiparametric margin "egpd" for S - 1: empirical body (Weibull plotting positions i/(n+1)) up to the 90th percentile u and a generalized
# Pareto tail above u fitted by maximum likelihood to the exceedances (used when no parametric family fits a large sample).
fit_egpd <- function(x, p_u = 0.90) {
  z <- sort(pmax(x - 1, 0)); n <- length(z); u <- unname(quantile(z, p_u, type = 7)); y <- z[z > u] - u
  nll <- function(th) { xi <- th[1]; be <- exp(th[2]); a <- 1 + xi * y / be
    if (any(a <= 0)) return(1e10); if (abs(xi) < 1e-8) return(length(y) * log(be) + sum(y) / be)
    length(y) * log(be) + (1 + 1 / xi) * sum(log(a)) }
  o <- optim(c(0.1, log(mean(y))), nll, method = "Nelder-Mead", control = list(maxit = 2000))
  xi <- min(max(o$par[1], -0.5), 1); be <- exp(o$par[2])
  pu <- mean(z <= u); body <- z[z < u]
  list(xs = c(0, body, u), Fs = c(0, seq_along(body) / (n + 1), pu), u = u, pu = pu, xi = xi, beta = be, n = n)
}
p_egpd <- function(e, z) { z <- pmax(z, 0); out <- approx(e$xs, e$Fs, z, rule = 2, ties = max)$y; t <- z > e$u
  if (any(t)) out[t] <- e$pu + (1 - e$pu) * (if (abs(e$xi) < 1e-8) 1 - exp(-(z[t] - e$u) / e$beta) else 1 - pmax(1 + e$xi * (z[t] - e$u) / e$beta, 0)^(-1 / e$xi))
  out }
q_egpd <- function(e, p) { out <- approx(e$Fs, e$xs, pmin(p, e$pu), rule = 2, ties = "ordered")$y; t <- p > e$pu
  if (any(t)) { r <- (1 - p[t]) / (1 - e$pu); out[t] <- e$u + (if (abs(e$xi) < 1e-8) -e$beta * log(r) else e$beta / e$xi * (r^(-e$xi) - 1)) }
  out }
pmarg <- function(m, q) {
  if (m$dist == "egpd") return(p_egpd(m$est, q - 1))
  if (shifted(m)) return(do.call(paste0("p", base_dist(m)), c(list(floor(q) - 1), as.list(m$est))))
  if (loc1(m)) return(do.call(paste0("p", base_dist(m)), c(list(pmax(q - 1, 0)), as.list(m$est))))
  do.call(paste0("p", m$dist), c(list(q), as.list(m$est)))
}
qmarg <- function(m, p) {
  if (m$dist == "egpd") return(q_egpd(m$est, p) + 1)
  if (shifted(m) || loc1(m)) return(do.call(paste0("q", base_dist(m)), c(list(p), as.list(m$est))) + 1)
  do.call(paste0("q", m$dist), c(list(p), as.list(m$est)))
}

#' AND return period by parametric copula, empirical Bernstein (beta) copula and counting.
#' rule = "whole_months" (primary, v2.2) or "continuous_v2.1" (previous rule; sensitivity only).
T3 <- function(f, d, s, rule = "whole_months") {
  dq <- if (rule == "whole_months") duration_cdf_point(d) else d
  Fd <- pmin(pmax(pmarg(f$mD, dq), 1e-9), 1 - 1e-9); Fs <- pmin(pmax(pmarg(f$mS, s), 1e-9), 1 - 1e-9)
  Cp <- VineCopula::BiCopCDF(Fd, Fs, f$cop); Cb <- copula::pCopula(cbind(Fd, Fs), copula::empCopula(f$U, smoothing = "beta"))
  pc <- sapply(seq_along(d), function(i) mean((if (rule == "whole_months") exceeds_duration(f$ev$D, d[i]) else f$ev$D >= d[i]) & f$ev$S >= s[i]))
  cbind(parametric = f$mu / pmax(1 - Fd - Fs + Cp, 1e-12), bernstein = f$mu / pmax(1 - Fd - Fs + Cb, 1e-12), count = ifelse(pc > 0, f$mu / pc, Inf))
}
