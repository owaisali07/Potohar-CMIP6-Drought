"""Step 2a - Build daily station records for stations in and around the Potohar Plateau.

PMD records are not openly available (DEVIATIONS D4). Daily data come from:
  * NOAA GSOD (open; raw CSVs downloaded from NCEI by Paper 3, read-only): TMAX, TMIN, TEMP, DEWP, WDSP, PRCP
  * GHCN-Daily (open, Table II): PRCP, TMAX, TMIN (quality-flagged values dropped)
Units converted to SI (degC, m/s, mm). GSOD missing codes (9999.9, 999.9, 99.99) -> NaN.
GSOD PRCP flag 'I' (incomplete daily total) is kept but flagged.
Output: 02_obs_preprocess/stations_daily.csv, stations_meta.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
ST = Path(r"D:\Papers\Paper 3\Paper1_Seasonal_Clock\data\stations")
OUT = ROOT / "02_obs_preprocess"
OUT.mkdir(exist_ok=True)

# stations in / around the plateau (lon 71.2-74.2, lat 31.9-34.5) with >=10 years of record
STATIONS = {  # GSOD id : (name, GHCN-D id, role)
    "41571099999": ("Islamabad-Chaklala", "PKM00041571", "plateau"),
    "41598099999": ("Jhelum", "PKM00041598", "plateau"),
    "41573099999": ("Murree", None, "plateau (Murree hills, Soan headwaters)"),
    "41535099999": ("Kakul", None, "surrounding"),
    "41530099999": ("Peshawar", "PKM00041530", "surrounding"),
    "41594099999": ("Sargodha", "PKM00041594", "surrounding"),
    "41536099999": ("Balakot", None, "surrounding"),
}
Y0, Y1 = 1981, 2024


def gsod(sid):
    frames = []
    for y in range(Y0, Y1 + 1):
        f = ST / "gsod" / "raw" / str(y) / f"{sid}.csv"
        if f.exists():
            frames.append(pd.read_csv(f, dtype=str))
    if not frames:
        return None
    d = pd.concat(frames)
    num = lambda c, miss: pd.to_numeric(d[c].str.strip(), errors="coerce").where(lambda s: s < miss)  # noqa: E731
    out = pd.DataFrame({
        "date": pd.to_datetime(d["DATE"]),
        "tmax": (num("MAX", 9999) - 32) / 1.8,
        "tmin": (num("MIN", 9999) - 32) / 1.8,
        "tmean": (num("TEMP", 9999) - 32) / 1.8,
        "tdew": (num("DEWP", 9999) - 32) / 1.8,
        "wind10": num("WDSP", 999) * 0.514444,
        "prcp_gsod": num("PRCP", 99.9) * 25.4,
        "prcp_gsod_flag": d["PRCP_ATTRIBUTES"].str.strip(),
        "tmax_from_hourly": d["MAX_ATTRIBUTES"].str.strip() == "*",
        "lat": pd.to_numeric(d["LATITUDE"]), "lon": pd.to_numeric(d["LONGITUDE"]), "elev": pd.to_numeric(d["ELEVATION"]),
    })
    return out.drop_duplicates("date").set_index("date")


def ghcn(gid):
    f = ST / "ghcnd" / "raw_by_station" / f"{gid}.csv"
    if gid is None or not f.exists():
        return None
    d = pd.read_csv(f, header=None, names=["id", "date", "el", "val", "m", "q", "s", "t"], dtype={"date": str, "q": str})
    d = d[d.el.isin(["PRCP", "TMAX", "TMIN"]) & d.q.isna()]
    d["date"] = pd.to_datetime(d.date)
    w = d.pivot_table(index="date", columns="el", values="val", aggfunc="first") / 10.0
    return w.rename(columns={"PRCP": "prcp_ghcn", "TMAX": "tmax_ghcn", "TMIN": "tmin_ghcn"})


rows, meta = [], []
for sid, (name, gid, role) in STATIONS.items():
    g = gsod(sid)
    if g is None:
        continue
    h = ghcn(gid)
    idx = pd.date_range(f"{Y0}-01-01", f"{Y1}-12-31", freq="D")
    d = g.reindex(idx)
    if h is not None:
        d = d.join(h.reindex(idx))
    lat, lon, elev = g.lat.dropna().iloc[-1], g.lon.dropna().iloc[-1], g.elev.dropna().iloc[-1]
    d = d.drop(columns=["lat", "lon", "elev"])
    # physical QC (WMO/GSOD-style gross-error checks)
    for c in ("tmax", "tmin", "tmean", "tmax_ghcn", "tmin_ghcn"):
        if c in d:
            d.loc[(d[c] < -25) | (d[c] > 52), c] = np.nan
    bad = d.tmax < d.tmin
    d.loc[bad, ["tmax", "tmin"]] = np.nan
    for c in ("prcp_gsod", "prcp_ghcn"):
        if c in d:
            d.loc[(d[c] < 0) | (d[c] > 400), c] = np.nan
    d.loc[(d.wind10 < 0) | (d.wind10 > 40), "wind10"] = np.nan
    d.loc[d.tdew > d.tmax + 1, "tdew"] = np.nan
    d.insert(0, "station", name)
    d.index.name = "date"
    rows.append(d.reset_index())
    comp = lambda c: float(d[c].notna().mean()) if c in d else 0.0  # noqa: E731
    meta.append(dict(station=name, gsod_id=sid, ghcn_id=gid or "", role=role, lat=lat, lon=lon, elev_m=elev,
                     frac_tmax=comp("tmax"), frac_tmin=comp("tmin"), frac_tdew=comp("tdew"), frac_wind=comp("wind10"),
                     frac_prcp_gsod=comp("prcp_gsod"), frac_prcp_ghcn=comp("prcp_ghcn"),
                     frac_prcp_gsod_flagI=float((d.prcp_gsod_flag == "I").mean())))
pd.concat(rows).to_csv(OUT / "stations_daily.csv", index=False, float_format="%.2f")
m = pd.DataFrame(meta)
m.to_csv(OUT / "stations_meta.csv", index=False)
pd.set_option("display.width", 220)
print(m.round(3).to_string())
