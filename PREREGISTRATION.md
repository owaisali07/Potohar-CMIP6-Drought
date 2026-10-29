# Pre-registration — fixes to the six remaining code issues (v2.2)

Written and committed **before** any of the fixes below was run (git tag `prereg-v2`). The state before the fixes is tagged
`v2-prefix`. After the `prereg-v2` commit, none of the choices below is changed. Any change made after results were seen is
recorded under **Post-hoc changes** at the end, with its reason, and the pre-registered result is still reported.

General rules (binding for all items)
- **Results-blind order.** Items 3 (bias correction) and 4 (model ranking) are judged only on historical calibration criteria (1985–2014). No future projection, return period or exposure result is opened, plotted or summarised until both are frozen (git tag `frozen-bc-rank`). During development of Items 3–4, partial runs stop before the `projections` chunk.
- **No tuning on validation data.** The validation halves of the split-sample tests only report skill; they never select settings.
- **Everything that runs is reported.** Every variant goes into `sensitivity/all_variants.csv` (item, variant, role = primary | sensitivity, metric, value). The primary result is the one pre-registered here, even if a variant looks better.
- **No preferred direction.** If a fix weakens or reverses a headline finding, the text says so plainly.
- **Text from numbers.** No directional or qualitative word in the Results is hand-typed (Item 1).
- **Unchanged.** The handling of the NEX-GDDP-CMIP6 wind discontinuity is unchanged from v2.1: step correction is primary and the exclusion of affected models is a sensitivity. The author's decision on this is still pending, and these fixes do not alter it.
- **Software.** Random seed `ensemble.seed` (20261012) for every resampling. One commit per item.

---

## Item 1 — Direction words generated from the numbers

**Method.** One function, `describe_change()` in `scripts/R/wording.R`, returns the wording for a change from `base` to `new`. Its arguments are:
- `kind`: `relative` (percent change), `pp` (percentage points), `degC`, `index` (standardised index units) or `years`;
- optional evidence: `p` (p-value), `agree` (model sign agreement), and `ci = c(lo, hi)` (CI of the change).

The rules are applied in this order:
1. **`changed little`**: |change| is inside the "no meaningful change" band for its kind.
2. **`uncertain direction`**: evidence is supplied and fails. That is, the CI of the change includes 0, or `agree` < 0.80, or `p` ≥ 0.05 (where `p` is the only evidence).
3. **`increased` / `decreased`**: the sign of the change, when it is outside the band and either the evidence passes or none is supplied. "None supplied" covers deterministic diagnostics such as calibration or validation bias, which have no sampling inference.

Bias magnitudes are compared as |bias|. A smaller |bias| reads "decreased", so the reader is never told that a worse bias "improved".

**Bands** (`config.yaml: wording`). They are fixed in advance, and each is the resolution at which a difference is not substantively interpretable for this study:

| kind | band | justification |
|---|---|---|
| relative | ±5 % | typical observational uncertainty of regional monthly precipitation/ET0 products (four-product spread here > 5 %) |
| pp (frequency) | ±1 %-point | one month in 100; below the sampling resolution of 25–30-year windows (1 month ≈ 0.3 %-pt) × 3 |
| degC | ±0.1 °C | instrument / reanalysis resolution of monthly means |
| index | ±0.1 index units | standard-normal index; 0.1 SD is below the uncertainty of the gamma / log-logistic fits |
| years | ±5 % relative | as relative |

Words such as `significant` (p < 0.05) and `robust` (≥80 % sign agreement and Wilcoxon p < 0.05; Item 5 for maps) are produced only by threshold functions.

**Tests** (`tests/test_wording.R`, testthat). Required cases:
- 102 % → 118 % gives `increased`;
- 21.9 % → 16.9 % gives `decreased`;
- a change inside the band gives `changed little`;
- a CI crossing zero gives `uncertain direction`;
- agreement 0.7 gives `uncertain direction`.

