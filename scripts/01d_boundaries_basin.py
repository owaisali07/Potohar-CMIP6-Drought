"""Step 1d - Study-area boundaries and Soan basin delineation (Methodology II-A; Table II Copernicus DEM).

* Districts: OCHA COD-AB admin-2 (2022): Attock, Chakwal, Jhelum, Rawalpindi + Islamabad Capital Territory.
* Soan basin: D8 delineation on Copernicus DEM GLO-30 (pits/depressions filled, flats resolved, pysheds).
  Outlets (WAPDA gauge coordinates are not published):
    - Dhok Pathan: Soan main-stem cell of maximum flow accumulation within 3 km of Dhok Pathan
      (33.120 N, 72.338 E); checked against the published 6,475 km2.
    - Chirah: the main-stem cell 13.9 km downstream (along the D8 path) of Simly Dam (33.719 N, 73.339 E),
      the published dam-to-gauge distance; checked against the published ~355 km2 (137 mi2).
    - Makhad (whole basin): last Soan cell before the Indus confluence (GLO-90), checked against 6,842 km2.
Outputs (EPSG:4326): 01_boundaries/potohar_districts.gpkg, soan_basins.gpkg, soan_rivers.gpkg,
                     dem_glo90_potohar.tif, basin_areas.csv
"""
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio

if not hasattr(np, "in1d"):  # pysheds 0.4 still calls np.in1d (removed in NumPy 2)
    np.in1d = np.isin
from pysheds.grid import Grid
from rasterio.merge import merge
from shapely.geometry import LineString, Point, shape
from shapely.ops import unary_union
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
RAW = Path(CFG["paths"]["raw"])
OUT = ROOT / "01_boundaries"
OUT.mkdir(exist_ok=True)
DIRMAP = (64, 128, 1, 2, 4, 8, 16, 32)
STEP = {64: (-1, 0), 128: (-1, 1), 1: (0, 1), 2: (1, 1), 4: (1, 0), 8: (1, -1), 16: (0, -1), 32: (-1, -1)}  # (drow, dcol)

# ---------------------------------------------------------------- districts
adm = gpd.read_file(CFG["paths"]["boundaries"])
names = CFG["domain"]["districts"]
d = adm[adm.adm2_name.isin(names) & adm.adm1_name.isin(["Punjab", "Islamabad"])][["adm2_name", "adm1_name", "adm2_pcode", "geometry"]]
d = d.rename(columns={"adm2_name": "district", "adm1_name": "province"}).to_crs(4326)
d["district"] = d.district.replace({"Islamabad": "Islamabad (ICT)"})
d["area_km2"] = d.to_crs(32643).area / 1e6
d.to_file(OUT / "potohar_districts.gpkg", layer="districts", driver="GPKG")
gpd.GeoDataFrame(dict(name=["Potohar (4 districts + ICT)"]), geometry=[unary_union(d.geometry)], crs=4326).to_file(
    OUT / "potohar_districts.gpkg", layer="union", driver="GPKG")
nb = adm[adm.intersects(unary_union(d.geometry).buffer(1.0))].to_crs(4326)
nb[["adm2_name", "adm1_name", "geometry"]].to_file(OUT / "potohar_districts.gpkg", layer="neighbours", driver="GPKG")
print(d[["district", "area_km2"]].round(0).to_string())


def mosaic(files, dest):
    srcs = [rasterio.open(f) for f in files]
    arr, tr = merge(srcs)
    prof = srcs[0].profile.copy()
    prof.update(height=arr.shape[1], width=arr.shape[2], transform=tr, driver="GTiff", compress="deflate", tiled=True, count=1)
    with rasterio.open(dest, "w", **prof) as o:
        o.write(arr[0], 1)
    for s in srcs:
        s.close()
    return dest


def hydro(dem_path):
    g = Grid.from_raster(str(dem_path))
    dem = g.read_raster(str(dem_path))
    dem = g.resolve_flats(g.fill_depressions(g.fill_pits(dem)))
    fdir = g.flowdir(dem, dirmap=DIRMAP)
    acc = g.accumulation(fdir, dirmap=DIRMAP)
    return g, fdir, acc


def cell_area_km2(g):
    a = g.affine
    rows = np.arange(g.shape[0])
    lat = a.f + (rows + 0.5) * a.e
    return (abs(a.a) * 111.32 * np.cos(np.radians(lat))) * (abs(a.e) * 110.57)  # km2 per cell, per row


def rc(g, lon, lat):
    c, r = ~g.affine * (lon, lat)
    return int(r), int(c)


def downstream(fdir, r, c, n):
    path = [(r, c)]
    for _ in range(n):
        dr, dc = STEP.get(int(fdir[r, c]), (0, 0))
        if dr == dc == 0:
            break
        r, c = r + dr, c + dc
        path.append((r, c))
    return path


