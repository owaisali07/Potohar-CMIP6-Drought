"""Step 1i (v2) - Google Earth Engine downloads (project eighth-effect-409505):

  era5land : ERA5-Land Penman-Monteith inputs, monthly 1981-2024, aggregated by GEE (reduceResolution, mean)
             directly onto the 0.25 deg analysis grid and the 0.05 deg fine grid:
               - dewpoint_temperature_2m, surface_solar_radiation_downwards_sum, surface_pressure  (ECMWF/ERA5_LAND/MONTHLY_AGGR)
               - 10 m wind SPEED = monthly mean of hourly sqrt(u10^2 + v10^2)                     (ECMWF/ERA5_LAND/HOURLY)
                 (the monthly product only has mean u/v components, whose vector mean underestimates speed)
               - temperature_2m_max / _min = monthly mean of daily extremes                       (ECMWF/ERA5_LAND/DAILY_AGGR)
  speibase : CSIC/SPEI/2_10 (SPEIbase v2.10), SPEI-1/3/6/12, 1981-2023, native 0.5 deg box.
  stations : ERA5-Land daily Tmax/Tmin/precip and hourly-derived daily wind & dewpoint at station points (gap filling).

Output: data_raw/gee/*.nc
Usage: python 01i_gee_downloads.py era5land speibase
"""
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import ee
import numpy as np
import pandas as pd
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
OUT = Path(CFG["paths"]["raw"]) / "gee"
OUT.mkdir(parents=True, exist_ok=True)
ee.Initialize(project="eighth-effect-409505")
Y0, Y1 = CFG["periods"]["obs"]
W, E, S, N = CFG["domain"]["download_bbox"]
GRIDS = {"025": (W, N, 0.25, int(round((E - W) / 0.25)), int(round((N - S) / 0.25))),
         "005": (71.5, 34.25, 0.05, 50, 40)}


def fetch(img, grid, bands, tries=6):
    x0, y0, res, nx, ny = grid
    req = {"expression": img.select(bands), "fileFormat": "NUMPY_NDARRAY",
           "grid": {"dimensions": {"width": nx, "height": ny},
                    "affineTransform": {"scaleX": res, "shearX": 0, "translateX": x0, "shearY": 0, "scaleY": -res, "translateY": y0},
                    "crsCode": "EPSG:4326"}}
    for k in range(tries):
        try:
            a = ee.data.computePixels(req)
            return np.stack([a[b] for b in bands], axis=0).astype("f8")
        except Exception as e:  # noqa: BLE001
            if k == tries - 1:
                raise
            time.sleep(10 * (k + 1))


def agg(img, res_deg):
    """Area-weighted mean of the native ERA5-Land 0.1 deg field onto a coarser grid (server side)."""
    if res_deg <= 0.1:
        return img  # 0.05 grid: nearest of the 0.1 field (no information gain from averaging)
    return img.reduceResolution(ee.Reducer.mean(), maxPixels=1024).reproject(ee.Projection("EPSG:4326").scale(res_deg, res_deg))


NATIVE = ee.ImageCollection("ECMWF/ERA5_LAND/MONTHLY_AGGR").first().select(0).projection()


def era5_month(y, m):
    t0 = ee.Date.fromYMD(y, m, 1); t1 = t0.advance(1, "month")
    mon = ee.ImageCollection("ECMWF/ERA5_LAND/MONTHLY_AGGR").filterDate(t0, t1).first()
    hr = ee.ImageCollection("ECMWF/ERA5_LAND/HOURLY").filterDate(t0, t1).select(["u_component_of_wind_10m", "v_component_of_wind_10m"])
    spd = hr.map(lambda i: i.expression("sqrt(u*u+v*v)", {"u": i.select(0), "v": i.select(1)}).rename("wind_speed_10m")).mean()
    day = ee.ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR").filterDate(t0, t1).select(["temperature_2m_max", "temperature_2m_min"]).mean()
    spd = spd.setDefaultProjection(NATIVE); day = day.setDefaultProjection(NATIVE)   # composites lose the native grid
    img = mon.select(["dewpoint_temperature_2m", "surface_solar_radiation_downwards_sum", "surface_pressure",
                      "u_component_of_wind_10m", "v_component_of_wind_10m"]).addBands(spd).addBands(day)
    return img


BANDS = ["dewpoint_temperature_2m", "surface_solar_radiation_downwards_sum", "surface_pressure", "u_component_of_wind_10m",
         "v_component_of_wind_10m", "wind_speed_10m", "temperature_2m_max", "temperature_2m_min"]


def era5land():
    for g, grid in GRIDS.items():
        dest = OUT / f"era5land_pm_inputs_{g}.nc"
        if dest.exists():
            continue
        jobs = [(y, m) for y in range(Y0, Y1 + 1) for m in range(1, 13)]
        res = grid[2]

        def one(j):
            return fetch(agg(era5_month(*j), res), grid, BANDS)

        with ThreadPoolExecutor(8) as ex:
            arrs = list(ex.map(one, jobs))
        a = np.stack(arrs, axis=1)  # band, time, y, x
        x0, y0, r, nx, ny = grid
        lons = np.round(x0 + r / 2 + r * np.arange(nx), 3); lats = np.round(y0 - r / 2 - r * np.arange(ny), 3)
        times = pd.DatetimeIndex([pd.Timestamp(y, m, 15) for y, m in jobs])
        ds = xr.Dataset({b: (("time", "lat", "lon"), a[i]) for i, b in enumerate(BANDS)}, coords=dict(time=times, lat=lats, lon=lons))
        ds.attrs.update(source="ECMWF/ERA5_LAND MONTHLY_AGGR + HOURLY (wind speed) + DAILY_AGGR (Tmax/Tmin) via Google Earth Engine",
                        aggregation="GEE reduceResolution(mean) to the target grid" if res > 0.1 else "nearest 0.1 deg field")
        ds.sortby("lat").to_netcdf(dest)
        print(g, {b: float(np.nanmean(ds[b])) for b in BANDS}, flush=True)


def speibase():
    dest = OUT / "speibase_v2_10_box.nc"
    if dest.exists():
        return
    col = ee.ImageCollection("CSIC/SPEI/2_10").filterDate(f"{Y0}-01-01", "2024-01-01")
    n = col.size().getInfo()
    lst = col.toList(n)
    bands = ["SPEI_01_month", "SPEI_03_month", "SPEI_06_month", "SPEI_12_month"]
    grid = (71.0, 35.0, 0.5, 7, 7)  # 71.0-74.5 E, 31.5-35.0 N at native 0.5 deg

    def one(i):
        img = ee.Image(lst.get(i))
        return fetch(img, grid, bands), img.date().format("YYYY-MM").getInfo()

    with ThreadPoolExecutor(8) as ex:
        out = list(ex.map(one, range(n)))
    a = np.stack([o[0] for o in out], axis=1)
    times = pd.DatetimeIndex([pd.Timestamp(o[1] + "-15") for o in out])
    lons = 71.25 + 0.5 * np.arange(7); lats = 34.75 - 0.5 * np.arange(7)
    ds = xr.Dataset({b.replace("_month", "").lower(): (("time", "lat", "lon"), a[i]) for i, b in enumerate(bands)},
                    coords=dict(time=times, lat=lats, lon=lons)).sortby(["time", "lat"])
    ds.attrs["source"] = "SPEIbase v2.10 (CSIC/SPEI/2_10, Begueria et al.) via Google Earth Engine"
    ds.to_netcdf(dest)
    print("speibase", ds.dims, float(ds.spei_03.mean()))


if __name__ == "__main__":
    for t in sys.argv[1:]:
        globals()[t]()
