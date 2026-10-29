"""Step 2e - Land cover and crop layers for exposure (Methodology III-F) and yield validation (III-D).

* ESA WorldCover 2021 v200 (10 m): exact class fractions on a 0.01 deg grid (71.50-74.00 E, 32.25-34.25 N), computed
  from full-resolution pixels (120 x 120 WorldCover pixels per 0.01 deg cell).
* SPAM2010 v2r0 physical area (ha, 5 arc-min): wheat and groundnut, rainfed (R) and all technologies (A).
* GDHY v1.2+v1.3 wheat yield (t/ha, 0.5 deg, 1981-2016): extracted for the Potohar box.
Outputs: 10_exposure/worldcover_fractions_0p01.tif (one band per class), spam2010_potohar.tif, gdhy_wheat_potohar.nc
"""
from pathlib import Path

import numpy as np
import rasterio
import xarray as xr
import yaml
from rasterio.windows import from_bounds

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
RAW = Path(CFG["paths"]["raw"])
OUT = ROOT / "10_exposure"
OUT.mkdir(exist_ok=True)
W, E, S, N = 71.50, 74.00, 32.25, 34.25
RES = 0.01
NX, NY = int(round((E - W) / RES)), int(round((N - S) / RES))
CLASSES = {10: "tree", 20: "shrub", 30: "grass", 40: "cropland", 50: "built", 60: "bare", 70: "snow", 80: "water",
           90: "herb_wetland", 95: "mangrove", 100: "moss"}
cnt = np.zeros((len(CLASSES), NY, NX), "f8")
tot = np.zeros((NY, NX), "f8")
for f in sorted((RAW / "worldcover").glob("*.tif")):
    with rasterio.open(f) as src:
        l, b, r, t = src.bounds
        bw, bs, be, bn = max(W, l), max(S, b), min(E, r), min(N, t)
        if bw >= be or bs >= bn:
            continue
        win = from_bounds(bw, bs, be, bn, src.transform).round_offsets().round_lengths()
        k = int(round(RES / src.res[0]))  # 120
        a = src.read(1, window=win)
        h, w = (a.shape[0] // k) * k, (a.shape[1] // k) * k
        a = a[:h, :w]
        r0 = int(round((N - bn) / RES)); c0 = int(round((bw - W) / RES))
        for i, cl in enumerate(CLASSES):
            blk = (a == cl).reshape(h // k, k, w // k, k).sum(axis=(1, 3))
            cnt[i, r0:r0 + h // k, c0:c0 + w // k] += blk
        tot[r0:r0 + h // k, c0:c0 + w // k] += k * k
        print(f.name, a.shape, flush=True)
frac = np.where(tot > 0, cnt / np.maximum(tot, 1), np.nan).astype("f4")
prof = dict(driver="GTiff", height=NY, width=NX, count=len(CLASSES), dtype="float32", crs="EPSG:4326",
            transform=rasterio.transform.from_origin(W, N, RES, RES), compress="deflate", nodata=np.nan)
with rasterio.open(OUT / "worldcover_fractions_0p01.tif", "w", **prof) as o:
    o.write(frac)
    o.descriptions = tuple(CLASSES.values())
print("cropland fraction mean:", float(np.nanmean(frac[3])))

# SPAM2010 physical area
layers = ["WHEA_R", "WHEA_A", "GROU_R", "GROU_A"]
arrs = []
for L in layers:
    with rasterio.open(RAW / "spam2010" / f"spam2010V2r0_global_A_{L}.tif") as src:
        win = from_bounds(W, S, E, N, src.transform).round_offsets().round_lengths()
        a = src.read(1, window=win).astype("f4")
        a[a < 0] = 0
        tr = src.window_transform(win)
        arrs.append(a)
prof = dict(driver="GTiff", height=arrs[0].shape[0], width=arrs[0].shape[1], count=4, dtype="float32", crs="EPSG:4326",
            transform=tr, compress="deflate")
with rasterio.open(OUT / "spam2010_potohar.tif", "w", **prof) as o:
    o.write(np.stack(arrs))
    o.descriptions = tuple(f"{L}_phys_area_ha" for L in layers)
print({L: float(a.sum()) for L, a in zip(layers, arrs)})

# GDHY wheat
das = []
for y in range(1981, 2017):
    d = xr.open_dataset(RAW / "gdhy" / "wheat" / f"yield_{y}.nc4")
    v = list(d.data_vars)[0]
    x = d[v]
    if float(x.lon.max()) > 180:
        x = x.assign_coords(lon=((x.lon + 180) % 360) - 180).sortby("lon")
    x = x.sortby("lat").sel(lat=slice(31.5, 35.0), lon=slice(70.5, 75.0)).load().expand_dims(year=[y])
    das.append(x.rename("wheat_yield"))
g = xr.concat(das, "year")
g.attrs.update(units="t ha-1", source="GDHY v1.2+v1.3 (Iizumi & Sakai 2020), wheat")
g.to_netcdf(OUT / "gdhy_wheat_potohar.nc")
print(g.mean(["lat", "lon"]).values.round(2))
