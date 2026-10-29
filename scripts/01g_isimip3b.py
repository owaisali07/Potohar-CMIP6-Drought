"""Step 1g - ISIMIP3b bias-adjusted CMIP6 (Lange 2019; W5E5 target, 0.5 deg) for the second-chain sensitivity test
(Table II alternative to NEX-GDDP-CMIP6). ISIMIP3b primary forcing has historical, SSP1-2.6, SSP3-7.0 and SSP5-8.5;
SSP2-4.5 is not provided, so the comparison is done for SSP5-8.5 (DEVIATIONS D11).

Uses the ISIMIP Files API v2 server-side `select_bbox` cut-out, then aggregates to monthly values as in 02b.
Output: 06_gcm_eval/isimip3b_monthly/{MODEL}_{historical|ssp585}.nc  (0.5 deg native grid)
"""
import io
import time
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd
import requests
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
RAW = Path(CFG["paths"]["raw"]) / "isimip3b"
OUT = ROOT / "06_gcm_eval" / "isimip3b_monthly"
OUT.mkdir(parents=True, exist_ok=True)
W, E, S, N = CFG["domain"]["download_bbox"]
MODELS = {"gfdl-esm4": "GFDL-ESM4", "ipsl-cm6a-lr": "IPSL-CM6A-LR", "mpi-esm1-2-hr": "MPI-ESM1-2-HR",
          "mri-esm2-0": "MRI-ESM2-0", "ukesm1-0-ll": "UKESM1-0-LL"}
VARS = ["pr", "tasmax", "tasmin", "hurs", "rsds", "sfcwind"]
EXPS = {"historical": (1981, 2014), "ssp585": (2015, 2100)}
API = "https://data.isimip.org/api/v1/files/"
_get, _post = requests.get, requests.post


def _retry(fn):
    def w(*a, **k):
        for i in range(10):
            try:
                return fn(*a, **k)
            except requests.exceptions.RequestException:
                time.sleep(30 * (i + 1))
        return fn(*a, **k)
    return w


requests.get, requests.post = _retry(_get), _retry(_post)


def paths(model, exp, var, y0, y1):
    p = dict(simulation_round="ISIMIP3b", product="InputData", category="climate", subcategory="atmosphere",
             climate_forcing=model, climate_scenario=exp, climate_variable=var, time_step="daily", page_size=200)
    res = requests.get(API, params=p, timeout=120).json()["results"]
    out = []
    for f in res:
        name = f["path"]
        a, b = int(name[-12:-8]), int(name[-7:-3])  # ..._YYYY_YYYY.nc
        if b >= y0 and a <= y1 and "global" in name:
            out.append(f["path"])
    return sorted(out)


def cutout(plist, dest_dir):
    dest_dir.mkdir(parents=True, exist_ok=True)
    if (dest_dir / "_done.txt").exists():
        return
    job = dict(paths=plist, operations=[dict(operation="select_bbox", bbox=[W, E, S, N])])
    for k in range(200):
        r = requests.post("https://files.isimip.org/api/v2", json=job, timeout=120).json()
        if r.get("status") == "finished":
            z = requests.get(r["file_url"], timeout=600).content
            with zipfile.ZipFile(io.BytesIO(z)) as zf:
                zf.extractall(dest_dir)
            (dest_dir / "_done.txt").write_text("\n".join(plist))
            return
        if r.get("status") == "failed":
            raise RuntimeError(r)
        time.sleep(30)
    raise TimeoutError(plist[0])


def monthly(files, var, y0, y1):
    da = xr.open_mfdataset(sorted(files), combine="by_coords")[var].sel(time=slice(f"{y0}", f"{y1}")).load()
    m = da.resample(time="MS").mean()
    t = pd.DatetimeIndex(m.time.values)
    if var == "pr":
        m = m * 86400 * xr.DataArray(t.days_in_month.values, dims="time"); u = "mm month-1"
    elif var in ("tasmax", "tasmin"):
        m = m - 273.15; u = "degC"
    elif var == "rsds":
        m = m * 0.0864; u = "MJ m-2 d-1"
    elif var == "hurs":
        u = "%"
    else:
        u = "m s-1"
    m["time"] = [pd.Timestamp(x.year, x.month, 15) for x in t]
    m.attrs = dict(units=u)
    return m.rename("sfcWind" if var == "sfcwind" else var)


for mk, MN in MODELS.items():
    for exp, (y0, y1) in EXPS.items():
        dest = OUT / f"{MN}_{exp}.nc"
        if dest.exists():
            continue
        das = []
        for v in VARS:
            pl = paths(mk, exp, v, y0, y1)
            d = RAW / MN / exp / v
            cutout(pl, d)
            das.append(monthly(list(d.rglob("*.nc")), v, y0, y1))
            print(MN, exp, v, len(pl), "files", flush=True)
        ds = xr.merge(das).sortby("lat")
        ds.attrs.update(model=MN, experiment=exp, source="ISIMIP3b bias-adjusted (ISIMIP3BASD v2.5, W5E5 v2.0) 0.5 deg")
        ds.to_netcdf(dest, encoding={v: {"zlib": True, "complevel": 4} for v in ds.data_vars})
print("done")

