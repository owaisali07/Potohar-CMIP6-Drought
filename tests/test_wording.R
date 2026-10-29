# Unit tests for scripts/R/wording.R (v2.2 Item 1). Run from analysis/: Rscript -e "testthat::test_dir('tests')"
library(testthat)
Sys.setenv(P6_CONFIG = normalizePath(file.path("..", "config.yaml")))   # test against the configured bands
source(file.path("..", "scripts", "R", "wording.R"), chdir = FALSE)

test_that("pre-registered cases", {
  expect_equal(describe_change(102, 118, "relative"), "increased")          # bias 102% -> 118%
  expect_equal(describe_change(21.9, 16.9, "relative"), "decreased")        # 21.9% -> 16.9%
  expect_equal(describe_change(17.5, 17.7, "relative"), "changed little")   # inside +-5% band
  expect_equal(describe_change(0, 3, "pp", ci = c(-1, 7)), "uncertain direction")   # CI crosses zero
  expect_equal(describe_change(0, 3, "pp", agree = 0.7), "uncertain direction")     # agreement < 80%
})

test_that("evidence that passes keeps the direction; p-value rule", {
  expect_equal(describe_change(0, 12.7, "pp", agree = 1, p = 0.002), "increased")
  expect_equal(describe_change(0, -4, "pp", agree = 0.9, p = 0.01), "decreased")
  expect_equal(describe_change(0, 4, "pp", p = 0.2), "uncertain direction")
  expect_equal(describe_change(0, 0.5, "pp", p = 0.001), "changed little")
})

test_that("bands per kind", {
  expect_equal(describe_change(20, 20.05, "degC"), "changed little")
  expect_equal(describe_change(20, 20.5, "degC"), "increased")
  expect_equal(describe_change(0, 0.08, "index"), "changed little")
  expect_equal(describe_change(30, 31, "years"), "changed little")    # +3.3% < 5%
  expect_equal(describe_change(30, 7.6, "years"), "decreased")
})

test_that("bias magnitudes and helpers", {
  expect_equal(describe_bias(-20, 10), "decreased")
  expect_equal(describe_bias(16.9, 21.7), "increased")
  expect_equal(describe_delta(2.5, "pp", agree = 0.9, p = 0.01), "increased")
  expect_equal(describe_delta(10, "relative", base = 800), "increased")
  expect_equal(sig_word(0.01), "significant"); expect_equal(sig_word(0.2), "not significant")
  expect_equal(robust_word(TRUE), "robust"); expect_equal(robust_word(NA), "not robust")
})

test_that("comparison and range helpers", {
  expect_equal(compare_word(1.66, 1, "relative"), "higher than")
  expect_equal(compare_word(0.96, 0.94, "relative"), "similar to")
  expect_equal(compare_word(0.5, 0.7, "relative"), "lower than")
  expect_equal(range_word(64, 70, 75), "below"); expect_equal(range_word(72, 70, 75), "within"); expect_equal(range_word(80, 70, 75), "above")
  expect_equal(verb("decreased", down = "shortened"), "shortened")
})