**Number trace.** Every number printed by `12_results_discussion.R` is logged with the expression that produced it to `results_text/Number_Trace.csv`. `scripts/16_check_number_trace.R` extracts every number from `Results_Discussion.docx` and requires each one to be in the log with an identical printed value. **Acceptance:** zero unmatched numbers. Years, figure/table/equation numbers, citation numbers and SSP/index names are excluded by fixed patterns listed in the script.

## Item 2 — One duration rule for all return-period estimators

**Method.** Duration D is a whole number of months. The reference duration d_ref, which is a continuous quantile of the fitted D marginal, is converted **once** to whole months by rounding to the nearest integer: k = round(d_ref). An event exceeds the reference if **D ≥ k**. This rule lives in a single helper, `exceeds_duration(D, d_ref)` in `scripts/R/return_period_helpers.R`.

The parametric and Bernstein copula estimators evaluate the D marginal at the continuity-corrected value **k − 0.5**. For integer D, F_D(k − 0.5) ≈ P(D ≤ k − 1), so P(D ≥ k) = 1 − F_D(k − 0.5). This is the same set of events the counting estimator uses. Rounding to the nearest integer is the rule consistent with this continuity correction, since a continuous quantile d corresponds to the integer k with k − 0.5 ≤ d < k + 0.5.

All three estimators (counting, Bernstein, parametric), the bootstrap and the Fig. 8 grid call the same helpers. Severity S is continuous and unchanged (S ≥ s_ref).

**Test.** For d_ref = 6, the counting rule (D ≥ 6) and the copula rule (D > 5.5) must classify an integer test set identically. The helper must also be the function actually called by `T3()`, which is checked by a test on `T3`'s body.

**Report.** A table of every return period: old (v2.1 rule), new, difference. The old-rule values are recomputed in the same run as a sensitivity row in `all_variants.csv`.

## Item 3 — Bias correction

**Primary (methodology III-E, Eq. 7).** QDM (Cannon et al. 2015, `MBC::QDM`) applied **per calendar month without pooling**, per 0.25° cell, calibration 1985–2014:
- pr, rsds and sfcWind are multiplicative (`ratio = TRUE`); tasmax, tasmin and hurs are additive.
- Wet-day / trace handling for pr: trace = 0.05 mm month⁻¹. Values below the trace are set to the trace level, randomised by MBC, and returned as 0, with jitter.factor = 0.01 for ratio variables.
- `ratio.max = 2` (MBC default), `n.tau = NULL` (all quantiles).
- Future in the blocks 2015–2040, 2041–2070 and 2071–2100.
- After correction, hurs is clipped to 1–100 % and tasmin to ≤ tasmax − 0.1, as in v2.1.

This replaces the v2.1 ±1-month pooled window (DEVIATIONS D13) by the methodology's per-month correction.

**Sensitivity only (not eligible to become primary).**
- (S1) ±1-month pooled window with each month **standardised first**: ratio to the calendar-month climatology (1985–2014, or the calibration half in the split tests) for ratio variables, and anomaly for additive ones. Pooled QDM is applied to the standardised values, and the result is back-transformed with the target month's observed climatology.
- (S2) The v2.1 pooled, unstandardised window, as already run.

**Validation (report only), all 27 GCMs, regional area-weighted series.**
- Plain split as in the methodology: calibrate 1985–1999, evaluate 2000–2014, and the reverse.
- Per calendar month median bias: % for ratio variables, °C or %-points otherwise. Raw and corrected, both methods, both directions. October is shown explicitly.
- The existing detrended split, odd/even and pseudo-reality tests are re-run with the primary method (Table S1).

**Acceptance criteria (fixed now; evaluated on calibration 1985–1999 → validation 2000–2014, ensemble mean over the 27 GCMs):**
- (A) For every variable, the mean over months of |median monthly bias| after correction is lower than raw.
- (B) For pr, no calendar month has |median bias| > 25 %.

If the primary fails A or B, it is **kept** and the failure is reported and discussed. No switch to S1 or S2 is allowed.

## Item 4 — Model ranking stability

