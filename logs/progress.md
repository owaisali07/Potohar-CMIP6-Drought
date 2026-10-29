# Progress log

## 2026-10-12 — Phase 0 (inventory)
- Read the methodology in full. `D:\downscaling\` turned out to be a CorrDiff project (5 GCMs, pr/tas only) and was not used (D1).
- NEX-GDDP-CMIP6 (pr, tasmax, tasmin) was found in Paper 3. hurs/rsds/sfcWind are missing; 27 GCMs on NASA NCCS have all six variables.
- The author delegated all decisions ("do your best recommendation"); the decisions are recorded as D1–D16 in DEVIATIONS.md.

## 2026-10-12/13 — Data acquisition (Python, scripts 01a–01g)
- NCCS: hurs/rsds/sfcWind for 27 models (historical) and 12 models (scenarios). NCCS had a global outage of about 12 h (20:10–07:50); work resumed afterwards.
- TerraClimate (range reads), CRU TS 4.10, WorldCover, Copernicus DEM, SPAM2010, GDHY, Hauser GWL tables, MODIS (Planetary Computer), GloFAS (Open-Meteo, from 1997 only) and ISIMIP3b (5 GCMs, SSP5-8.5).
- PMD/NDMC bulletins: the server returned HTTP 500; the Internet Archive returned 429. Not obtained.
- SPEIbase (digital.csic.es): TLS refused. Replaced by the SPEIbase algorithm on CRU TS 4.10 (D12).

## Step 1 — Study area: done
- Basin areas: Dhok Pathan 6,849 km² (GLO-90), within the 6,475–6,842 km² range (+5.8% vs 6,475); Chirah 352.7 km² vs 355 km². The basin to Makhad is 11,183 km²; this matches the Punjab P&D figure (11,228 km²) but not Wikipedia's 6,842 km².

## Steps 2–5 — Observations, ET0, indices, characteristics: done
- Stations: only Chaklala and Jhelum meet the 80% rule. Regional CHIRPS + TerraClimate-PM is the primary series.
- Selected index (yield correlation): SPEI-3 ending in December (mean r = 0.665, significant in 5/5 units).
- Propagation: k = 1 month at Dhok Pathan (r = 0.53); k = 3 at Chirah.

## Step 6 — GCM evaluation: done
- KIOST-ESM had no skill (P KGE < 0) and was ranked last. Top 10: ACCESS-ESM1-5, TaiESM1, IPSL-CM6A-LR, GFDL-ESM4, NorESM2-LM, GISS-E2-1-G, EC-Earth3, CMCC-ESM2, MPI-ESM1-2-LR, UKESM1-0-LL.

## Step 7 — QDM: done
- Large residual biases in NEX wind (+186%), Rs (+23%) and RH (+19 %-pt) were removed.
- Per-month QDM inflated the P change, so a pooled 3-month window was used (D13).

## Steps 8–11 — Projections, GWL, copulas, exposure, uncertainty, sensitivity: done
- Far-future change in drought frequency: +7.7 %-pt (SSP2-4.5) and +10.6 %-pt (SSP5-8.5), robust. The increase is concentrated in DJF/MAM (Rabi).
- Return periods: the baseline 25-yr event becomes a 7–9-yr event by 2076–2100. The pooled Gumbel copula fails the GoF test; an empirical T_AND is given as a cross-check.
- Model uncertainty dominates (68–75% of the variance).

## 2026-10-13 — Final QA
- Full report rendered (Potohar_Drought_Analysis.html); Results_Discussion.docx generated from key_numbers.json.
- Clean end-to-end re-render from config.yaml (empty cache) run for reproducibility; see the end of this file.

- 2026-10-13 13:53: clean re-render from an empty cache finished; key_numbers.json identical to the previous run (0 differences). Pipeline reproducible from config.yaml (fixed seed 20261012).
