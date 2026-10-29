"""Step 2d - Daily CHIRPS (precip) and ERA5-Land (tmax, tmin, precip) at each station's grid cell, 1981-2024.
Used in the R analysis to fill short station gaps by quantile mapping (Methodology III-B).
Output: 02_obs_preprocess/station_gridpoints_daily.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
meta = pd.read_csv(ROOT / "02_obs_preprocess" / "stations_meta.csv")
Y0, Y1 = CFG["periods"]["obs"]
frames = []
# CHIRPS
ch = []
for y in range(Y0, Y1 + 1):
    with xr.open_dataset(Path(CFG["paths"]["chirps_local"]) / f"chirps-v2.0.{y}.days_p05_PAK.nc") as d:
        pts = d.precip.sel(latitude=xr.DataArray(meta.lat.values, dims="st"),
                           longitude=xr.DataArray(meta.lon.values, dims="st"), method="nearest").load()
    ch.append(pts.to_pandas())
chd = pd.concat(ch)
chd.columns = meta.station.values
# ERA5-Land
e = {k: [] for k in ("tmax", "tmin", "pr")}
idx = []
for y in range(Y0, Y1 + 1):
    for m in range(1, 13):
        with xr.open_dataset(Path(CFG["paths"]["era5land_local"]) / f"era5land_daily_PAK_{y}{m:02d}.nc") as d:
            sel = d.sel(lat=xr.DataArray(meta.lat.values, dims="st"), lon=xr.DataArray(meta.lon.values, dims="st"), method="nearest").load()
        e["tmax"].append(sel.temperature_2m_max.values - 273.15)
        e["tmin"].append(sel.temperature_2m_min.values - 273.15)
        e["pr"].append(sel.total_precipitation_sum.values * 1000.0)
        idx.append(pd.DatetimeIndex(sel.time.values))
eidx = idx[0].append(idx[1:])
for k in e:
    e[k] = pd.DataFrame(np.concatenate(e[k]), index=eidx, columns=meta.station.values)
for s in meta.station:
    f = pd.DataFrame({"chirps_pr": chd[s], "era5l_tmax": e["tmax"][s], "era5l_tmin": e["tmin"][s], "era5l_pr": e["pr"][s]})
    f.insert(0, "station", s)
    frames.append(f.rename_axis("date").reset_index())
out = pd.concat(frames)
out.to_csv(ROOT / "02_obs_preprocess" / "station_gridpoints_daily.csv", index=False, float_format="%.2f")
print(out.groupby("station").mean(numeric_only=True).round(2))