def path_length_km(g, path):
    a = g.affine
    L = 0.0
    for (r0, c0), (r1, c1) in zip(path, path[1:]):
        lat = a.f + (r0 + 0.5) * a.e
        L += np.hypot((c1 - c0) * abs(a.a) * 111.32 * np.cos(np.radians(lat)), (r1 - r0) * abs(a.e) * 110.57)
    return L


def snap_max(g, acc, lon, lat, radius_km):
    r, c = rc(g, lon, lat)
    k = int(radius_km / (abs(g.affine.e) * 110.57))
    win = np.asarray(acc[r - k:r + k + 1, c - k:c + k + 1])
    i, j = np.unravel_index(np.argmax(win), win.shape)
    return r - k + i, c - k + j


def catchment_poly(g, fdir, r, c, name):
    x, y = g.affine * (c + 0.5, r + 0.5)
    cat = g.catchment(x=c, y=r, fdir=fdir, dirmap=DIRMAP, xytype="index")
    mask = np.asarray(cat).astype("uint8")
    area = float((mask * cell_area_km2(g)[:, None]).sum())
    shapes = [shape(s) for s, v in rasterio.features.shapes(mask, transform=g.affine) if v == 1]
    poly = unary_union(shapes)
    return dict(name=name, outlet_lon=x, outlet_lat=y, area_km2=area, geometry=poly), mask


import rasterio.features  # noqa: E402

# ---------------------------------------------------------------- GLO-90 (whole basin to Makhad; maps)
d90 = mosaic(sorted((RAW / "copdem_glo90").glob("*.tif")), OUT / "dem_glo90_potohar.tif")
g9, f9, a9 = hydro(d90)
ca9 = cell_area_km2(g9)
r, c = snap_max(g9, a9, 72.338, 33.120, 3)
path = downstream(f9, r, c, 3000)
areas = [float(a9[p]) * ca9[p[0]] for p in path]
jump = next(i for i in range(1, len(path)) if areas[i] > 2.0 * areas[i - 1])  # entering the Indus
mk = path[jump - 1]
rows = []
rec, _ = catchment_poly(g9, f9, *mk, "Soan at Makhad (Indus confluence), GLO-90")
rows.append(rec)
rec, _ = catchment_poly(g9, f9, r, c, "Soan at Dhok Pathan, GLO-90 (cross-check)")
rows.append(rec)

# ---------------------------------------------------------------- GLO-30 (gauged outlets)
d30 = mosaic(sorted((RAW / "copdem_glo30").glob("*.tif")), OUT / "dem_glo30_soan.tif")
g3, f3, a3 = hydro(d30)
r, c = snap_max(g3, a3, 72.338, 33.120, 3)
rec, mask_dp = catchment_poly(g3, f3, r, c, "Soan at Dhok Pathan, GLO-30")
rows.append(rec)
rs, cs = snap_max(g3, a3, 73.339, 33.719, 1.0)  # Simly Dam outlet on the Soan
path = downstream(f3, rs, cs, 20000)
cum = np.cumsum([0] + [path_length_km(g3, path[i:i + 2]) for i in range(len(path) - 1)])
ch = path[int(np.argmin(np.abs(cum - 13.9)))]
rec, _ = catchment_poly(g3, f3, *ch, "Soan at Chirah (13.9 km below Simly Dam), GLO-30")
rows.append(rec)

bas = gpd.GeoDataFrame(rows, crs=4326)
bas["published_km2"] = [6842, 6475, 6475, 355]  # Makhad: Wikipedia/[4]; Punjab P&D D4 report gives 4,335 mi2 (11,228 km2)
bas["published_km2_alt"] = [11228, np.nan, np.nan, np.nan]
bas["difference_pct"] = 100 * (bas.area_km2 - bas.published_km2) / bas.published_km2
bas.to_file(OUT / "soan_basins.gpkg", driver="GPKG")
bas.drop(columns="geometry").to_csv(OUT / "basin_areas.csv", index=False)
print(bas.drop(columns="geometry").round(3).to_string())

# ---------------------------------------------------------------- river network (GLO-90, >= 50 km2)
thr = 50.0 / np.median(ca9)
streams = g9.extract_river_network(f9, a9 > thr, dirmap=DIRMAP)
riv = gpd.GeoDataFrame.from_features(streams["features"], crs=4326)
riv["order_proxy_km2"] = [float(a9[rc(g9, *ls.coords[-1])]) * np.median(ca9) if True else 0 for ls in riv.geometry]
riv.to_file(OUT / "soan_rivers.gpkg", driver="GPKG")
print("rivers:", len(riv))