**Metrics.** These are unchanged from v2.1 (16 criteria): KGE, pattern correlation, nRMSD and station-annual-cycle KGE for pr, tasmax, tasmin and PM ET0, 1985–2014. The references are CHIRPS for pr, ERA5-Land for Tmax, Tmin and ET0, and the accepted stations. The KGE < 0 skill screen (D17) is unchanged.

**Normalisation.** For criterion j and model i, d_ij = (x_ij − best_j)/(worst_j − best_j), which lies in [0, 1] with 0 best. Models that failed the skill screen are excluded from best/worst.

**Criterion weights — entropy weight method.** The benefit scores are b_ij = 1 − d_ij.
- p_ij = (b_ij + 10⁻⁶) / Σ_i (b_ij + 10⁻⁶)
- e_j = −(1/ln n) Σ_i p_ij ln p_ij
- w_j = (1 − e_j) / Σ_j (1 − e_j)

The distance is L_i = √(Σ_j w_j d_ij² / Σ_j w_j), i.e. compromise programming with p = 2. Equal weights and CRITIC weights are reported as sensitivities.

**Stability.** A moving-block bootstrap over the years 1985–2014: block length 5, 6 blocks per replicate (start years drawn uniformly from 1985–2010), B = 1,000. The **same** resampled years are used for observations, stations and all models in a replicate. In each replicate the climatologies, all 16 metrics, the normalisation, the entropy weights and the ranks are recomputed. For each model the report gives:
- the mean rank,
- the 90 % rank interval (5th–95th percentile),
- P(top 10).

**Selection rule (fixed).** The 10 models with the highest P(top 10), ties broken by the lower mean rank. Ensemble weights are ∝ 1/L (full-sample, entropy-weighted) and renormalised over the selected models.

**Freeze.** The selection is written to `06_gcm_eval/selection_frozen.csv` and committed with the tag `frozen-bc-rank`, together with the frozen Item 3 code. Only then are projections run.

**Report.**
- The overlap of the new selection with the v2.1 primary set (MIROC6, CNRM-CM6-1, ACCESS-ESM1-5, GFDL-CM4, GISS-E2-1-G, NorESM2-LM, INM-CM4-8, NorESM2-MM, GFDL-ESM4, TaiESM1) and with the v2 set.
- Key results under **old 10** (the v2.1 primary set), **new 10** and **all 27**, plus the v2 TerraClimate-referenced set already in Table S6.

## Item 5 — FDR on projection maps

**Maps.**
- For each scenario × period map of the change in drought frequency (SPEI-3 ≤ −1; the only projection index mapped), the per-cell Wilcoxon signed-rank p-values over the selected GCMs are adjusted with Benjamini–Hochberg (α = 0.05) across the cells of that map.
- A cell is marked (hatched) only if **p_BH < 0.05 and sign agreement ≥ 80 %**.
- Report the share of cells meeting the criterion before and after FDR.
- If no cell survives, the text says so and relies on the district means.

**Other uses of this rule.**
- The binary exposure measure (Table S3) uses the FDR-based cell mask.
- District robustness (Table S4) applies BH across the five units for each scenario × period.
- Regional (single-test) robustness is unchanged.

## Item 6 — Minor items

**Paths.** No absolute path outside `config.yaml`. `scripts/17_check_paths.R` scans `*.R`, `*.Rmd`, `*.py` and `*.ps1` (excluding `archive/`) for drive-letter paths with the regular expression `(^|[^A-Za-z0-9])[A-Za-z]:[\\/]`. **Acceptance:** zero hits.

**Warnings.** All `suppressWarnings()` calls and `warning = FALSE` options are removed. Warnings are captured by a calling handler that writes them to `logs/warnings.log` (time, chunk, message). Each distinct warning class is fixed or explained in `logs/WARNINGS_EXPLAINED.md`.

**DEVIATIONS.md** is generated by `scripts/15_render_deviations.R` from `DEVIATIONS.template.md`. Every current-state number is a placeholder evaluated against `results_text/key_numbers.rds`. Historical values of superseded versions (v1/v2, labelled as such) may stay literal. **Acceptance:** the template contains no literal current-state number in the "New" column of v2.1/v2.2 rows.

