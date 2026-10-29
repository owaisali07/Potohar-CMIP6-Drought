"""Step 0c - Quick physical QC of local NEX-GDDP temperature/precip (read-only).

Per model (PAK tree, years 1985, 2000, 2014, 2050, 2090): fraction of tasmax<tasmin,
mean DTR, mean (tas - (tasmax+tasmin)/2), share of days identical to the previous day
(flags padded calendars), and negative pr. Output: 00_inventory/qc_temperature.csv
"""
from pathlib import Path

import h5py
import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
CFG = yaml.safe_load(open(ROOT / "config.yaml")); DS = Path(CFG["paths"]["downscaling_readonly"]); P3D = Path(CFG["paths"]["paper3_data"])
P3 = P3D / "nex_gddp_cmip6"
rows = []
for mdir in sorted(P3.iterdir()):
    for exp, yr in (("historical", 1985), ("historical", 2000), ("historical", 2014), ("ssp245", 2050), ("ssp585", 2050), ("ssp585", 2090)):
        f = mdir / exp / f"nex_gddp_{mdir.name}_{exp}_{yr}_PAK.nc"
        if not f.exists():
            continue
        with h5py.File(f, "r") as h:
            pr = h["pr"][()]
            r = dict(model=mdir.name, exp=exp, year=yr, ndays=pr.shape[0],
                     neg_pr_frac=float(np.nanmean(pr < 0)),
                     dup_day_frac_pr=float(np.mean([np.array_equal(pr[i], pr[i - 1], equal_nan=True) for i in range(1, pr.shape[0])])))
            if "tasmax" in h:
                tx, tn, ta = h["tasmax"][()], h["tasmin"][()], h["tas"][()]
                r.update(tmax_lt_tmin_frac=float(np.nanmean(tx < tn)), mean_DTR_K=float(np.nanmean(tx - tn)),
                         tas_minus_midpoint_K=float(np.nanmean(ta - (tx + tn) / 2)))
        rows.append(r)
df = pd.DataFrame(rows)
df.to_csv(ROOT / "00_inventory" / "qc_temperature.csv", index=False)
pd.set_option("display.width", 220, "display.max_rows", 300)
g = df.groupby("model").agg(DTR=("mean_DTR_K", "mean"), DTR_min=("mean_DTR_K", "min"), tmid=("tas_minus_midpoint_K", "mean"),
                            tmid_maxabs=("tas_minus_midpoint_K", lambda s: s.abs().max()), tx_lt_tn=("tmax_lt_tmin_frac", "max"),
                            dup=("dup_day_frac_pr", "max"), negpr=("neg_pr_frac", "max"))
print(g.round(3))
print(df[df.tas_minus_midpoint_K.abs() > 1.5].round(3).to_string())
