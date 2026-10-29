# Unit tests for scripts/R/qdm_helpers.R (v2.2 Item 3). Run from analysis/: Rscript -e "testthat::test_dir('tests')"
library(testthat)
source(file.path("..", "scripts", "R", "qdm_helpers.R"))

mk <- function(n_yr, f, seed) { set.seed(seed); m <- rep(1:12, n_yr); list(m = m, x = f(m)) }

test_that("primary (per calendar month) uses only the target month", {
  o <- mk(30, function(m) rgamma(length(m), 2, 2 / (10 + 5 * m)), 1); h <- mk(30, function(m) rgamma(length(m), 2, 2 / (8 + 5 * m)), 2)
  x <- h$x; set.seed(3); a <- qdm_cell(o$x, o$m, h$x, h$m, x, h$m, TRUE, "permonth")
  o2 <- o$x; o2[o$m == 2] <- o2[o$m == 2] * 50                      # change February only
  set.seed(3); b <- qdm_cell(o2, o$m, h$x, h$m, x, h$m, TRUE, "permonth")
  expect_equal(a[h$m != 2], b[h$m != 2])                            # other months unaffected
  expect_false(isTRUE(all.equal(a[h$m == 2], b[h$m == 2])))
  set.seed(3); p <- qdm_cell(o2, o$m, h$x, h$m, x, h$m, TRUE, "pooled")
  expect_false(isTRUE(all.equal(a[h$m == 1], p[h$m == 1])))         # pooled window: January sees February
})

test_that("calibration-period correction reproduces the observed monthly medians (additive and multiplicative)", {
  o <- mk(30, function(m) 20 + 3 * m + rnorm(length(m)), 4); h <- mk(30, function(m) 17 + 3 * m + 2 * rnorm(length(m)), 5)
  for (meth in QDM_METHODS) { c1 <- qdm_cell(o$x, o$m, h$x, h$m, h$x, h$m, FALSE, meth)
    expect_lt(max(abs(tapply(c1, h$m, median) - tapply(o$x, o$m, median))), 0.5) }
  o <- mk(30, function(m) rgamma(length(m), 3, 3 / (20 + 10 * m)), 6); h <- mk(30, function(m) rgamma(length(m), 3, 3 / (30 + 10 * m)), 7)
  set.seed(8); c2 <- qdm_cell(o$x, o$m, h$x, h$m, h$x, h$m, TRUE, "permonth")
  expect_lt(max(abs(tapply(c2, h$m, median) / tapply(o$x, o$m, median) - 1)), 0.1)
})

test_that("QDM preserves the model's relative change per month (multiplicative)", {
  o <- mk(30, function(m) rgamma(length(m), 3, 3 / 50), 9); h <- mk(30, function(m) rgamma(length(m), 3, 3 / 40), 10)
  fut <- h$x * 1.2; set.seed(11); cf <- qdm_cell(o$x, o$m, h$x, h$m, fut, h$m, TRUE, "permonth")
  set.seed(11); ch <- qdm_cell(o$x, o$m, h$x, h$m, h$x, h$m, TRUE, "permonth")
  expect_equal(median(cf / pmax(ch, 1e-6)), 1.2, tolerance = 0.02)
})

test_that("standardised pooled window (S1) back-transforms with the target month's observed climatology", {
  o <- mk(30, function(m) 10 * m + rnorm(length(m)), 12); h <- mk(30, function(m) 5 * m + rnorm(length(m)), 13)
  c1 <- qdm_cell(o$x, o$m, h$x, h$m, h$x, h$m, FALSE, "pooled_std")
  expect_lt(max(abs(tapply(c1, h$m, mean) - 10 * (1:12))), 0.6)
  c2 <- qdm_cell(o$x, o$m, h$x, h$m, h$x, h$m, FALSE, "pooled")      # unstandardised pooling smears the seasonal cycle
  expect_gt(max(abs(tapply(c2, h$m, mean) - 10 * (1:12))), max(abs(tapply(c1, h$m, mean) - 10 * (1:12))))
})
