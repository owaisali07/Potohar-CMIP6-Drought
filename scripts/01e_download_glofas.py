"""Step 1e - GloFAS-ERA5 (v4) daily river discharge at the Soan outlets (Table II alternative to WAPDA).

Source: Open-Meteo Flood API (https://open-meteo.com/en/docs/flood-api), which serves the GloFAS v4 consolidated
reanalysis (0.05 deg) from 1984 onward without a key. Because GloFAS is gridded, the 5 x 5 GloFAS cells (0.05 deg)
around each delineated outlet are queried and the cell whose long-term mean discharge best matches the
outlet's drainage area (largest-flow cell = main stem, as GloFAS has no upstream-area field in this API) is used.
Output: 02_obs_preprocess/glofas_discharge_daily.csv, glofas_cell_choice.csv
"""
import time
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import requests
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
OUT = ROOT / "02_obs_preprocess"
bas = gpd.read_file(ROOT / "01_boundaries" / "soan_basins.gpkg")
OUTLETS = {"Dhok Pathan": bas[bas.name.str.contains("Dhok Pathan, GLO-90")].iloc[0],
           "Chirah": bas[bas.name.str.contains("Chirah")].iloc[0]}


CACHE = Path(CFG["paths"]["raw"]) / "glofas_openmeteo"
CACHE.mkdir(parents=True, exist_ok=True)


def q(lat, lon):
    """Query one location; responses cached (the API is rate-limited: ~100 weighted calls per 41-year request)."""
    cf = CACHE / f"q_{lat:.3f}_{lon:.3f}.json"
    if cf.exists():
        j = __import__("json").loads(cf.read_text())
    else:
        url = ("https://flood-api.open-meteo.com/v1/flood?latitude={:.3f}&longitude={:.3f}&daily=river_discharge"
               "&start_date=1984-01-01&end_date=2024-12-31&models=seamless_v4").format(lat, lon)
        for k in range(12):
            try:
                r = requests.get(url, timeout=120)
            except requests.exceptions.RequestException:
                time.sleep(60); continue
            if r.status_code == 429:
                print("rate limited; waiting 15 min", flush=True); time.sleep(900); continue
            r.raise_for_status()
            j = r.json(); cf.write_text(r.text)
            break
        else:
            raise RuntimeError("rate limit not released")
    return j["latitude"], j["longitude"], pd.Series(j["daily"]["river_discharge"], index=pd.to_datetime(j["daily"]["time"]), dtype=float)


rows, cand = [], {}
for name, o in OUTLETS.items():
    seen = set()
    rad = 0.10 if name == "Dhok Pathan" else 0.05
    for dy in np.arange(-rad, rad + 0.001, 0.05):
        for dx in np.arange(-rad, rad + 0.001, 0.05):
            la, lo, s = q(o.outlet_lat + dy, o.outlet_lon + dx)
            if (la, lo) in seen:
                continue
            seen.add((la, lo))
            rows.append(dict(outlet=name, cell_lat=la, cell_lon=lo, mean_q=float(s.mean()), n_valid=int(s.notna().sum()),
                             delineated_area_km2=o.area_km2))
            cand[(name, la, lo)] = s
            time.sleep(1.0)
ch = pd.DataFrame(rows)
ch["chosen"] = False
# Dhok Pathan (large river, no larger river within 0.1 deg): main-stem = largest-flow cell
sub_dp = ch[(ch.outlet == "Dhok Pathan") & (ch.n_valid > 10000)]
main = sub_dp[sub_dp.mean_q >= 0.9 * sub_dp.mean_q.max()].copy()   # main-stem cells
o = OUTLETS["Dhok Pathan"]
main["dist"] = np.hypot(main.cell_lat - o.outlet_lat, main.cell_lon - o.outlet_lon)
dp = main.dist.idxmin()                                             # main-stem cell nearest the outlet
ch.loc[dp, "chosen"] = True
spec = ch.loc[dp, "mean_q"] / OUTLETS["Dhok Pathan"].area_km2  # basin-mean specific discharge m3 s-1 km-2
# Chirah: cell whose mean flow is closest (log scale) to specific discharge x delineated Chirah area
sub = ch[(ch.outlet == "Chirah") & (ch.n_valid > 10000) & (ch.mean_q > 0)]
expected = spec * OUTLETS["Chirah"].area_km2
ch.loc[(np.log(sub.mean_q / expected)).abs().idxmin(), "chosen"] = True
ch["expected_q_from_specific_runoff"] = np.where(ch.outlet == "Chirah", expected, np.nan)
series = {r.outlet: cand[(r.outlet, r.cell_lat, r.cell_lon)] for r in ch[ch.chosen].itertuples()}
print(ch[ch.chosen].round(3).to_string())
ch.to_csv(OUT / "glofas_cell_choice.csv", index=False)
df = pd.DataFrame(series)
df.index.name = "date"
df.to_csv(OUT / "glofas_discharge_daily.csv", float_format="%.3f")
print(df.describe().round(2))
