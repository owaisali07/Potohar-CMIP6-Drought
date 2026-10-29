# Unit tests for scripts/R/return_period_helpers.R (v2.2 Item 2). Run from analysis/: Rscript -e "testthat::test_dir('tests')"
library(testthat)
suppressMessages({ library(VineCopula); library(copula) })
source(file.path("..", "scripts", "R", "return_period_helpers.R"))

test_that("one whole-month rule: d_ref = 6 classifies the same events for counting and copula", {
  D <- 1:12
  cnt <- exceeds_duration(D, 6)                                  # counting estimator rule
  cop <- D > duration_cdf_point(6)                                # copula rule: F_D evaluated at k - 0.5
  expect_identical(cnt, cop)
  expect_identical(which(cnt), 6:12)
  expect_equal(ref_duration_k(6.0), 6L); expect_equal(ref_duration_k(6.19), 6L); expect_equal(ref_duration_k(6.6), 7L)
})

test_that("T3 uses the helper for all three estimators", {
  set.seed(1)
  ev <- data.frame(D = sample(1:9, 60, replace = TRUE)); ev$S <- ev$D * runif(60, 0.8, 1.6)
  U <- VineCopula::pobs(cbind(ev$D, ev$S), ties.method = "random")
  f <- list(mD = list(dist = "lnorm", est = c(meanlog = mean(log(ev$D)), sdlog = sd(log(ev$D)))),
            mS = list(dist = "lnorm", est = c(meanlog = mean(log(ev$S)), sdlog = sd(log(ev$S)))),
            cop = BiCop(4, 1.8), U = U, ev = ev, mu = 0.5)
  # any d_ref that rounds to the same k gives identical return periods for all three estimators
  expect_equal(T3(f, 5.6, 6), T3(f, 6.4, 6))
  # counting estimator matches a direct count of events with D >= k and S >= s
  k <- ref_duration_k(6.2); expect_equal(unname(T3(f, 6.2, 6)[, "count"]), 0.5 / mean(ev$D >= k & ev$S >= 6))
  b <- paste(deparse(body(T3)), collapse = " ")
  expect_true(grepl("duration_cdf_point", b)); expect_true(grepl("exceeds_duration", b))
})
