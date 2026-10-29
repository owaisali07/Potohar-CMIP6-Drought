# Unit tests for the v3/v3.1 code: PMD and WAPDA parsers (scripts/R/pmd_wapda_helpers.R), propagation (scripts/R/propagation_helpers.R),
# discrete duration margins (scripts/R/return_period_helpers.R) and the per-cell station KGE (scripts/R/ranking_helpers.R).
# Run from analysis/: Rscript -e "testthat::test_dir('tests')"
library(testthat)
suppressMessages(library(data.table))
source(file.path("..", "scripts", "R", "pmd_wapda_helpers.R"))
source(file.path("..", "scripts", "R", "propagation_helpers.R"))
source(file.path("..", "scripts", "R", "return_period_helpers.R"))

test_that("PMD parser: month names, missing code, trace, gross errors and Tmax < Tmin", {
  f <- tempfile(fileext = ".txt")
  writeLines(c("2001\t1\t1\t0.01\t15.0\t2.0", "2001\t1\t2\t-99.9\t-99.9\t-99.9", "2001\tjan\t3\t12.5\t231.7\t3.0", "2001\t1\t4\t5\t4.0\t6.0\t\t\t"), f)
  r <- read_pmd(f, "Test")
  expect_equal(r$data$date, as.IDate(c("2001-01-01", "2001-01-02", "2001-01-03", "2001-01-04")))
  expect_equal(r$data$prcp, c(0, NA, 12.5, 5))                    # trace -> 0, -99.9 -> NA
  expect_true(is.na(r$data$tmax[3]))                               # 231.7 degC outside the gross-error limit
  expect_true(is.na(r$data$tmax[4]) && is.na(r$data$tmin[4]))      # Tmax < Tmin: both removed
  expect_equal(r$log[check == "trace (0.01 mm) set to 0", n], 1L)
})

test_that("PMD parser re-dates a leap year whose labels skip 29 Feb and repeat 31 Dec", {
  d <- seq(as.Date("2004-01-01"), as.Date("2004-12-31"), by = 1)
  lab <- d[d != as.Date("2004-02-29")]; lab <- c(lab, as.Date("2004-12-31"))          # 366 rows, labels shifted after 28 Feb
  f <- tempfile(fileext = ".txt")
  writeLines(sprintf("%s\t%d\t%d\t%d\t20\t10", format(lab, "%Y"), as.integer(format(lab, "%m")), as.integer(format(lab, "%d")), seq_along(lab)), f)
  r <- read_pmd(f, "Test")
  expect_equal(nrow(r$data), 366L); expect_false(anyDuplicated(r$data$date) > 0)
  expect_equal(r$data[date == as.IDate("2004-02-29"), prcp], 60)                     # row 60 is 29 Feb when rows are consecutive
  expect_equal(r$data[date == as.IDate("2004-12-31"), prcp], 366)
})

wapda_block <- function(yr, ten_day_means = TRUE, blank_day1 = FALSE) {
  hdr <- c("DAY", month.name); rows <- list(c("Test gauge", rep(NA, 12)), c(sprintf("(Year %d)", yr), rep(NA, 12)), c(NA, rep(NA, 11), "m3/sec"), hdr)
  for (dd in 1:31) { rows[[length(rows) + 1]] <- c(if (dd == 1 && blank_day1) NA else as.character(dd), as.character(dd + 100 * (1:12)))
    if (ten_day_means && dd %in% c(10, 20)) rows[[length(rows) + 1]] <- c("Mean", rep("999", 12)) }
  if (ten_day_means) rows[[length(rows) + 1]] <- c("Mean", rep("999", 12))
  rows <- c(rows, list(c("Month Mean", rep("999", 12)), c("year :Mean", rep(NA, 12)), c("Source: SWHP, WAPDA", rep(NA, 12))))
  as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
}

test_that("WAPDA parser: 10-day Mean rows are dropped and month lengths respect leap years", {
  d <- rbind(wapda_block(2003), wapda_block(2004, ten_day_means = FALSE, blank_day1 = TRUE))
  w <- parse_wapda_sheet(d, "Test")
  expect_equal(nrow(w), 365L + 366L)
  expect_equal(w[date == as.IDate("2003-01-11"), q_m3s], 111)       # day 11 of January after the first 10-day Mean row
  expect_equal(w[date == as.IDate("2004-02-29"), q_m3s], 229)       # leap day kept in 2004
  expect_equal(nrow(w[date == as.IDate("2004-01-01")]), 1L)          # blank day label accepted by position
  expect_false(any(w$q_m3s == 999))
})

