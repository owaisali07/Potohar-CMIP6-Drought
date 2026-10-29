# Paper 6 — Future Droughts in the Potohar Plateau under CMIP6 Scenarios: analysis pipeline

The pipeline implements `../Paper6_Methodology_IEEE.docx` (Sections II–IV, Eq. 1–8). Every departure from it is listed in `DEVIATIONS.md`.

## Layout
```
analysis/
  config.yaml                     single configuration (paths, periods, thresholds, model list)
  environment.yml                 Python environment (conda, "p6drought"); R 4.6.1 from CRAN + scripts/install_r_packages.R
  Potohar_Drought_Analysis.Rmd    ONE R Markdown file with ALL statistical analysis, tables and maps (R)
  Potohar_Drought_Analysis.html   rendered report
  scripts/                        Python data acquisition + daily->monthly preprocessing (numbered, re-runnable)
  00_inventory/ … 11_validation_uncertainty/   intermediate NetCDF/CSV (CF metadata)
  figures/  (Fig01–Fig10 + FigS1; 600-dpi PNG + PDF, IEEE column widths, colour-blind-safe palettes)
  tables/   (Table1–Table7; CSV + IEEE-style DOCX)
  results_text/Results_Discussion.docx, key_numbers.json
  logs/progress.md, DEVIATIONS.md
```

## Version 3.1 (2026-10-23): code-audit fixes
- Station data in model and product evaluation: one value per 0.25° cell, a ±500 m station–cell elevation limit (`indices.station_dz_max`), relative SNHT/Pettitt tests against CHIRPS/ERA5-Land with suspect series excluded, and station ET0 only where humidity and wind were observed.
- Propagation pairs each gauge with its own catchment SPEI (Dhok Pathan basin, Chirah catchment); the unlocated Sil gauge is used for SRI/SDI only.
- Copula return periods: discrete margins for the duration, mid-rank pseudo-observations (deterministic).
- Exposure: per-model changes, model range and bootstrap CI (Table S8). Effect of QDM on the drought-frequency signal reported.
- Key numbers kept at full precision; sign-sensitive number trace; new unit tests (`tests/test_pmd_wapda.R`).
- Rebuild: `scripts/22_rebuild_v3.R` (see DEVIATIONS D25 for the library on a machine with Smart App Control). Details: `DEVIATIONS.md` (C1–C9), `PREREGISTRATION.md` (post-hoc 7–8), `CHANGES_v3.md`.

## Version 3 (2026-10-23): PMD stations and WAPDA gauges
PMD daily records for Islamabad and Murree (P, Tmax, Tmin, 1961–2010) and WAPDA/SWHP daily discharge for the Soan at Dhok Pathan (1964–2003), the Soan at Chirah and the Sil River near Chahan (1962–2003) were supplied by the author in `../Real dataset/`. `Rscript scripts/05_read_pmd_wapda.R` parses and checks them into `data/pmd/` and `data/wapda/` (needs `readxl`, which is not in `renv.lock` because the Rmd does not use it). The Rmd merges PMD into the station network and uses the gauges as the primary hydrological input; GloFAS-ERA5 is validated against them (Table S7) and extends SRI/SDI to 2024. Deviations: `DEVIATIONS.md` v3 (D4, D22–D24); before/after numbers: `CHANGES_v3.md` (`scripts/21_changes_v3.R`, compares with git tag `v2.2-pre-realdata`). `CHANGES_v2.md` is frozen.

## Version 2 (2026-10-13)
v2 applies the audit and fix list. See `CHANGES_v2.md` for Issue | Action | Old | New | Status, and `DEVIATIONS.md` (section "v2") for old value, new value and reason. **Python is used only to download data**. All statistics, tables and maps are in the Rmd, and the two Word documents are built with R (`officer`).

v2 download scripts (run after the v1 steps below):

