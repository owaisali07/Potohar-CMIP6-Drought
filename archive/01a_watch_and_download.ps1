# Waits until NASA NCCS THREDDS is reachable, then downloads NEX-GDDP-CMIP6 hurs/rsds/sfcWind:
#   Phase A: historical (all 27 models)  -> needed for GCM evaluation (Eq. 6)
#   Phase B: SSP2-4.5 / SSP5-8.5 for the models listed in 06_gcm_eval/phaseB_models.txt (written by the R ranking),
#            or all models if that file does not exist yet.
# Moderate concurrency (6 threads) to avoid server-side throttling.
$s = "D:\Papers\Paper 6\analysis\scripts"
$log = "D:\Papers\Paper 6\analysis\logs\download_nexgddp_main.out"
function Up { try { (Invoke-WebRequest -UseBasicParsing "https://ds.nccs.nasa.gov/thredds/catalog/AMES/NEX/GDDP-CMIP6/catalog.xml" -TimeoutSec 60).StatusCode -eq 200 } catch { $false } }
while (-not (Up)) { Add-Content $log "$(Get-Date -Format s) NCCS unreachable; retry in 10 min"; Start-Sleep 600 }
Add-Content $log "$(Get-Date -Format s) NCCS reachable: phase A (historical)"
for ($i = 0; $i -lt 5; $i++) { & "$s\run_py.ps1" "$s\01a_download_nexgddp_nccs.py" --exps historical --threads 6 *>> $log; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 300 }
$sel = "D:\Papers\Paper 6\analysis\06_gcm_eval\phaseB_models.txt"
while (-not (Test-Path $sel)) { Add-Content $log "$(Get-Date -Format s) waiting for phaseB_models.txt (GCM ranking)"; Start-Sleep 300 }
$models = (Get-Content $sel) -split '\s+' | Where-Object { $_ }
Add-Content $log "$(Get-Date -Format s) phase B (scenarios) for: $($models -join ', ')"
for ($i = 0; $i -lt 8; $i++) { & "$s\run_py.ps1" "$s\01a_download_nexgddp_nccs.py" --exps ssp245 ssp585 --models @models --threads 6 *>> $log; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 300 }
Add-Content $log "$(Get-Date -Format s) phase B finished"