test_that("propagation pairs SPEI at month t with SRI at t + lag and recovers a known lag", {
  set.seed(3); n <- 240; yr <- rep(1981:2000, each = 12); mo <- rep(1:12, 20)
  sp <- rnorm(n); sri <- c(rep(NA, 2), sp[1:(n - 2)]) + rnorm(n, 0, 0.2)   # SRI follows SPEI-1 two months later
  spei <- list(g = setNames(lapply(1:3, function(k) matrix(if (k == 1) sp else rnorm(n))), paste0("SPEI", 1:3)))
  P <- prop_tab(yr * 12L + mo, list(g = sri), spei, yr, mo, ks = 1:3, lags = 0:4)
  b <- prop_best(P, "g")
  expect_equal(b$best_k, 1L); expect_equal(b$best_lag, 2L); expect_gt(b$r, 0.9)
  P2 <- prop_tab(yr * 12L + mo, list(g = sri), spei, yr, mo, ks = 1, lags = 2, to = 1990)
  expect_equal(P2$n_g, 118L)                                               # 1981-1990 SRI months minus the 2 leading NA
})

test_that("discrete duration margins: P(D >= k) at the continuity point k - 0.5 and integer quantiles", {
  m <- list(dist = "geom1", est = c(prob = 0.4))
  expect_equal(1 - pmarg(m, 3 - 0.5), (1 - 0.4)^2)                       # P(D >= 3) = P(D - 1 >= 2) for a shifted geometric
  expect_equal(pmarg(m, 1 - 0.5), 0)
  q <- qmarg(m, c(0.1, 0.5, 0.9)); expect_true(all(q == round(q)) && all(q >= 1))
  mp <- list(dist = "pois1", est = c(lambda = 1.5)); expect_equal(pmarg(mp, 2.5), ppois(1, 1.5))
})

test_that("semiparametric severity margin: empirical body, GPD tail, consistent quantiles", {
  set.seed(7); S <- 1 + rgamma(400, 1.3, 0.6)
  m <- list(dist = "egpd", est = fit_egpd(S))
  expect_equal(pmarg(m, 1), 0)
  p <- c(0.05, 0.5, 0.89, 0.95, 0.99); expect_equal(pmarg(m, qmarg(m, p)), p, tolerance = 1e-6)    # quantile = inverse CDF, body and tail
  expect_true(all(diff(pmarg(m, seq(1, 15, 0.1))) >= 0))                                          # monotone
  expect_equal(pmarg(m, 1 + m$est$u), m$est$pu, tolerance = 1e-12)                                 # continuous at the threshold
  expect_lt(abs(mean(S <= quantile(S, 0.5)) - pmarg(m, quantile(S, 0.5))), 0.01)
})

test_that("severity margins with a known lower bound of 1 (S - 1)", {
  m <- list(dist = "lnorm.loc1", est = c(meanlog = 0.5, sdlog = 0.8))
  expect_equal(pmarg(m, 1), 0); expect_equal(pmarg(m, 3), plnorm(2, 0.5, 0.8))
  expect_equal(qmarg(m, 0.5), qlnorm(0.5, 0.5, 0.8) + 1)
  expect_equal(pmarg(m, qmarg(m, c(0.1, 0.9))), c(0.1, 0.9))
  expect_false(shifted(m)); expect_true(loc1(m)); expect_equal(base_dist(m), "lnorm")
})

test_that("mid-rank pseudo-observations do not depend on row order", {
  X <- cbind(D = c(1, 1, 2, 3, 3, 3, 5), S = c(1.2, 0.9, 2.5, 3.1, 4.0, 3.3, 7.7)); o <- c(7, 3, 1, 5, 2, 6, 4)
  U1 <- VineCopula::pobs(X, ties.method = "average"); U2 <- VineCopula::pobs(X[o, ], ties.method = "average")
  expect_equal(U1[o, ], U2, ignore_attr = TRUE)
})

test_that("station KGE counts stations sharing a 0.25 deg cell once", {
  source(file.path("..", "scripts", "R", "ranking_helpers.R"), local = TRUE)
  simv <- cbind(c1 = 1:12 + 0, c2 = (1:12) * 2)
  clim <- list(a = 1:12 + 0.5, b = 1:12 - 0.5, c = (1:12) * 2.2)
  k_cell <- station_kge(simv, function(st) clim[[st]], c("a", "b", "c"), c(a = 1L, b = 1L, c = 2L))
  expect_equal(k_cell, mean(c(kge(simv[, 1], (clim$a + clim$b) / 2)[["KGE"]], kge(simv[, 2], clim$c)[["KGE"]])))
  expect_true(is.na(station_kge(simv, function(st) clim[[st]], character(), c(a = 1L))))
})