| Script | Purpose |
|---|---|
| `01h_glofas_ewds.py` | GloFAS-ERA5 v4.0 consolidated, 1979–2024, from CEMS EWDS (needs `~/.cdsapirc`) |
| `01i_gee_downloads.py era5land speibase` | ERA5-Land MONTHLY_AGGR/HOURLY/DAILY_AGGR PM inputs (0.25° and 0.05°) and SPEIbase v2.10 via Google Earth Engine (project `eighth-effect-409505`) |
| `01j_download_yields.py` | PBS, BoS Punjab and PDS 2024 district crop statistics (PDF/CSV) |
| `01k_download_stations.py` | All GSOD/ISD and GHCN-D stations within 100 km, plus ERA5-Land/CHIRPS daily point series for gap filling |
| `01l_download_bulletins.py` | NDMC drought bulletins archived on web.archive.org |

v2 R scripts (no Python): `04_digitise_yields.R` → `data/yields/district_wheat.csv`. The Rmd export chunk runs `12_results_discussion.R` (→ `results_text/Results_Discussion.docx`), `13_methodology_redline.R` (→ `Methodology_v2_redline.docx`) and `14_changes_v2.R` (→ `CHANGES_v2.md`). `REQUESTS_v2.md` lists what still needs the author, with draft e-mails.

## Environment and paths (v2.1)
- Python: `conda env create -f environment.yml` (pinned). Exact lock: `environment.lock.yml`, or for a byte-identical rebuild on win-64, `conda-explicit-win64.txt` plus the pip block.
- R 4.6.1: `Rscript scripts/install_r_packages.R`. For exact versions, run `Rscript -e "renv::restore(lockfile = 'renv.lock', prompt = FALSE)"`.
- Every path is in `config.yaml`. All R and Python scripts read it, so run them from `analysis/` or set `P6_CONFIG=<path to config.yaml>`.
- Gridded outputs are written as CF-1.8 NetCDF:
  - `03_et0/et0_monthly_0p25_1981_2024.nc`: PM ET₀ (ERA5-Land and TerraClimate inputs), Hargreaves ET₀ and CHIRPS P.
  - `04_indices_obs/drought_indices_obs_monthly_0p25_1981_2024.nc`: SPI, SPEI and RDIst at 1, 3, 6 and 12 months.
- Superseded v1 files are in `archive/` (see `archive/README.md`) and are not read by the pipeline.
- History: `git log` in `analysis/`. The tag `v1-preaudit` marks the state before the audit fixes; a full byte copy is in `../analysis_v1_preaudit/`.

## Run order
Python steps run with `powershell -File scripts/run_py.ps1 <script> [args]`, which uses the `p6drought` env without activation.

| Step | Script | Purpose |
|---|---|---|
| 0 | `00_inventory.py`, `00b…00e` | Inventory of local CMIP6, value/QC probes, NASA NCCS availability |
| 1a | `01a_download_nexgddp_nccs.py [--exps historical] [--models …]` | NEX-GDDP-CMIP6 hurs/rsds/sfcWind (v2.0) for the Potohar box |
| 1b | `01b_check_nex_versions.py` | v2.0 vs local v1.x equivalence check |
| 1c | `01c_download_obs.py terraclimate cru worldcover dem30 dem90 spam gdhy gwl bulletins` | Open observational/auxiliary data |
| 1d | `01d_boundaries_basin.py` | Districts + ICT, Soan basin delineation (Copernicus DEM), rivers |
| 1e | `01e_download_glofas.py` | GloFAS-ERA5 discharge at Dhok Pathan and Chirah |
| 1f | `01f_modis_pc.py` | MODIS MOD13Q1 NDVI and MOD11A2 LST (Planetary Computer) |
| 1g | `01g_isimip3b.py` | ISIMIP3b second chain (server-side cut-outs) |
| 2a | `02a_stations.py` | GSOD/GHCN-D daily station records + gross-error QC |
| 2b | `02b_nex_monthly.py` | Daily NEX-GDDP -> monthly on the 0.25° grid |
| 2c | `02c_obs_grid.py chirps era5land terraclimate cru fine` | Observations -> monthly 0.25° (and 0.05°) by conservative remapping |
| 2d | `02d_station_gridpoints.py` | CHIRPS/ERA5-Land daily at stations (gap filling) |
| 2e | `02e_landcover_crops.py` | WorldCover fractions, SPAM2010, GDHY |
| 3 | `Rscript -e "rmarkdown::render('Potohar_Drought_Analysis.Rmd')"` | All analysis: QC/homogeneity, ET₀ (Eq. 1), SPI/SPEI/RDI/SRI/SDI/VHI (Eq. 2–4), run theory (Eq. 5), trends, propagation, GCM evaluation (Eq. 6), QDM (Eq. 7), projections, GWL, copulas (Eq. 8), exposure, validation, Hawkins–Sutton, sensitivity |

