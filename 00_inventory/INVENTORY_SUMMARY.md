# Phase 0 — Data inventory and gap report

Date: 2026-10-12. Scripts: `scripts/00_inventory.py`, `00b_probe_values.py`, `00c_qc_tasmax_tasmin.py`, `00d_obs_probe.py`, `00e_nccs_availability.py`. All source folders were opened read-only.

## 1. `D:\downscaling\` is not NEX-GDDP-CMIP6

`D:\downscaling\` is a CorrDiff (NVIDIA PhysicsNeMo) AI-downscaling project (see `D:\downscaling\outputs\CorrDiff_Complete_Workflow.md`):

| Item | Content |
|---|---|
| Models | 5 raw CMIP6 GCMs: EC-Earth3, GFDL-ESM4, MPI-ESM1-2-HR, MRI-ESM2-0, NorESM2-MM (r1i1p1f1) |
| Variables | `pr` and `tas` (daily mean) **only**; no tasmax, tasmin, hurs, rsds or sfcWind |
| Historical | 1995–2014 (GFDL and NorESM 1990–, MRI 1950–) → **1985–2014 baseline impossible for 3 of 5 models** |
| Future | 2021–2040, 2041–2060, 2081–2100 → **2061–2080 missing** (EC-Earth3, MPI-HR, NorESM-MM); EC-Earth3 tas has gaps for two SSPs |
| Products | raw native grid (~1°), 1° regridded + own QDM, CorrDiff 0.1° output (124 files; pilot region) |
| Units/calendar | raw: kg m⁻² s⁻¹ and K, native calendars; processed: mm/day and °C |

Using it would substitute a dataset, and Table II does not list it as an alternative. It also fails the variable, period and ≥10-model requirements.

## 2. NEX-GDDP-CMIP6 is already on disk (Paper 3)

| Copy | Path | Content |
|---|---|---|
| Per-variable (original NEX names) | `D:\Papers\Paper 3\Paper1_Seasonal_Clock\data\nex-gddp-cmip6\` | 31,410 files, 92 GB |
| Merged per model-year, Pakistan clip | `...\data\nex_gddp_cmip6\` | 8,207 files, 92 GB |
| pr-only copies (v1.0/v1.1/v2.0) | `D:\Papers\Paper 3\Paper2_Monsoon_Regime\data\raw\nex_gddp_cmip6*` | 24,384 files |

- Source: Google Earth Engine `NASA/GDDP-CMIP6`, versions v1.0/v1.1. 0.25°, lon 60.125–78.875 E, lat 23.125–37.875 N, which **covers Potohar with more than 0.5° buffer**.
- Variables: **pr, tas, tasmax, tasmin only**. **hurs, rsds and sfcWind are absent for every model.**
- Units are raw CF: pr in kg m⁻² s⁻¹ (×86 400 → mm d⁻¹) and temperatures in K. The merged files carry no `units` attribute; this is documented only in the global attributes.
- Calendars: every file is labelled `proleptic_gregorian` (GEE re-indexing). Paper 3 (`scripts/fix_nex_calendars.py`) relabelled the 365-day models in leap years. The 360-day models (HadGEM3-GC31-LL/MM, KACE-1-0-G, UKESM1-0-LL) contain 5–6 **repeated days per year** (tagged, not removed). Monthly totals must account for this.

### Physical QC findings (`qc_temperature.csv`)
- **CMCC-CM2-SR5**: mean diurnal range is 5.1 K, against 12.4–14.3 K for every other model. NASA's current (v2.0) archive **no longer offers tasmax/tasmin for this model** (see §3), so the local values are very likely erroneous or superseded.
- **TaiESM1**: in the future runs, `tas` is about 3.1 K above (tasmax+tasmin)/2; in the historical run it is 0 K. This matches the NEX Technical Note 4 issue already documented in Paper 3. It affects `tas` only; tasmax and tasmin look consistent.
- No negative precipitation, and no cases of tasmax < tasmin, except 0.1% for CMCC-CM2-SR5.

## 3. NASA NCCS THREDDS (official source, v2.0): what can be obtained

`nccs_availability.csv`: 35 model folders checked for all six variables × historical/ssp245/ssp585.

**Complete for all 6 variables, historical 1950–2014 and both SSPs 2015–2100: 28 folders = 27 GCMs**
ACCESS-CM2, ACCESS-ESM1-5, CMCC-ESM2, CNRM-CM6-1 (r1i1p1f2), CNRM-ESM2-1 (f2), CanESM5, EC-Earth3, EC-Earth3-Veg-LR, FGOALS-g3 (r3), GFDL-CM4 (+ gr2 duplicate), GFDL-ESM4, GISS-E2-1-G (f2), HadGEM3-GC31-LL (f3, 360-day), INM-CM4-8, INM-CM5-0, IPSL-CM6A-LR, KACE-1-0-G (360-day), KIOST-ESM (*one ssp245 hurs year missing*), MIROC-ES2L (f2), MIROC6, MPI-ESM1-2-HR, MPI-ESM1-2-LR, MRI-ESM2-0, NorESM2-LM, NorESM2-MM, TaiESM1, UKESM1-0-LL (f2, 360-day).

**Cannot produce Penman–Monteith ET₀ (flagged; no silent switch to Hargreaves):**
| Model | Problem |
|---|---|
| BCC-CSM2-MR | no `hurs` (any experiment) |
| NESM3 | no `hurs` (any experiment) |
| CESM2, CESM2-WACCM, IITM-ESM | no `tasmax`/`tasmin` (IITM-ESM also ends in 2099) |
| CMCC-CM2-SR5 | no `tasmax`/`tasmin` in v2.0; local v1.x values fail QC |
| HadGEM3-GC31-MM | no SSP2-4.5 run at all |

The six variables do exist on NCCS for the 27 GCMs. A test subset request (one variable-year, Potohar box 71–74.5 E, 31.75–34.75 N) took about 10 s and returned 235 kB. The server is flaky (timeouts), so retries are needed.
**Version issue:** NCCS now serves **v2.0** only, while the local pr/tasmax/tasmin are v1.0/v1.1.

## 4. Observational datasets (Table I / II) — see `obs_datasets_status.csv`

| Present locally | Partial | Must be downloaded (open) | Needs credentials / request |
|---|---|---|---|
| CHIRPS v2.0 daily 1981–2025; GHCN-D (sparse); OCHA admin-2 (all 5 units); GSOD and HadISD (not in Table II) | ERA5-Land: only t2m/tmax/tmin/precip; **dewpoint, solar radiation and 10 m wind are missing** | CRU TS 4.09, TerraClimate, PKU GIMMS NDVI, GDHY, SPAM2010, ESA WorldCover (AWS), Copernicus DEM GLO-30 (AWS), SPEIbase, PERSIANN-CDR, ESA CCI SM, ISIMIP3b, Mishra SA-CMIP6, Hauser GWL tables | **PMD stations** (request), **WAPDA discharge** (request), **Crop Reporting Service yields** (manual), APHRODITE (e-mail registration), MSWEP (form), GLEAM (registration), MERIT Hydro (registration), **GloFAS-ERA5** (EWDS/CDS account), **MODIS** (GEE or Earthdata), **ERA5-Land PM variables** (GEE or CDS key) |

Stations in the plateau: Chaklala (Rawalpindi/Islamabad) and Jhelum appear in GHCN-D, GSOD and HadISD. Murree, Kakul and Balakot are in GSOD (edge or outside). No PMD data are on disk.
No GEE, CDS/EWDS or Earthdata credentials were found on this machine.

## 5. Software
Anaconda base (Python 3.12) has xarray, dask, scipy, h5py and python-docx. It **lacks** netCDF4, xclim, geopandas, rioxarray, pyet, pymannkendall, climate_indices, cartopy, regionmask and copula libraries. A dedicated conda env (`environment.yml`) will be created in Phase 1. No R installation was found.
