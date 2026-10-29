#!/usr/bin/env bash
# Stage the Zenodo deposit: data used by the analysis, processed outputs, code and supplementary material.
# PMD station records and WAPDA discharge records are NOT included (agency data; author decision 2026-10-29),
# neither as raw files nor as monthly aggregates. Derived indices and test statistics are included.
# Usage: bash scripts/29_zenodo_stage.sh "<Submission folder>"
set -euo pipefail
P6="/d/Papers/Paper 6"; A="$P6/analysis"; P3="/d/Papers/Paper 3/Paper1_Seasonal_Clock/data"; ADD="/d/downscaling/additional"
SUB="${1:-$P6/Submission_2026-10-23}"; Z="$SUB/11_Zenodo"; T="$Z/_staging"
BSDTAR=/c/Windows/System32/tar.exe                     # bsdtar: writes zip (zip64) archives
mkdir -p "$Z" "$T"
zipit() { local out="$1"; shift; rm -f "$Z/$out"; "$BSDTAR" -a --options zip:compression=store -cf "$Z/$out" "$@"; echo "$(date +%T) $out"; }

# 1. Processed outputs of the analysis (cache_R and data/pmd, data/wapda left out)
rm -rf "$T/analysis_outputs"; mkdir -p "$T/analysis_outputs/data"
for d in 00_inventory 01_boundaries 02_obs_preprocess 03_et0 04_indices_obs 05_characteristics 06_gcm_eval 07_bias_correction \
         08_projections 09_return_periods 10_exposure 11_validation_uncertainty tables figures sensitivity results_text logs; do
  cp -r "$A/$d" "$T/analysis_outputs/"
done
cp -r "$A/data/yields" "$T/analysis_outputs/data/"
# monthly station file: drop the PMD rows (aggregated agency data); GSOD/GHCN-D stations stay
awk -F, 'NR==1 || $1 !~ /\(PMD\)/' "$A/02_obs_preprocess/stations_monthly.csv" > "$T/analysis_outputs/02_obs_preprocess/stations_monthly.csv"
if grep -rlq "(PMD)," "$T/analysis_outputs/02_obs_preprocess/stations_monthly.csv"; then echo "PMD rows left"; exit 1; fi
zipit Potohar_processed_outputs.zip -C "$T" analysis_outputs

# 2. Raw downloads: NEX-GDDP-CMIP6 Potohar-box subsets (NCCS downloads of this study)
zipit Potohar_raw_NEX-GDDP-CMIP6_subsets.zip -C "$P6/data_raw" nexgddp_nccs -C "$ADD" nexgddp_cmip6 MANIFEST_sha256.csv

# 3. ERA5-Land daily (Pakistan subset, 1981-2024, read by 02c/02d)
mapfile -t ERA < <(ls "$P3/era5land_daily" | grep -E "_(198[1-9]|199[0-9]|20[01][0-9]|202[0-4])[0-9]{2}\.nc$" | sed "s|^|era5land_daily/|")
zipit Potohar_raw_ERA5-Land_daily_1981-2024.zip -C "$P3" "${ERA[@]}"

# 4. Other observations, reanalysis-derived and reference data
mapfile -t CHI < <(ls "$P3/chirps" | grep -E "\.(198[1-9]|199[0-9]|20[01][0-9]|202[0-4])\.days" | sed "s|^|chirps/|")
zipit Potohar_raw_observations_other.zip -C "$P3" "${CHI[@]}" boundaries \
  -C "$P6/data_raw" cru_ts410 terraclimate gee glofas_ewds glofas_openmeteo stations_v2 isimip3b gwl gdhy \
  -C "$ADD" esa_cci_sm persiann_cdr

# 5. Land cover, elevation and crop statistics
zipit Potohar_raw_landcover_DEM_crops.zip -C "$P6/data_raw" spam2010 worldcover copdem_glo30 copdem_glo90 yields

# 6. Supplementary material of the manuscript
zipit Potohar_supplementary_material.zip -C "$SUB" 05_Supplementary

# 7. Code: the public copy of the analysis repository (30_public_export.sh: no agency data)
rm -rf "$T/code"; bash "$A/scripts/30_public_export.sh" "$T/code/analysis"
zipit Potohar_code.zip -C "$T/code" analysis
if "$BSDTAR" -tf "$Z/Potohar_code.zip" | grep -qiE "data/(pmd|wapda)/"; then echo "agency data in code zip"; exit 1; fi
echo "$(date +%T) Potohar_code.zip ($(git -C "$A" rev-parse --short HEAD))"

rm -rf "$T"
( cd "$Z" && sha256sum *.zip > SHA256SUMS.txt && ls -l *.zip )