The R Markdown caches heavy steps in `cache_R/*.rds`. Delete a file to recompute that step, or delete the folder for a clean end-to-end run. Random seeds are fixed (`config.yaml: ensemble.seed`).

## Data sources (all open)
- NEX-GDDP-CMIP6: Paper 3 local copy plus NASA NCCS.
- Station data: PMD daily records for Islamabad and Murree (1961–2010, supplied by the author) merged with NOAA GSOD/ISD and GHCN-Daily (all stations within 100 km).
- Gridded observations: CHIRPS v2.0, ERA5-Land (GEE; primary PM ET₀), TerraClimate (PM sensitivity), CRU TS 4.10, SPEIbase v2.10 (GEE).
- Discharge: WAPDA/SWHP daily gauge records (Dhok Pathan, Chirah, Sil near Chahan; to 2003, supplied by the author); GloFAS-ERA5 v4.0 from CEMS EWDS (1979–2024) as validated extension; Open-Meteo GloFAS (1997+) for cross-checking.
- Yields: PBS, BoS Punjab, PDS 2024 and Crop Reporting Service Punjab district wheat (1985–2026; irrigated/un-irrigated split), CRS district groundnut (2017-18–2025-26), plus GDHY.
- Drought bulletins: NDMC monthly (2020–2024) and quarterly (2012–2019) bulletins, reports and advisories from the Internet Archive.
- Vegetation: MODIS v061 via Microsoft Planetary Computer.
- Land cover and crops: ESA WorldCover 2021, SPAM2010 v2r0, GDHY v1.2+1.3.
- Terrain and boundaries: Copernicus DEM GLO-30/90, OCHA COD-AB (2022).
- Projections metadata: Hauser et al. warming-level tables, ISIMIP3b.

`D:\downscaling\` and the Paper 3 data were only ever read.

## Open issues after v2 (see the Limitations paragraph in Results_Discussion.docx and REQUESTS_v2.md)
1. **PMD daily station data** (v3): received for Islamabad and Murree only, to 2010, without humidity, wind or sunshine (DEVIATIONS D22). Records for Rawalpindi/Chaklala, Jhelum, Chakwal and Attock, and 2011–2024, would strengthen the network.
2. **WAPDA discharge** (v3): gauges end in 2003, so gauge SRI/SDI are calibrated on 1985–2003 and GloFAS-ERA5 is used after 2003. Coordinates of the Sil gauge near Chahan are needed to map it.
3. **Yields**: district groundnut statistics start in 2017-18 and the irrigated/un-irrigated wheat split in 2011-12 (CRS books available online).
4. **NDMC bulletins**: only archived issues exist (monthly 2020–2024, quarterly 2012–2019), and the quarterly Potohar statements are largely boilerplate.
5. **QDM precipitation**: the median and drought-frequency bias of P are not reduced in the out-of-sample tests (see Table S1).
6. **PKU GIMMS NDVI** (1999–2002 VCI) was not added. MODIS VHI covers 2000–2024.
