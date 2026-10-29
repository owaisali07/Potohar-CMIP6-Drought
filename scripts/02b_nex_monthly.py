"""Step 2b - Daily NEX-GDDP-CMIP6 -> monthly values on the 0.25 deg Potohar analysis grid.

Inputs (read-only):
  pr, tasmax, tasmin : local NEX-GDDP-CMIP6 copy (Paper 3; GEE v1.0/v1.1, identical to NASA files, see
                       00_inventory/nex_version_check.csv)
  hurs, rsds, sfcWind: NASA NCCS v2.0 subsets (01a_download_nexgddp_nccs.py)
  v2.1: models downloaded with all six variables to <paths.downscaling_additional>/nexgddp_cmip6 (Phase B) take
        every variable from there (NCCS v2.0); the local v1.x copy is not used for them.
Monthly products (CF names):
  pr      [mm month-1]   = mean daily rate (kg m-2 s-1 * 86400) * days in the Gregorian month
  tasmax, tasmin [degC]  monthly mean of daily values
  hurs [%], rsds [MJ m-2 d-1] (W m-2 * 0.0864), sfcWind [m s-1] (10 m) : monthly means
Calendar handling: 365-day models relabelled by GEE in leap years (duplicated last day) are repaired as in
Paper 3; 360-day models are averaged by native month. Monthly means are therefore unaffected by calendar.
Output: 06_gcm_eval/gcm_monthly/{model}_{experiment}.nc   (time = 15th of each month, Gregorian)
Usage: python 02b_nex_monthly.py [--vars pr tasmax tasmin hurs rsds sfcWind] [--models ...]
"""
import argparse
import re
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import cftime
import h5py
import numpy as np
import pandas as pd
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
LOCAL = Path(CFG["paths"]["nex_local"])
NCCS = Path(CFG["paths"]["raw"]) / "nexgddp_nccs" / "data"
ADDN = Path(CFG["paths"]["downscaling_additional"]) / "nexgddp_cmip6" / "data"
OUT = ROOT / "06_gcm_eval" / "gcm_monthly"
OUT.mkdir(parents=True, exist_ok=True)
W, E, S, N = CFG["domain"]["download_bbox"]
RES = CFG["domain"]["grid_res"]
LONS = np.round(np.arange(W + RES / 2, E, RES), 3)
LATS = np.round(np.arange(S + RES / 2, N, RES), 3)
EXPS = {"historical": (CFG["periods"]["hist_sim"][0], 2014), "ssp245": (2015, 2100), "ssp585": (2015, 2100)}
NOLEAP = {"CMCC-ESM2", "CanESM5", "FGOALS-g3", "GFDL-CM4", "GFDL-ESM4", "GISS-E2-1-G", "INM-CM4-8", "INM-CM5-0",
          "KIOST-ESM", "NorESM2-LM", "NorESM2-MM", "TaiESM1"}


def idx(axis, targets):
    return np.array([int(np.argmin(np.abs(axis - t))) for t in targets])


def read_year(path, var):
    with h5py.File(path, "r") as f:
        lat, lon = f["lat"][()], f["lon"][()]
        iy, ix = idx(lat, LATS), idx(lon, LONS)
        assert np.max(np.abs(lat[iy] - LATS)) < 0.01 and np.max(np.abs(lon[ix] - LONS)) < 0.01, path
        y0, y1 = iy.min(), iy.max() + 1
        x0, x1 = ix.min(), ix.max() + 1
        a = f[var][:, y0:y1, x0:x1].astype("f8")
        a = a[:, iy - y0][:, :, ix - x0]
        t = f["time"]
        units = t.attrs["units"].decode() if isinstance(t.attrs["units"], bytes) else t.attrs["units"]
        cal = t.attrs.get("calendar", b"standard")
        cal = cal.decode() if isinstance(cal, bytes) else cal
        times = cftime.num2date(t[()], units, calendar=cal)
    fv = 1e19
    a[np.abs(a) > fv] = np.nan
    return a, times


def monthly_from_daily(a, times, model, year, local):
    months = np.array([tt.month for tt in times])
    years = np.array([tt.year for tt in times])
    if local and model in NOLEAP and len(times) == 366 and np.array_equal(a[-1], a[-2], equal_nan=True):
        # GEE labelling of a 365-day model in a leap year (see Paper 3 fix_nex_calendars.py)
        a = a[:-1]
        doy = np.arange(365)
        dates = pd.Timestamp(year, 1, 1) + pd.to_timedelta(doy, "D")
        dates = np.where(dates >= pd.Timestamp(year, 2, 29), dates + pd.Timedelta(days=1), dates)
        months = pd.DatetimeIndex(dates).month.values
        years = np.full(365, year)
    out = np.full((12,) + a.shape[1:], np.nan)
    for m in range(1, 13):
        sel = (months == m) & (years == year)
        if sel.any():
            out[m - 1] = np.nanmean(a[sel], axis=0)
    return out