## Rebuild acceptance

The rebuild must:
- start from a fresh R library restored from `renv.lock` (and pandoc from `environment.lock.yml`) with an empty `cache_R/`;
- pass all unit tests, the path check (0 hits) and the Number_Trace check (0 unmatched).

The Python download and preprocessing steps are not re-executed, because their outputs are inputs to the R pipeline; this is stated in the report.

## Independent verification

A separate agent that has not seen the fix history or earlier scores receives only the methodology, this file and `analysis/`. It recomputes the changed numbers and re-scores with the original 100-point rubric. Its score is the one reported.

---

## Post-hoc changes

(none at the time of pre-registration)

1. **Item 1, clarification during implementation (2026-10-15, before any v2.2 result was computed).** The pre-registration did not say how the bands apply to **trends**, which are Sen slopes per decade. The rule adopted is: the change over the record (slope × record length in decades, 4.4 for 1981–2024 and 4.0 for 1985–2024) is classified with `describe_change()` against the record mean. The kind is relative for P, ET0 and P − ET0, degC for temperature and index for SPI/SPEI. The trend p-value (p_BH for districts) is the evidence.
   *Reason:* a per-decade slope compared with an absolute band has no interpretable meaning, whereas the change over the record is the quantity the band was defined for.
   *Disclosure:* the observed trend values are not affected by Items 2–6 and were already known from v2.1.

2. **Item 1, comparison helpers (same date).** The comparative phrases `compare_word()` (higher / lower / similar, same bands) and `range_word()` (below / within / above a published range) were added, together with unit tests. Qualitative judgements without a pre-set threshold ("weak", "almost entirely", "rapid", "dominated") were removed from the text rather than given new thresholds. The one exception is "model uncertainty was the largest source", which is an argmax of the three Hawkins–Sutton fractions.

3. **Item 3, reading of the acceptance criteria (2026-10-15, written before any Item 3 validation number was computed).** "Ensemble mean over the 27 GCMs" of a median monthly bias can be read in two ways: (i) the mean over GCMs of each GCM's |bias|, or (ii) |the mean over GCMs of the signed bias|. Reading (ii) lets opposite biases of different models cancel. **Reading (i) is the binding one for A and B**, because it is the stricter one. Reading (ii) is also computed and reported, but it does not decide the outcome. Further details:
   - Biases are computed per GCM on the regional area-weighted series. The series is formed **after** cell-level correction, exactly as in production.
   - Ratio variables are in %, relative to the observed validation median (denominator floored at 0.1 mm or 0.1 unit). Additive variables are in their own units.
   - Under S1 (the standardised pooled variant), the pr trace of 0.05 applies to the standardised (ratio-to-climatology) values.
   - Implementation: per-cell QDM functions `qdm_cell(method = "permonth" | "pooled" | "pooled_std")`, shared by production, validation and the diagnostics.
   - The S1, S2 and TerraClimate-target runs are made for all 27 GCMs, so that they do not depend on the Item 4 selection.
   *Reason:* the pre-registered text left the order of the absolute value and the ensemble mean open.

4. **Implementation details not fixed in advance (2026-10-15; recorded here for completeness).**
   - **Item 3, before any Item 3 result.** The QDM runs use the sorted model list and a seed per model (`SEED` + position in the sorted list), so that a model's jitter does not depend on the Item 4 selection.
   - **Item 4, before the bootstrap was run.**
     - The KGE < 0 skill screen is re-applied in every replicate.
     - Entropy weights are computed over all models, including any screened model, whose distances are capped at 1.
     - The equal-weight L₂ of v2.1 is reported alongside.
   - **Item 6.** `01a_watch_and_download.ps1`, a one-off download watcher, was moved to `archive/` and is not part of the pipeline. Parallel copula workers write to the same warning log, so a log line can occasionally hold two messages. The explanation patterns are therefore not anchored, and the count only includes non-empty lines. (Superseded after the first clean rebuild: concurrent appends tore two messages, so each worker now writes its own file, merged at export.)

