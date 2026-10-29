# What still needs you (v2)

Logins are done. Google Earth Engine (project `eighth-effect-409505`) was authorised on this PC, and its token is saved in `%USERPROFILE%\.config\earthengine`. The Copernicus key is in `%USERPROFILE%\.cdsapirc` and works for the CDS and the Early Warning Data Store (GloFAS).
**Recommended:** revoke and regenerate that Copernicus key after the paper is finished, because it was shared in chat. Then update `.cdsapirc`.

The remaining gaps can only be closed by data requests to national agencies. Draft e-mails are below; **please verify each recipient address on the agency's official website before sending** (addresses are not filled in here because they could not be verified from this machine).

| # | Data | Agency | Why it matters | Current substitute |
|---|---|---|---|---|
| 1 | Daily station data 1981–2024 | PMD (Climate Data Processing Centre, Karachi) | Methodology primary station source. Only 3 open-archive stations pass the 70% rule. | NOAA GSOD/ISD + GHCN-Daily |
| 2 | Daily discharge, Soan at Chirah and Dhok Pathan, 1981–2024 | WAPDA, Surface Water Hydrology Project | Gauge-based SRI/SDI and propagation | GloFAS-ERA5 v4.0 (simulated) |
| 3 | *Optional now.* Rainfed/irrigated wheat split for 1985–2010 and district groundnut before 2017-18 | Crop Reporting Service, Agriculture Dept. Punjab | Longer rainfed and groundnut series | **Found online (2026-10-14):** wheat 1985–2026 (incl. 2023-24), irrigated/un-irrigated 2011-12 and 2016-17–2025-26, groundnut 2017-18–2025-26 from agripunjab.punjab.gov.pk (CRS) |
| 4 | Complete archive of drought bulletins, 2000–2024 | PMD, National Drought Monitoring Centre (NDMC), Islamabad | Bulletin validation | Internet Archive: monthly Oct 2020–Dec 2024, quarterly 2012–2019, annual reports 2013–2018, advisories 2024–25. ndmc.pmd.gov.pk still returns HTTP 500 |
| 5 | Optional: MSWEP V2 licence | GloH2O (gloh2o.org) | Rainfall-uncertainty range (Table II) | not used |
| 6 | Optional: APHRODITE registration | aphrodite.precinfo@gmail.com (as stated by APHRODITE) | Station-based gridded rainfall check (to 2015) | CPC/CHIRPS |

---

### Draft 1 — PMD station data
**Subject:** Request for daily climate data, Potohar Plateau stations, 1981–2024 (academic research)

Dear Sir/Madam,

I am conducting academic research on future droughts in the Potohar Plateau (Attock, Chakwal, Jhelum, Rawalpindi and Islamabad) under CMIP6 scenarios, for publication in an IEEE journal. I request **daily** records for **1 January 1981 – 31 December 2024** for the following PMD stations, or the nearest available: Islamabad (Zero Point), Rawalpindi (Chaklala), Murree, Jhelum, Chakwal, Attock/Campbellpur, Talagang, Mangla, Kotli, Kohat and Sialkot.

Variables: precipitation (mm), maximum and minimum temperature (°C), relative humidity (morning and afternoon observations, or daily mean), wind speed (m/s, with anemometer height), and sunshine duration (hours), together with station coordinates, elevation and any relocation or instrument-change history.

The data will be used only for this research, will not be redistributed, and PMD will be acknowledged in all outputs. I am happy to follow your data policy and pay any applicable charges.

Yours faithfully,
Owais Ali — owais.ali.bahria@gmail.com
[Affiliation, department, supervisor]

### Draft 2 — WAPDA discharge
**Subject:** Request for daily discharge data, Soan River at Chirah and Dhok Pathan, 1981–2024

Dear Sir/Madam,

For academic research on meteorological-to-hydrological drought propagation in the Soan basin, I request **daily mean discharge (m³/s)** at the WAPDA SWHP gauges **Soan at Chirah** and **Soan at Dhok Pathan** for **1981–2024**. Please include the gauge coordinates, catchment areas and any notes on data gaps or rating-curve changes. The data will be used only for this research, with WAPDA acknowledged.

Yours faithfully,
Owais Ali — owais.ali.bahria@gmail.com
[Affiliation]

### Draft 3 — Crop Reporting Service, Punjab (optional: the 2023-24 data, rainfed split and groundnut were found online; send only for the pre-2011 rainfed split or pre-2017 groundnut)
**Subject:** District-wise wheat and groundnut statistics, Rawalpindi Division, 1981-82 to 2023-24

Dear Sir/Madam,

For research on drought impacts on rainfed agriculture in the Potohar Plateau, I request district-wise **area (ha), production (t) and yield (kg/ha)** of **wheat and groundnut** for Attock, Chakwal, Jhelum, Rawalpindi (including Murree and Talagang, if reported separately) and Islamabad, for **1981-82 to 2023-24**. If possible, please split these into **irrigated and un-irrigated (barani)** area. Published Punjab Development Statistics end in 2022-23; the 2023-24 figures are the most urgent.

Yours faithfully,
Owais Ali — owais.ali.bahria@gmail.com
[Affiliation]

### Draft 4 — NDMC drought bulletins
**Subject:** Request for the archive of monthly drought bulletins, 2000–2024

Dear Sir/Madam,

The NDMC website currently returns a server error, and only some bulletins are available through the Internet Archive. For validation of drought indices in the Potohar Plateau, I request the complete set of **monthly (and seasonal) drought bulletins/outlooks issued by NDMC for 2000–2024**, in PDF or any other format, together with the district-level drought category tables if they exist.

Yours faithfully,
Owais Ali — owais.ali.bahria@gmail.com
[Affiliation]

### When data arrive
- PMD stations: save as `data/stations_pmd/{station}.csv` (date, prcp, tmax, tmin, rh or tdew, wind, sunshine) and tell me. The station chunk can read them in place of GSOD.
- WAPDA discharge: save as `02_obs_preprocess/wapda_discharge_daily.csv` (date, Chirah, Dhok Pathan); it replaces GloFAS in the SRI chunk.
- CRS yields: append the rows to `data/yields/district_wheat.csv`.
- Bulletins: drop the PDFs into `data_raw/pmd_bulletins/wayback/`.
