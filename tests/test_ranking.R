# Unit tests for scripts/R/ranking_helpers.R (v2.2 Item 4). Run from analysis/: Rscript -e "testthat::test_dir('tests')"
library(testthat)
source(file.path("..", "scripts", "R", "ranking_helpers.R"))

set.seed(1)
fake_eval <- function(n = 8) rbindlist(lapply(paste0("M", 1:n), function(m) rbindlist(lapply(c("pr", "tasmax", "tasmin", "ET0"), function(v)
  data.table(model = m, variable = v, KGE = runif(1, 0.2, 0.9), PCC = runif(1, 0.5, 0.99), nRMSD = runif(1, 0.1, 1), KGE_station = runif(1, 0, 0.9))))))

test_that("criterion weights are non-negative and sum to one; constant criteria get zero weight", {
  M <- matrix(runif(40), 10, 4, dimnames = list(NULL, letters[1:4])); M[, 2] <- 0.3
  for (w in c("entropy", "critic", "equal")) { x <- crit_weights(M, w); expect_equal(sum(x), 1); expect_true(all(x >= 0)) }
  expect_equal(unname(crit_weights(M, "entropy")["b"]), 0, tolerance = 1e-9)
  expect_equal(unname(crit_weights(M, "critic")["b"]), 0)
})

test_that("equal weights reproduce the v2.1 L2 = sqrt(mean d^2)", {
  EV <- fake_eval(); r <- cp_rank(EV, "equal")$rank; cr <- cp_criteria(EV)
  l2 <- cr[, .(L2 = sqrt(mean(d^2))), by = model]
  expect_equal(r[order(model), L], l2[order(model), L2])
})

test_that("a model failing the skill screen ranks last and does not set best/worst", {
  EV <- fake_eval(); EV[model == "M3" & variable == "pr", KGE := -0.5]
  for (w in c("entropy", "critic", "equal")) expect_equal(tail(cp_rank(EV, w)$rank$model, 1), "M3")
  cr <- cp_criteria(EV); expect_true(all(cr[model != "M3", d] >= 0 & cr[model != "M3", d] <= 1))
})

test_that("a model best on every criterion has L = 0 and rank 1", {
  EV <- fake_eval(); EV[model == "M5", `:=`(KGE = 0.99, PCC = 0.999, nRMSD = 0.01, KGE_station = 0.99)]
  r <- cp_rank(EV, "entropy")$rank; expect_equal(r$model[1], "M5"); expect_equal(r$L[1], 0)
})