5. **Changes after the first full v2.2 render, which came after the `frozen-bc-rank` tag, so projection results had been computed (2026-10-15).** None of these changes alters any computed number.
   - **Results-text script.** `gword()` crashed on relative changes because the base was missing. It now passes base = 1; for a percentage change the base cancels.
   - **Unlogged literals.** Five literal numbers in the text (SPEI scales, the 25-year label, the 95 % CI level, the number of units) were not logged. They are now logged.
   - **Number-trace checker.** GCM identifiers such as INM-CM4-8 were read as numbers. The checker now removes the known model names before extracting numbers, and treats 1900–1949 as years (SPEIbase starts in 1901).
   - *Disclosure:* the checker was changed after its first run had flagged 6 unmatched numbers. The false positives were names and a year. Every genuine unlogged number was fixed in the text script, not by changing the checker.
   - **Item 2 commit.** A broken string in the Table 5 note made the Rmd fail to parse. It was found and fixed while Item 3 was being implemented.

6. **Rebuild environment (2026-10-15).**
   - **Lockfile.** `renv.lock` gained `testthat` and its 11 dependencies, at the installed versions. No other package version changed.
   - **No compiler.** This machine has no Rtools, so the 6 locked versions that CRAN has since replaced cannot be built from source. The restore therefore uses dated Posit Package Manager snapshots, which provide Windows binaries of those versions (2026-10-01 first, then 2026-10-13, then CRAN).
   - **Version check.** All 192 locked versions were confirmed in the restored library, or in R's own library for the recommended packages.
   - **Pandoc.** Pandoc comes from the existing conda environment and was not re-created.

7. **v3 data update (2026-10-23): PMD stations and WAPDA gauges.** New station inputs change the inputs of the Item 4 rule, not the rule. The rule was rerun and the selection frozen again before any v3 projection was computed (`logs/selection_freeze_v3.txt`, SHA-256 of `06_gcm_eval/selection_frozen.csv`). The v2.2 selection is kept as `06_gcm_eval/selection_frozen_v22.csv` and reported as a sensitivity set (Table S6).

8. **v3.1 code fixes (2026-10-23), after the v3 projection results had been computed and seen.** A code audit found defects in how station data enter the Item 4 criteria and in the return-period margins. These are corrections of errors, not choices among alternatives, and they were decided from the audit findings without reference to the projection results:
   - **Item 4 station KGE.** (a) Stations in the same 0.25° cell are averaged into one cell value (Chaklala and Islamabad (PMD) were counted twice). (b) Stations more than 500 m above or below their cell mean elevation are not compared with grid values (Murree, +754 m). (c) Homogeneity is tested relative to two independent references (CHIRPS/ERA5-Land and TerraClimate); a series flagged by both tests against both references is not used. A first version with one reference flagged breaks in 1997–98 at several stations 100 km apart, a sign of a reference artefact, so confirmation against a second reference was added before any v3.1 result was computed. (d) Station ET0 is used only where ≥ 70% of months have observed humidity and wind.
   - **Item 2 margins.** The duration D, a whole number of months, gets discrete margins (shifted geometric, Poisson, negative binomial). The severity S (≥ 1 by construction) is modelled as S − 1, semiparametrically (empirical body, generalized Pareto tail above the 90th percentile) for the pooled sets of ≥ 100 events, where every parametric family was rejected. Pseudo-observations use mid-ranks instead of random tie-breaking.
   - **Consequence for Item 4.** The corrected criteria were evaluated with the same rule, and the resulting selection was frozen again before the v3.1 projections were run (`logs/selection_freeze_v3_1.txt`). *Disclosure:* this re-freeze is not results-blind in the sense of the general rule, because the v3 projections had been seen. Both earlier selections (v2.2 and v3) are therefore reported as sensitivity sets in Table S6, so that a reader can see whether the selection change matters.
   - **Item 3.** Unchanged. The primary QDM is kept, as pre-registered; its effect on the drought-frequency signal is now reported.
   - **Item 1.** The number-trace check now matches signs. Key numbers are no longer rounded before printing.
