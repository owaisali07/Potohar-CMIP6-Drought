"""Step 1m (v2.1) - Table II robustness datasets (download only; statistics in the Rmd).

  persiann : PERSIANN-CDR daily precipitation (GEE NOAA/PERSIANN-CDR, 0.25 deg) summed to months on the exact 0.25-deg
             analysis grid (download_bbox of config.yaml), 1983-2024. Role (Table II): rainfall-uncertainty range for SPI/SPEI.
  cci_sm   : C3S/ESA CCI satellite soil moisture, COMBINED active+passive, monthly, CDR v202505 (CDS 'satellite-soil-moisture'),
             1981-2024; global monthly files kept, clipped copy for the Potohar box. Role (Table II): validation of agricultural drought.
Downloads go to <paths.downscaling_additional> in config.yaml (the folder named by the author); every file is logged
with its SHA-256 in MANIFEST_sha256.csv.
Usage: run_py.ps1 01m_download_robustness_obs.py persiann cci_sm
"""
import csv
import hashlib
import sys
import time
import zipfile
from pathlib import Path

import numpy as np
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ADD = Path(CFG["paths"]["downscaling_additional"]); ADD.mkdir(parents=True, exist_ok=True)
W, E, S, N = CFG["domain"]["download_bbox"]; RES = CFG["domain"]["grid_res"]
MAN = ADD / "MANIFEST_sha256.csv"


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def log(p, source, note=""):
    new = not MAN.exists()
    with open(MAN, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["file", "bytes", "sha256", "source", "note", "logged_utc"])
        w.writerow([str(Path(p).relative_to(ADD)).replace("\\", "/"), Path(p).stat().st_size, sha256(p), source, note, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())])


def persiann():
    import ee
    ee.Initialize(project="eighth-effect-409505")
    out = ADD / "persiann_cdr"; out.mkdir(exist_ok=True)
    nx, ny = int(round((E - W) / RES)), int(round((N - S) / RES))
    col = ee.ImageCollection("NOAA/PERSIANN-CDR").select("precipitation")
    for y in range(1983, 2025):
        f = out / f"persiann_cdr_monthly_0p25_{y}.nc"
        if f.exists():
            continue
        months = [col.filterDate(f"{y}-{m:02d}-01", ee.Date(f"{y}-{m:02d}-01").advance(1, "month")).sum().rename(f"m{m:02d}") for m in range(1, 13)]
        img = ee.Image.cat(months)
        for k in range(6):
            try:
                arr = ee.data.computePixels({"expression": img, "fileFormat": "NUMPY_NDARRAY",
                                             "grid": {"dimensions": {"width": nx, "height": ny}, "affineTransform": {
                                                 "scaleX": RES, "shearX": 0, "translateX": W, "shearY": 0, "scaleY": -RES, "translateY": N},
                                                 "crsCode": "EPSG:4326"}})
                break
            except Exception as e:  # noqa: BLE001
                print("retry", y, k, str(e)[:120], flush=True); time.sleep(30 * (k + 1))
        else:
            raise RuntimeError(f"PERSIANN {y} failed")
        data = np.stack([np.asarray(arr[f"m{m:02d}"], dtype="float32") for m in range(1, 13)])     # (12, ny, nx), north-up
        lat = N - RES / 2 - RES * np.arange(ny); lon = W + RES / 2 + RES * np.arange(nx)
        t = np.array([np.datetime64(f"{y}-{m:02d}-15") for m in range(1, 13)])
        ds = xr.Dataset({"pr": (("time", "lat", "lon"), data, {"units": "mm month-1", "long_name": "PERSIANN-CDR precipitation, monthly sum of daily values",
                                                               "cell_methods": "time: sum"})}, coords={"time": t, "lat": lat, "lon": lon})
        ds.attrs.update(Conventions="CF-1.8", source="Google Earth Engine NOAA/PERSIANN-CDR (Ashouri et al. 2015)", grid="NEX-GDDP-CMIP6 0.25-deg grid")
        ds.to_netcdf(f); log(f, "GEE NOAA/PERSIANN-CDR", f"monthly sums {y}"); print("ok", f.name, flush=True)


def cci_sm():
    import cdsapi
    out = ADD / "esa_cci_sm"; (out / "global_zip").mkdir(parents=True, exist_ok=True)
    c = cdsapi.Client(quiet=True)
    for y in range(1981, 2025):
        z = out / "global_zip" / f"c3s_sm_combined_monthly_v202505_{y}.zip"
        clip = out / f"c3s_sm_combined_monthly_potohar_{y}.nc"
        if not z.exists():
            req = {"variable": ["surface_soil_moisture_volumetric"], "type_of_sensor": ["combined"], "time_aggregation": ["month_average"],
                   "year": [str(y)], "month": [f"{m:02d}" for m in range(1, 13)], "day": ["01"], "type_of_record": ["cdr"], "version": ["v202505"]}
            for k in range(6):
                try:
                    c.retrieve("satellite-soil-moisture", req, str(z)); break
                except Exception as e:  # noqa: BLE001
                    print("retry", y, k, str(e)[:160], flush=True); time.sleep(60 * (k + 1))
            else:
                raise RuntimeError(f"CCI SM {y} failed")
            log(z, "CDS satellite-soil-moisture", f"combined, monthly, CDR v202505, {y}, global")
        if not clip.exists():
            parts = []
            with zipfile.ZipFile(z) as zz:
                for n in sorted(zz.namelist()):
                    if not n.endswith(".nc"):
                        continue
                    tmp = out / "_tmp.nc"; tmp.write_bytes(zz.read(n))
                    with xr.open_dataset(tmp) as ds:
                        parts.append(ds[["sm"]].sel(lat=slice(N, S), lon=slice(W, E)).load())
                    tmp.unlink()
            xr.concat(parts, "time").to_netcdf(clip); log(clip, "derived from global_zip", f"clip {W}-{E}E {S}-{N}N, {y}")
            print("ok", clip.name, flush=True)


if __name__ == "__main__":
    for mode in sys.argv[1:] or ["persiann", "cci_sm"]:
        {"persiann": persiann, "cci_sm": cci_sm}[mode]()
