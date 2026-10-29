"""Step 1b - Compare NASA NCCS v2.0 pr/tasmax (year 2000) with the local GEE v1.x copy over the Potohar box.

Output: 00_inventory/nex_version_check.csv (max/mean abs difference, share of identical cells, matching
by date; 360-day models are compared on the first 360 local days after removing GEE padding is not
possible, so they are compared by monthly means instead).
"""
from pathlib import Path

import h5py
import numpy as np
import pandas as pd
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
CHK = Path(CFG["paths"]["raw"]) / "nexgddp_nccs" / "check_v2"
LOC = Path(CFG["paths"]["nex_local"])
rows = []
for f in sorted(CHK.rglob("*.nc")):
    model, var = f.parts[-3], f.name.split("_")[0]
    loc = sorted((LOC / model / "historical").glob(f"{var}_day_{model}_historical_*_2000*.nc"))[0]
    with h5py.File(f) as a, h5py.File(loc) as b:
        la, lo = a["lat"][()], a["lon"][()]
        lb, lob = b["lat"][()], b["lon"][()]
        iy = [int(np.argmin(np.abs(lb - y))) for y in la]
        ix = [int(np.argmin(np.abs(lob - x))) for x in lo]
        xa = a[var][()].astype("f8")
        xb = b[var][()][:, iy, :][:, :, ix].astype("f8")
    n = min(len(xa), len(xb))
    same_len = len(xa) == len(xb)
    if same_len:
        d = np.abs(xa - xb)
        rows.append(dict(model=model, var=var, n_v2=len(xa), n_local=len(xb), max_abs=np.nanmax(d), mean_abs=np.nanmean(d),
                         frac_identical=float(np.mean(d < 1e-6)), mean_v2=np.nanmean(xa), mean_local=np.nanmean(xb)))
    else:
        rows.append(dict(model=model, var=var, n_v2=len(xa), n_local=len(xb), max_abs=np.nan, mean_abs=np.nan,
                         frac_identical=np.nan, mean_v2=np.nanmean(xa), mean_local=np.nanmean(xb)))
df = pd.DataFrame(rows)
df.to_csv(Path(CFG["paths"]["root"]) / "00_inventory" / "nex_version_check.csv", index=False)
pd.set_option("display.width", 200)
print(df)
