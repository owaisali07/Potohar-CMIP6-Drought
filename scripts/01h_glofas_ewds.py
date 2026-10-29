"""Step 1h (v2) - GloFAS-ERA5 historical v4.0 (consolidated, LISFLOOD) daily discharge 1979-2024 from the
Copernicus Early Warning Data Store (EWDS, dataset cems-glofas-historical), small box around the Soan outlets.
Credentials: ~/.cdsapirc key (ECMWF account; the same token is valid on EWDS).
Output: data_raw/glofas_ewds/glofas_v4_{year}.nc and 02_obs_preprocess/glofas_ewds_discharge_daily.csv
at the GloFAS cells selected in 01e (Dhok Pathan 33.125N 72.325E; Chirah 33.675N 73.325E).
"""
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import cdsapi
import numpy as np
import pandas as pd
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
OUT = Path(CFG["paths"]["raw"]) / "glofas_ewds"
OUT.mkdir(parents=True, exist_ok=True)
KEY = [l.split(":", 1)[1].strip() for l in open(Path.home() / ".cdsapirc") if l.startswith("key")][0]
CELLS = pd.read_csv(ROOT / "02_obs_preprocess" / "glofas_cell_choice.csv").query("chosen == True")


def have(y):
    return (OUT / f"glofas_v4_{y}.nc").exists() or any(int(f.stem.split("_")[2]) <= y <= int(f.stem.split("_")[3])
                                                       for f in OUT.glob("glofas_v4_*_*.nc"))


def get_years(ys):
    """One EWDS request for several years (the queue, not the volume, limits throughput)."""
    ys = [y for y in ys if not have(y)]
    if not ys:
        return None
    dest = OUT / f"glofas_v4_{ys[0]}_{ys[-1]}.nc"
    c = cdsapi.Client(url="https://ewds.climate.copernicus.eu/api", key=KEY, quiet=True)
    req = {"system_version": ["version_4_0"], "hydrological_model": ["lisflood"], "product_type": ["consolidated"],
           "variable": ["average_river_discharge_in_the_last_24_hours"], "timespan": ["time_mean"],
           "year": [str(y) for y in ys], "month": [f"{m:02d}" for m in range(1, 13)], "day": [f"{d:02d}" for d in range(1, 32)],
           "data_format": "netcdf", "download_format": "unarchived", "area": [33.85, 72.05, 32.95, 73.55]}
    for k in range(6):
        try:
            c.retrieve("cems-glofas-historical", req, str(dest))
            return ys
        except Exception as e:  # noqa: BLE001
            if "cost limits" in str(e) and len(ys) > 1:          # request too large for EWDS: split in halves
                h = len(ys) // 2
                return (get_years(ys[:h]) or []) + (get_years(ys[h:]) or [])
            print(ys, "retry", k, str(e)[:150], flush=True)
            time.sleep(60 * (k + 1))
    raise RuntimeError(f"years {ys} failed")


def main():
    years = list(range(1979, 2025))
    todo = [y for y in years if not have(y)]
    chunks = [todo[i:i + 2] for i in range(0, len(todo), 2)]
    with ThreadPoolExecutor(5) as ex:
        for ys in ex.map(get_years, chunks):
            print("done", ys, flush=True)
    files = sorted(OUT.glob("glofas_v4_*.nc"))
    series = {}
    for _, c in CELLS.iterrows():
        vals = []
        for fpath in files:
            with xr.open_dataset(fpath) as d:
                v = [n for n in d.data_vars][0]
                tname = "valid_time" if "valid_time" in d.dims else "time"
                s = d[v].sel(latitude=c.cell_lat, longitude=c.cell_lon, method="nearest")
                vals.append(pd.Series(s.values, index=pd.to_datetime(d[tname].values)))
                lat_used, lon_used = float(s.latitude), float(s.longitude)
        s_all = pd.concat(vals)
        series[c.outlet] = s_all[~s_all.index.duplicated()].sort_index()
        print(c.outlet, "cell", lat_used, lon_used)
    df = pd.DataFrame(series)
    df.index = df.index.normalize() - pd.Timedelta(days=1)  # value valid for the 24 h ending at 00 UTC -> date of the day
    df.index.name = "date"
    df.to_csv(ROOT / "02_obs_preprocess" / "glofas_ewds_discharge_daily.csv", float_format="%.3f")
    old = pd.read_csv(ROOT / "02_obs_preprocess" / "glofas_discharge_daily.csv", parse_dates=["date"], index_col="date")
    j = df.join(old, rsuffix="_openmeteo").dropna()
    for o in ("Dhok Pathan", "Chirah"):
        print(o, "r(EWDS, Open-Meteo) =", round(np.corrcoef(j[o], j[o + "_openmeteo"])[0, 1], 4),
              "mean", round(j[o].mean(), 2), round(j[o + "_openmeteo"].mean(), 2), "n", len(j))
    print(df.describe().round(2))


if __name__ == "__main__":
    sys.exit(main())