def local_files(model, exp, var):
    d = LOCAL / model / exp
    fs = {}
    for f in d.glob(f"{var}_day_{model}_{exp}_*.nc"):
        y = int(re.search(r"_(\d{4})(?:_v[\d.]+)?\.nc$", f.name).group(1))
        if y not in fs or "_v1.1" in f.name:  # prefer v1.1 where both exist
            fs[y] = f
    return fs


def nccs_files(model, exp, var, base=None):
    d = (base or NCCS) / model / exp
    return {int(re.search(r"_(\d{4})(?:_v[\d.]+)?\.nc$", f.name).group(1)): f for f in d.glob(f"{var}_day_*.nc")}


def process(model, exp, var):
    dest = OUT / "_parts" / f"{model}_{exp}_{var}.nc"
    if dest.exists():
        return str(dest)
    y0, y1 = EXPS[exp]
    need = set(range(y0, y1 + 1))
    allowed_missing = {("KIOST-ESM", "ssp245", "hurs")}   # one year missing at NASA itself (filled in R)
    add = nccs_files(model, exp, var, ADDN)
    if len(need - set(add)) <= (1 if (model, exp, var) in allowed_missing else 0) and add:                      # complete v2.0 set in <paths.downscaling_additional> -> use it for every variable
        local, files = False, add
    else:
        local = var in ("pr", "tasmax", "tasmin")
        files = local_files(model, exp, var) if local else nccs_files(model, exp, var)
    if model == "IITM-ESM":
        need.discard(2100)
    allowed_missing = {("KIOST-ESM", "ssp245", "hurs")}   # one year missing at NASA itself (filled in R)
    if not local and len(need - set(files)) > (1 if (model, exp, var) in allowed_missing else 0):
        return None   # download incomplete -> do not cache a part with missing years
    data, tlist = [], []
    for y in range(y0, y1 + 1):
        if y in files:
            a, times = read_year(files[y], var)
            mm = monthly_from_daily(a, times, model, y, local)
        else:
            mm = np.full((12, len(LATS), len(LONS)), np.nan)
        data.append(mm)
        tlist += [pd.Timestamp(y, m, 15) for m in range(1, 13)]
    x = np.concatenate(data)
    t = pd.DatetimeIndex(tlist)
    if var == "pr":
        x = x * 86400.0 * t.days_in_month.values[:, None, None]
        units = "mm month-1"
    elif var in ("tasmax", "tasmin"):
        x = x - 273.15
        units = "degC"
    elif var == "rsds":
        x = x * 0.0864
        units = "MJ m-2 d-1"
    elif var == "hurs":
        x = np.clip(x, 0, 100)
        units = "%"
    else:
        units = "m s-1"
    missing_years = sorted(set(range(y0, y1 + 1)) - set(files))
    da = xr.DataArray(x.astype("f4"), dims=("time", "lat", "lon"), coords=dict(time=t, lat=LATS, lon=LONS), name=var,
                      attrs=dict(units=units, missing_years=",".join(map(str, missing_years)),
                                 source="local NEX-GDDP-CMIP6 v1.x (GEE)" if local else "NASA NCCS NEX-GDDP-CMIP6 v2.0"))
    dest.parent.mkdir(exist_ok=True)
    da.to_netcdf(dest, encoding={var: {"zlib": True, "complevel": 4}})
    return str(dest)


def merge(model, exp, variables):
    parts = [OUT / "_parts" / f"{model}_{exp}_{v}.nc" for v in variables]
    if not all(p.exists() for p in parts):
        return False
    ds = xr.merge([xr.open_dataarray(p) for p in parts])
    ds.attrs.update(model=model, experiment=exp, variant=CFG["models"][model], grid="0.25 deg NEX-GDDP-CMIP6 native",
                    Conventions="CF-1.8", title="Monthly NEX-GDDP-CMIP6 for the Potohar Plateau (Paper 6)")
    ds.lat.attrs.update(units="degrees_north", standard_name="latitude")
    ds.lon.attrs.update(units="degrees_east", standard_name="longitude")
    ds.to_netcdf(OUT / f"{model}_{exp}.nc", encoding={v: {"zlib": True, "complevel": 4} for v in ds.data_vars})
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vars", nargs="+", default=["pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"])
    ap.add_argument("--models", nargs="+", default=list(CFG["models"]))
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--exps", nargs="+", default=list(EXPS))
    a = ap.parse_args()
    jobs = [(m, e, v) for m in a.models for e in a.exps for v in a.vars]
    with ProcessPoolExecutor(a.workers) as ex:
        for r in ex.map(process, *zip(*jobs)):
            pass
    allv = ["pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"]
    merged = sum(merge(m, e, allv) for m in a.models for e in a.exps)
    print(f"parts done: {len(jobs)}; merged files: {merged}")


if __name__ == "__main__":
    main()
