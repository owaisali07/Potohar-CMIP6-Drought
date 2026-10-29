"""Step 0b - Probe value ranges, day counts and calendars of local NEX-GDDP files (read-only).

Writes 00_inventory/value_probe.csv: one row per model x tree (year 2000 historical
and 2050 ssp585), with ntime, calendar, time units and value ranges, to detect unit
conversions (K vs degC, kg m-2 s-1 vs mm/day) and non-standard calendars.
"""
from pathlib import Path

import h5py
import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
CFG = yaml.safe_load(open(ROOT / "config.yaml")); DS = Path(CFG["paths"]["downscaling_readonly"]); P3D = Path(CFG["paths"]["paper3_data"])
P3 = P3D
rows = []


def a(o, k):
    v = o.attrs.get(k, b"")
    return v.decode() if isinstance(v, bytes) else str(v)


for mdir in sorted((P3 / "nex_gddp_cmip6").iterdir()):
    for exp, yr in (("historical", 2000), ("ssp585", 2050)):
        f = mdir / exp / f"nex_gddp_{mdir.name}_{exp}_{yr}_PAK.nc"
        if not f.exists():
            continue
        with h5py.File(f, "r") as h:
            t = h["time"]
            r = dict(tree="PAK", model=mdir.name, exp=exp, year=yr, ntime=t.shape[0],
                     calendar=a(t, "calendar"), time_units=a(t, "units"),
                     global_attrs=";".join(f"{k}={a(h, k)[:40]}" for k in list(h.attrs)[:6]))
            for v in ("pr", "tas", "tasmax", "tasmin"):
                if v in h:
                    x = h[v][()].astype("f8")
                    fv = h[v].attrs.get("_FillValue")
                    if fv is not None:
                        x[x == fv[0]] = np.nan
                    r[f"{v}_min"], r[f"{v}_mean"], r[f"{v}_max"] = np.nanmin(x), np.nanmean(x), np.nanmax(x)
                    r[f"{v}_attrs"] = ";".join(f"{k}={a(h[v], k)}" for k in h[v].attrs if k not in ("DIMENSION_LIST", "_Netcdf4Dimid"))[:120]
        rows.append(r)
    # matching per-variable file (original NEX-GDDP) for the same year
    pv = P3 / "nex-gddp-cmip6" / mdir.name / "historical"
    for f in sorted(pv.glob("pr_day_*_2000*.nc"))[:1]:
        with h5py.File(f, "r") as h:
            t = h["time"]
            x = h["pr"][()].astype("f8")
            rows.append(dict(tree="pervar", model=mdir.name, exp="historical", year=2000, ntime=t.shape[0],
                             calendar=a(t, "calendar"), time_units=a(t, "units"),
                             pr_min=np.nanmin(x), pr_mean=np.nanmean(x), pr_max=np.nanmax(x),
                             pr_attrs=a(h["pr"], "units")))

df = pd.DataFrame(rows)
df.to_csv(ROOT / "00_inventory" / "value_probe.csv", index=False)
pd.set_option("display.width", 250, "display.max_columns", 30, "display.max_rows", 200)
print(df[["tree", "model", "exp", "ntime", "calendar", "pr_mean", "pr_max", "tas_mean", "tasmax_mean", "tasmin_mean"]].round(4))
print(df.loc[df.tree == "PAK", ["model", "pr_attrs", "tas_attrs", "global_attrs"]].head(3).to_string())
