"""Step 2c - Gridded observations -> monthly values on the 0.25 deg NEX-GDDP analysis grid (1981-2024).

Remapping is first-order conservative (area-overlap weights, separable in lon/lat), so 0.05 deg CHIRPS and
1/24 deg TerraClimate cells nest exactly in the 0.25 deg cells.
  CHIRPS v2.0 daily (local, read-only)          -> pr [mm month-1]
  ERA5-Land daily aggregates (local, read-only) -> pr [mm month-1], tasmax, tasmin, tas [degC]
  TerraClimate (downloaded)                     -> tasmax, tasmin, vap [kPa], hurs-equivalent via vap, rsds
                                                   [MJ m-2 d-1], sfcWind [m s-1, 10 m], pet [mm month-1], pr
  CRU TS 4.10 (downloaded)                      -> pr, tas, tasmax, tasmin, pet [mm month-1], vap
Output: 02_obs_preprocess/obs_monthly_{chirps,era5land,terraclimate,cru}.nc
Usage: python 02c_obs_grid.py chirps era5land terraclimate cru
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
RAW = Path(CFG["paths"]["raw"])
OUT = ROOT / "02_obs_preprocess"
W, E, S, N = CFG["domain"]["download_bbox"]
RES = CFG["domain"]["grid_res"]
LONS = np.round(np.arange(W + RES / 2, E, RES), 3)
LATS = np.round(np.arange(S + RES / 2, N, RES), 3)
Y0, Y1 = CFG["periods"]["obs"]


def weights(src, dst, res_dst):
    """Overlap matrix (len(dst) x len(src)) for 1-D cell-centred axes."""
    src = np.asarray(src, float)
    d = np.median(np.abs(np.diff(src)))
    s0, s1 = src - d / 2, src + d / 2
    t0, t1 = dst - res_dst / 2, dst + res_dst / 2
    w = np.clip(np.minimum(t1[:, None], s1[None, :]) - np.maximum(t0[:, None], s0[None, :]), 0, None)
    return w


def remap(da, latn="lat", lonn="lon", lats=None, lons=None, res=None):
    """Conservative remap of (time, lat, lon) to the analysis grid (or a given grid); NaN-aware."""
    lats = LATS if lats is None else lats
    lons = LONS if lons is None else lons
    res = RES if res is None else res
    wy = weights(da[latn].values, lats, res)
    wx = weights(da[lonn].values, lons, res)
    x = da.transpose(..., latn, lonn).values
    m = np.isfinite(x)
    x0 = np.where(m, x, 0.0)
    num = np.einsum("ij,tjk,lk->til", wy, x0, wx)
    den = np.einsum("ij,tjk,lk->til", wy, m.astype(float), wx)
    full = np.einsum("ij,lk->il", wy, wx)[None]
    out = np.where(den > 0.5 * full, num / np.where(den > 0, den, 1), np.nan)
    return xr.DataArray(out.astype("f4"), dims=("time", "lat", "lon"),
                        coords=dict(time=da.time.values, lat=lats, lon=lons))


def fine():
    """0.05 deg observed fields (CHIRPS native grid) for high-resolution observed maps (71.5-74.0E, 32.25-34.25N)."""
    r = 0.05
    flons = np.round(np.arange(71.5 + r / 2, 74.0, r), 3)
    flats = np.round(np.arange(32.25 + r / 2, 34.25, r), 3)
    parts = []
    for y in range(Y0, Y1 + 1):
        with xr.open_dataset(Path(CFG["paths"]["chirps_local"]) / f"chirps-v2.0.{y}.days_p05_PAK.nc") as d:
            p = d.precip.sel(latitude=slice(32.2, 34.3), longitude=slice(71.45, 74.05)).load()
        mon = p.where(p >= 0).resample(time="MS").sum(min_count=25).rename(latitude="lat", longitude="lon")
        parts.append(remap(mon, lats=flats, lons=flons, res=r))
    out = {"pr": xr.concat(parts, "time")}
    d0 = RAW / "terraclimate"
    for v, name in (("tmax", "tasmax"), ("tmin", "tasmin"), ("vap", "vap"), ("srad", "rsds"), ("ws", "sfcWind"), ("pet", "pet")):
        da = xr.concat([xr.open_dataset(d0 / f"TerraClimate_{v}_{y}_potohar.nc")[v].load() for y in range(Y0, Y1 + 1)], "time")
        out[name] = remap(da, lats=flats, lons=flons, res=r)
    out["rsds"] = out["rsds"] * 0.0864
    for k in out:
        out[k]["time"] = mid_month(out[k].time.values)
    ds = xr.Dataset(out)
    for k, u in dict(pr="mm month-1", tasmax="degC", tasmin="degC", vap="kPa", rsds="MJ m-2 d-1", sfcWind="m s-1",
                     pet="mm month-1").items():
        ds[k].attrs["units"] = u
    save(ds, "fine005", "CHIRPS v2.0 (native 0.05 deg) + TerraClimate remapped conservatively to 0.05 deg")


def mid_month(t):
    t = pd.DatetimeIndex(t)
    return pd.DatetimeIndex([pd.Timestamp(a.year, a.month, 15) for a in t])


def save(ds, name, source):
    ds.attrs.update(Conventions="CF-1.8", source=source, grid="0.25 deg (NEX-GDDP-CMIP6 grid), conservative remap",
                    title=f"Monthly {name} for the Potohar Plateau (Paper 6)")
    ds.lat.attrs.update(units="degrees_north", standard_name="latitude")
    ds.lon.attrs.update(units="degrees_east", standard_name="longitude")
    ds.to_netcdf(OUT / f"obs_monthly_{name}.nc", encoding={v: {"zlib": True, "complevel": 4} for v in ds.data_vars})
    print(name, {v: (str(ds[v].attrs.get("units")), float(ds[v].mean())) for v in ds.data_vars})


def chirps():
    fs = [Path(CFG["paths"]["chirps_local"]) / f"chirps-v2.0.{y}.days_p05_PAK.nc" for y in range(Y0, Y1 + 1)]
    parts = []
    for f in fs:
        with xr.open_dataset(f) as d:
            p = d.precip.sel(latitude=slice(S - 0.1, N + 0.1), longitude=slice(W - 0.1, E + 0.1)).load()
        p = p.where(p >= 0)
        mon = p.resample(time="MS").sum(min_count=25)
        parts.append(remap(mon.rename(latitude="lat", longitude="lon")))
    pr = xr.concat(parts, "time")
    pr["time"] = mid_month(pr.time.values)
    pr.attrs.update(units="mm month-1", long_name="precipitation (CHIRPS v2.0)")
    save(xr.Dataset(dict(pr=pr)), "chirps", "CHIRPS v2.0 daily 0.05 deg (Funk et al. 2015)")


def era5land():
    d0 = Path(CFG["paths"]["era5land_local"])
    out = {k: [] for k in ("pr", "tas", "tasmax", "tasmin")}
    times = []
    for y in range(Y0, Y1 + 1):
        for m in range(1, 13):
            f = d0 / f"era5land_daily_PAK_{y}{m:02d}.nc"
            with xr.open_dataset(f) as d:
                d = d.sel(lat=slice(S - 0.2, N + 0.2) if d.lat[0] < d.lat[-1] else slice(N + 0.2, S - 0.2),
                          lon=slice(W - 0.2, E + 0.2)).load()
            n = d.sizes["time"]
            tp = d.total_precipitation_sum.sum("time", min_count=1) * 1000.0
            if n < pd.Timestamp(y, m, 1).days_in_month:  # ERA5-Land DAILY_AGGR starts 1950-01-02
                tp = tp * pd.Timestamp(y, m, 1).days_in_month / n
            arrs = dict(pr=tp, tas=d.temperature_2m.mean("time") - 273.15,
                        tasmax=d.temperature_2m_max.mean("time") - 273.15, tasmin=d.temperature_2m_min.mean("time") - 273.15)
            for k, a in arrs.items():
                out[k].append(a.expand_dims(time=[pd.Timestamp(y, m, 15)]))
    ds = xr.Dataset({k: remap(xr.concat(v, "time")) for k, v in out.items()})
    for k, u in dict(pr="mm month-1", tas="degC", tasmax="degC", tasmin="degC").items():
        ds[k].attrs["units"] = u
    save(ds, "era5land", "ERA5-Land daily aggregates (ECMWF/ERA5_LAND/DAILY_AGGR via GEE; Munoz-Sabater et al. 2021)")


def terraclimate():
    d0 = RAW / "terraclimate"
    ds = {}
    for v in ("tmax", "tmin", "vap", "srad", "ws", "pet", "ppt"):
        da = xr.concat([xr.open_dataset(d0 / f"TerraClimate_{v}_{y}_potohar.nc")[v].load() for y in range(Y0, Y1 + 1)], "time")
        ds[v] = remap(da)
        ds[v]["time"] = mid_month(da.time.values)
    out = xr.Dataset(dict(tasmax=ds["tmax"], tasmin=ds["tmin"], vap=ds["vap"], rsds=ds["srad"] * 0.0864,
                          sfcWind=ds["ws"], pet=ds["pet"], pr=ds["ppt"]))
    for k, u in dict(tasmax="degC", tasmin="degC", vap="kPa", rsds="MJ m-2 d-1", sfcWind="m s-1", pet="mm month-1",
                     pr="mm month-1").items():
        out[k].attrs["units"] = u
    out.sfcWind.attrs["height"] = "10 m"
    save(out, "terraclimate", "TerraClimate monthly 1/24 deg (Abatzoglou et al. 2018)")


def cru():
    d0 = RAW / "cru_ts410"
    ds = {}
    for v in ("pre", "tmp", "tmn", "tmx", "pet", "vap"):
        fs = sorted(d0.glob(f"cru_ts4.10.*.{v}_potohar.nc"))
        da = xr.concat([xr.open_dataset(f)[v].load() for f in fs], "time").sel(time=slice(f"{Y0}", f"{Y1}"))
        if v == "pet":  # CRU pet in mm/day
            da = da * pd.DatetimeIndex(da.time.values).days_in_month.values[:, None, None]
        if v == "vap":  # hPa -> kPa
            da = da / 10.0
        ds[v] = remap(da)
        ds[v]["time"] = mid_month(da.time.values)
    out = xr.Dataset(dict(pr=ds["pre"], tas=ds["tmp"], tasmin=ds["tmn"], tasmax=ds["tmx"], pet=ds["pet"], vap=ds["vap"]))
    for k, u in dict(pr="mm month-1", tas="degC", tasmin="degC", tasmax="degC", pet="mm month-1", vap="kPa").items():
        out[k].attrs["units"] = u
    save(out, "cru", "CRU TS v4.10 0.5 deg (Harris et al. 2020)")


if __name__ == "__main__":
    for t in sys.argv[1:]:
        globals()[t]()
