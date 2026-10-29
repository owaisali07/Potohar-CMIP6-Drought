"""Step 1k (v2) - Download every GSOD/ISD and GHCN-Daily station within 100 km of the four districts + ICT, and
the daily CHIRPS / ERA5-Land values at each station (Google Earth Engine) for quantile-mapping gap filling.
Download only: parsing, QC, completeness screening and gap filling are done in Potohar_Drought_Analysis.Rmd.

Outputs (data_raw/stations_v2/):
  isd-history.csv, ghcnd-stations.txt, candidate_stations.csv
  gsod/{year}/{USAF}{WBAN}.csv          raw NCEI GSOD files 1981-2024
  ghcnd/{ID}.csv.gz                     raw GHCN-Daily by-station files
  gee_points/{station_key}.csv          daily CHIRPS pr + ERA5-Land (DAILY_AGGR) tmax, tmin, pr, dewpoint, u10, v10
"""
import io
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import ee
import geopandas as gpd
import pandas as pd
import requests
import yaml
from shapely.geometry import Point

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
OUT = Path(CFG["paths"]["raw"]) / "stations_v2"
(OUT / "gsod").mkdir(parents=True, exist_ok=True); (OUT / "ghcnd").mkdir(exist_ok=True); (OUT / "gee_points").mkdir(exist_ok=True)
H = {"User-Agent": "Mozilla/5.0 (research; Paper6 Potohar drought)"}
Y0, Y1 = 1981, 2024


def get(url, dest=None, tries=5, ok404=True):
    for k in range(tries):
        try:
            r = requests.get(url, headers=H, timeout=120)
            if r.status_code == 404 and ok404:
                return None
            r.raise_for_status()
            if dest:
                Path(dest).write_bytes(r.content)
            return r.content
        except Exception:  # noqa: BLE001
            time.sleep(5 * (k + 1))
    return None


# ---------------- candidate stations within 100 km ----------------
union = gpd.read_file(ROOT / "01_boundaries" / "potohar_districts.gpkg", layer="union").to_crs(32643)
buf = union.buffer(100_000).iloc[0]
if not (OUT / "isd-history.csv").exists():
    get("https://www.ncei.noaa.gov/pub/data/noaa/isd-history.csv", OUT / "isd-history.csv")
if not (OUT / "ghcnd-stations.txt").exists():
    get("https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-stations.txt", OUT / "ghcnd-stations.txt")
isd = pd.read_csv(OUT / "isd-history.csv", dtype=str).dropna(subset=["LAT", "LON"])
isd = isd[(isd.LAT.astype(float).between(30, 37)) & (isd.LON.astype(float).between(69, 77))]
isd = isd[isd["END"].astype(int) >= 19850101]
pts = gpd.GeoSeries([Point(float(x), float(y)) for x, y in zip(isd.LON, isd.LAT)], crs=4326).to_crs(32643)
isd = isd[pts.within(buf).values].copy()
isd["key"] = isd.USAF + isd.WBAN
rows = []
for _, s in isd.iterrows():
    rows.append(dict(source="GSOD", key=s.key, name=s["STATION NAME"], ctry=s.CTRY, lat=float(s.LAT), lon=float(s.LON),
                     elev=float(s["ELEV(M)"]) if s["ELEV(M)"] else None, begin=s.BEGIN, end=s.END))
gh = []
for line in (OUT / "ghcnd-stations.txt").read_text(errors="ignore").splitlines():
    lat, lon = float(line[12:20]), float(line[21:30])
    if 30 <= lat <= 37 and 69 <= lon <= 77:
        gh.append((line[0:11], lat, lon, float(line[31:37]), line[41:71].strip()))
for gid, lat, lon, el, nm in gh:
    if gpd.GeoSeries([Point(lon, lat)], crs=4326).to_crs(32643).within(buf).iloc[0]:
        rows.append(dict(source="GHCN-D", key=gid, name=nm, ctry=gid[:2], lat=lat, lon=lon, elev=el, begin="", end=""))
cand = pd.DataFrame(rows)
cand["dist_km"] = [round(union.distance(gpd.GeoSeries([Point(r.lon, r.lat)], crs=4326).to_crs(32643).iloc[0]).iloc[0] / 1000, 1)
                   for r in cand.itertuples()]
cand.to_csv(OUT / "candidate_stations.csv", index=False)
print(cand.groupby("source").size(), flush=True)

# ---------------- GSOD yearly files ----------------
jobs = [(k, y) for k in cand[cand.source == "GSOD"].key for y in range(Y0, Y1 + 1)]


def gsod(j):
    k, y = j
    d = OUT / "gsod" / str(y); d.mkdir(exist_ok=True)
    f = d / f"{k}.csv"
    if f.exists():
        return 1
    return 1 if get(f"https://www.ncei.noaa.gov/data/global-summary-of-the-day/access/{y}/{k}.csv", f) else 0


with ThreadPoolExecutor(8) as ex:
    n = sum(ex.map(gsod, jobs))
print("GSOD station-years:", n, flush=True)

# ---------------- GHCN-D by station ----------------
for k in cand[cand.source == "GHCN-D"].key:
    f = OUT / "ghcnd" / f"{k}.csv.gz"
    if not f.exists():
        get(f"https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/{k}.csv.gz", f)
print("GHCN-D files:", len(list((OUT / "ghcnd").glob("*.gz"))), flush=True)

# ---------------- GEE daily series at stations ----------------
ee.Initialize(project="eighth-effect-409505")
E5 = ["temperature_2m_max", "temperature_2m_min", "total_precipitation_sum", "dewpoint_temperature_2m",
      "u_component_of_wind_10m", "v_component_of_wind_10m"]


def gee_point(r):
    dest = OUT / "gee_points" / f"{r.source}_{r.key}.csv"
    if dest.exists():
        return
    pt = ee.Geometry.Point([r.lon, r.lat])
    frames = []
    for y in range(Y0, Y1 + 1):
        for k in range(5):
            try:
                e5 = ee.ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR").filterDate(f"{y}-01-01", f"{y + 1}-01-01").select(E5)
                ch = ee.ImageCollection("UCSB-CHG/CHIRPS/DAILY").filterDate(f"{y}-01-01", f"{y + 1}-01-01").select("precipitation")
                a = e5.getRegion(pt, 11132).getInfo(); b = ch.getRegion(pt, 5566).getInfo()
                da = pd.DataFrame(a[1:], columns=a[0]); db = pd.DataFrame(b[1:], columns=b[0])
                da["date"] = pd.to_datetime(da.time, unit="ms").dt.normalize(); db["date"] = pd.to_datetime(db.time, unit="ms").dt.normalize()
                frames.append(da[["date"] + E5].merge(db[["date", "precipitation"]].rename(columns={"precipitation": "chirps_pr"}), on="date", how="outer"))
                break
            except Exception:  # noqa: BLE001
                time.sleep(10 * (k + 1))
    pd.concat(frames).sort_values("date").to_csv(dest, index=False)


with ThreadPoolExecutor(6) as ex:
    list(ex.map(gee_point, cand.itertuples()))
print("GEE point files:", len(list((OUT / "gee_points").glob("*.csv"))))
