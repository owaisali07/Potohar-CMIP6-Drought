"""Step 1f - MODIS Terra MOD13Q1 (NDVI, 250 m, 16-day) and MOD11A2 (daytime LST, 1 km, 8-day), collection 6.1,
2000-2024, for the Potohar Plateau, read from Microsoft Planetary Computer cloud-optimised GeoTIFFs (open access;
LP DAAC data, Didan 2021; Wan et al. 2021).

Quality screening: NDVI pixel_reliability in {0 good, 1 marginal}; LST QC_Day bits0-1 in {00, 01} and LST error
bits6-7 <= 01 (<= 2 K). Each composite is reprojected (average) from the MODIS sinusoidal grid to a 0.01 deg
lat/lon grid (71.50-74.00 E, 32.25-34.25 N), tiles h23v05 + h24v05 mosaicked.
Monthly products: NDVI = maximum of the 16-day composites in the month (maximum-value compositing);
LST = mean of the 8-day composites in the month (degC).
Output: 02_obs_preprocess/modis_monthly_0p01.nc
"""
import os
import re
import time

os.environ.update(GDAL_HTTP_TIMEOUT="60", GDAL_HTTP_CONNECTTIMEOUT="30", GDAL_HTTP_MAX_RETRY="5",
                  GDAL_HTTP_RETRY_DELAY="5", GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR")
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pandas as pd
import planetary_computer
import pystac_client
import rasterio
import xarray as xr
import yaml
from rasterio.warp import Resampling, reproject, transform_bounds
from rasterio.windows import from_bounds

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
OUT = ROOT / "02_obs_preprocess"
W, E, S, N = 71.50, 74.00, 32.25, 34.25
RES = 0.01
NX, NY = int(round((E - W) / RES)), int(round((N - S) / RES))
DST_T = rasterio.transform.from_origin(W, N, RES, RES)
DST_CRS = "EPSG:4326"
CAT = pystac_client.Client.open("https://planetarycomputer.microsoft.com/api/stac/v1",
                                modifier=planetary_computer.sign_inplace)


def items(col, prefix):
    out = []
    for y in range(2000, 2025):
        s = CAT.search(collections=[col], bbox=[W, S, E, N], datetime=f"{y}-01-01/{y}-12-31")
        out += [i for i in s.items() if i.id.startswith(prefix)]
    return out


def read_reproject(href, qhref, kind):
    for k in range(5):
        try:
            with rasterio.open(planetary_computer.sign(href)) as src:
                b = transform_bounds(DST_CRS, src.crs, W, S, E, N)
                win = from_bounds(*b, transform=src.transform).round_offsets().round_lengths()
                win = win.intersection(rasterio.windows.Window(0, 0, src.width, src.height))
                a = src.read(1, window=win).astype("f4")
                tr = src.window_transform(win)
                crs = src.crs
            with rasterio.open(planetary_computer.sign(qhref)) as qs:
                q = qs.read(1, window=win)
            break
        except Exception:  # noqa: BLE001
            if k == 4:
                raise
            time.sleep(10 * (k + 1))
    if kind == "ndvi":
        a = np.where((a > -2000) & np.isin(q, [0, 1]), a * 1e-4, np.nan)
    else:
        good = ((q & 0b11) <= 1) & (((q >> 6) & 0b11) <= 1)
        a = np.where((a > 0) & good, a * 0.02 - 273.15, np.nan)
    dst = np.full((NY, NX), np.nan, "f4")
    reproject(a, dst, src_transform=tr, src_crs=crs, dst_transform=DST_T, dst_crs=DST_CRS,
              resampling=Resampling.average, src_nodata=np.nan, dst_nodata=np.nan)
    return dst


def run(col, prefix, asset, qasset, kind):
    its = items(col, prefix)
    print(col, len(its), "items", flush=True)
    comp = defaultdict(lambda: np.full((NY, NX), np.nan, "f4"))
    with ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(read_reproject, i.assets[asset].href, i.assets[qasset].href, kind): i for i in its}
        for n, f in enumerate(as_completed(futs), 1):
            i = futs[f]
            d = re.search(r"\.A(\d{7})\.", i.id).group(1)
            date = pd.Timestamp(int(d[:4]), 1, 1) + pd.Timedelta(days=int(d[4:]) - 1)
            arr = f.result()
            comp[date] = np.fmax(comp[date], arr)  # mosaic h23v05/h24v05 (no overlap)
            if n % 200 == 0:
                print(f"  {n}/{len(its)}", flush=True)
    dates = sorted(comp)
    da = xr.DataArray(np.stack([comp[d] for d in dates]), dims=("time", "lat", "lon"),
                      coords=dict(time=dates, lat=N - RES / 2 - RES * np.arange(NY), lon=W + RES / 2 + RES * np.arange(NX)))
    return da


def cached_run(name, *a):
    f = OUT / f"_modis_{name}_composites.nc"
    if f.exists():
        return xr.open_dataarray(f).load()
    da = run(*a)
    da.rename(name).to_netcdf(f)
    return da


ndvi = cached_run("ndvi", "modis-13Q1-061", "MOD13Q1", "250m_16_days_NDVI", "250m_16_days_pixel_reliability", "ndvi")
lst = cached_run("lst", "modis-11A2-061", "MOD11A2", "LST_Day_1km", "QC_Day", "lst")
ndvi_m = ndvi.resample(time="MS").max()
lst_m = lst.resample(time="MS").mean()
ds = xr.Dataset(dict(ndvi=ndvi_m, lst=lst_m))
ds["time"] = ds.time + pd.Timedelta(days=14)
ds.ndvi.attrs.update(units="1", long_name="MOD13Q1 v061 NDVI, monthly maximum of 16-day composites")
ds.lst.attrs.update(units="degC", long_name="MOD11A2 v061 daytime LST, monthly mean of 8-day composites")
ds.attrs.update(Conventions="CF-1.8", source="Microsoft Planetary Computer modis-13Q1-061 / modis-11A2-061 (NASA LP DAAC)")
ds = ds.sortby("lat")
ds.to_netcdf(OUT / "modis_monthly_0p01.nc", encoding={v: {"zlib": True, "complevel": 4} for v in ds.data_vars})
print(ds)
