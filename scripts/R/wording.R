# v2.2 Item 1 (PREREGISTRATION.md): every directional / qualitative word in the Results is generated here from the numbers.
# Bands come from config.yaml (wording:). No caller may hand-type "increased", "reduced", "unchanged", "robust", "significant".
wording_cfg <- function() {
  w <- tryCatch(yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))$wording, error = function(e) NULL)
  if (is.null(w)) w <- list(band_relative_pct = 5, band_pp = 1, band_degC = 0.1, band_index = 0.1, band_years_relative_pct = 5, agree_min = 0.8, alpha = 0.05)
  w
}
WCFG <- wording_cfg()

# change and band for a kind
.change <- function(base, new, kind) {
  switch(kind,
         relative = list(d = 100 * (new / base - 1), band = WCFG$band_relative_pct),
         years    = list(d = 100 * (new / base - 1), band = WCFG$band_years_relative_pct),
         pp       = list(d = new - base, band = WCFG$band_pp),
         degC     = list(d = new - base, band = WCFG$band_degC),
         index    = list(d = new - base, band = WCFG$band_index),
         stop("unknown kind: ", kind))
}

#' Classify a change. Returns one of "increased", "decreased", "changed little", "uncertain direction".
#' base/new: values; kind: relative | pp | degC | index | years; p: p-value of the change; agree: sign agreement (0-1);
#' ci: c(lo, hi) of the change (same units as new - base, or relative % for kind relative/years).
describe_change <- function(base, new, kind = "relative", p = NA_real_, agree = NA_real_, ci = NULL) {
  stopifnot(length(base) == 1, length(new) == 1, is.finite(base), is.finite(new))
  ch <- .change(base, new, kind)
  if (abs(ch$d) <= ch$band) return("changed little")
  evidence <- !is.na(p) || !is.na(agree) || !is.null(ci)
  if (evidence) {
    fails <- (!is.null(ci) && ci[1] <= 0 && ci[2] >= 0) || (!is.na(agree) && agree < WCFG$agree_min) || (!is.na(p) && p >= WCFG$alpha)
    if (fails) return("uncertain direction")
  }
  if (ch$d > 0) "increased" else "decreased"
}

#' Same rule for an already-computed change d (e.g. an ensemble-mean change) around zero.
describe_delta <- function(d, kind = "pp", p = NA_real_, agree = NA_real_, ci = NULL, base = NULL) {
  if (kind %in% c("relative", "years")) { stopifnot(!is.null(base)); return(describe_change(base, base * (1 + d / 100), kind, p, agree, ci)) }
  describe_change(0, d, kind, p, agree, ci)
}

#' Bias magnitude comparison: |bias| before vs after ("decreased" = smaller error)
describe_bias <- function(before, after, kind = "relative") describe_change(abs(before), abs(after), if (kind == "relative") "relative" else kind)

sig_word <- function(p) if (is.na(p)) "not tested" else if (p < WCFG$alpha) "significant" else "not significant"
robust_word <- function(flag) if (isTRUE(flag)) "robust" else "not robust"
#' "an increase" / "a decrease" / "little change" / "a change of uncertain direction" for use as a noun phrase
change_noun <- function(word) switch(word, increased = "an increase", decreased = "a decrease", "changed little" = "little change",
                                     "uncertain direction" = "a change of uncertain direction")

#' Comparison of a with b using the same bands: "higher than" / "lower than" / "similar to"
compare_word <- function(a, b, kind = "relative") switch(describe_change(b, a, kind), increased = "higher than", decreased = "lower than", "similar to")
#' Position of x relative to a published range [lo, hi]: "below" / "within" / "above"
range_word <- function(x, lo, hi) if (x < lo) "below" else if (x > hi) "above" else "within"
#' Verb forms of a describe_* result for trends and changes
verb <- function(word, up = "increased", down = "decreased", little = "changed little", unc = "changed in an uncertain direction")
  switch(word, increased = up, decreased = down, "changed little" = little, "uncertain direction" = unc)
