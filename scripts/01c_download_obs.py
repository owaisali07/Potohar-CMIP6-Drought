"""Step 1c - Download open observational / auxiliary datasets for the Potohar domain.

Sub-commands (run any subset):  python 01c_download_obs.py terraclimate cru worldcover dem30 dem90 spam gdhy gwl bulletins speibase
Every global file is cut to config domain.download_bbox and the global copy deleted. Resumable.
Sources (all open, no login):
  TerraClimate  climate.northwestknowledge.net/TERRACLIMATE-DATA (per-year global files)       [Table II, ERA5-Land alternative]
  CRU TS 4.10   crudata.uea.ac.uk (decadal .nc.gz)                                                [Table I]
  WorldCover    esa-worldcover.s3.eu-central-1.amazonaws.com v200/2021                             [Table I]
  Copernicus DEM copernicus-dem-30m / -90m AWS open buckets                                        [Table II]
  SPAM2010 v2r0 Harvard Dataverse doi:10.7910/DVN/PRFF8V (physical area GeoTIFF)                  [Table II]
  GDHY v1.2+1.3 PANGAEA doi:10.1594/PANGAEA.909132                                                 [Table II]
  GWL tables    github.com/mathause/cmip_warming_levels (Hauser et al.)                            [III-F]
  PMD/NDMC bulletins ndmc.pmd.gov.pk/new/assets/bulletins/*.pdf (those reachable)                 [IV]
"""
import gzip
import shutil
import sys
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests
import xarray as xr
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
RAW = Path(CFG["paths"]["raw"])
W, E, S, N = CFG["domain"]["download_bbox"]
H = {"User-Agent": "Mozilla/5.0 (research download; Paper6 Potohar drought)"}
Y0, Y1 = CFG["periods"]["obs"]


def dl(url, dest, tries=6, chunk=1 << 20):
    dest = Path(dest)
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    for k in range(tries):
        try:
            with requests.get(url, stream=True, timeout=300, headers=H) as r:
                r.raise_for_status()
                tmp = dest.with_suffix(dest.suffix + ".part")
                with open(tmp, "wb") as f:
                    for b in r.iter_content(chunk):
                        f.write(b)
            tmp.replace(dest)
            return dest
        except Exception as e:  # noqa: BLE001
            if k == tries - 1:
                raise RuntimeError(f"{url}: {e}")
            time.sleep(10 * (k + 1))


def cut_nc(src, dest, latname="lat", lonname="lon"):
    with xr.open_dataset(src) as ds:
        lat = ds[latname]
        ls = slice(N, S) if lat[0] > lat[-1] else slice(S, N)
        sub = ds.sel({latname: ls, lonname: slice(W, E)}).load()
    enc = {v: {"zlib": True, "complevel": 4} for v in sub.data_vars}
    sub.to_netcdf(dest, encoding=enc)


# ------------------------------------------------------------------ TerraClimate
def terraclimate():
    out = RAW / "terraclimate"
    out.mkdir(parents=True, exist_ok=True)
    jobs = [(v, y) for v in ("tmax", "tmin", "vap", "srad", "ws", "pet", "ppt") for y in range(Y0, Y1 + 1)]

    from concurrent.futures import ProcessPoolExecutor  # HDF5 is not thread-safe -> one process per read
    with ProcessPoolExecutor(4) as ex:
        list(ex.map(_tc_one, [(v, y, str(out)) for v, y in jobs]))
    print("terraclimate files:", len(list(out.glob("*_potohar.nc"))))


def _tc_one(j):
    """HTTP range reads of only the chunks covering the box (files are HDF5, chunks 1080 x 2160)."""
    import aiohttp
    import fsspec
    v, y, out = j
    dest = Path(out) / f"TerraClimate_{v}_{y}_potohar.nc"
    if dest.exists():
        return
    url = f"https://climate.northwestknowledge.net/TERRACLIMATE-DATA/TerraClimate_{v}_{y}.nc"
    for k in range(6):
        try:
            with fsspec.open(url, "rb", block_size=2**18,
                             client_kwargs={"timeout": aiohttp.ClientTimeout(total=600, sock_read=120)}) as fo:
                with xr.open_dataset(fo, engine="h5netcdf") as ds:
                    sub = ds[[v]].sel(lat=slice(N, S), lon=slice(W, E)).load()
            # source global attributes contain invalid surrogate characters -> replace by a citation note
            sub.attrs = {"source": f"TerraClimate v1.1 (Abatzoglou et al. 2018), {url}, subset {W}-{E}E {S}-{N}N"}
            tmp = dest.with_suffix(".tmp.nc")
            sub.to_netcdf(tmp, encoding={v: {"zlib": True, "complevel": 4}})
            tmp.replace(dest)
            return
        except Exception:  # noqa: BLE001
            if k == 5:
                raise
            time.sleep(15 * (k + 1))


# ------------------------------------------------------------------ CRU TS 4.10
def cru():
    out = RAW / "cru_ts410"
    out.mkdir(parents=True, exist_ok=True)
    base = "https://crudata.uea.ac.uk/cru/data/hrg/cru_ts_4.10/cruts.2604091129.v4.10"
    decs = [(1981, 1990), (1991, 2000), (2001, 2010), (2011, 2020), (2021, 2025)]
    for v in ("pre", "tmp", "tmn", "tmx", "pet", "vap"):
        for a, b in decs:
            dest = out / f"cru_ts4.10.{a}.{b}.{v}_potohar.nc"
            if dest.exists():
                continue
            gz = dl(f"{base}/{v}/cru_ts4.10.{a}.{b}.{v}.dat.nc.gz", out / f"_{v}_{a}.nc.gz")
            nc = gz.with_suffix("")
            with gzip.open(gz) as fi, open(nc, "wb") as fo:
                shutil.copyfileobj(fi, fo)
            cut_nc(nc, dest)
            gz.unlink(); nc.unlink()
    print("cru files:", len(list(out.glob("*_potohar.nc"))))


# ------------------------------------------------------------------ ESA WorldCover 2021 v200
def worldcover():
    out = RAW / "worldcover"
    for t in ("N30E069", "N30E072", "N33E069", "N33E072"):
        dl(f"https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_{t}_Map.tif",
           out / f"ESA_WorldCover_10m_2021_v200_{t}_Map.tif")
    print("worldcover ok")


# ------------------------------------------------------------------ Copernicus DEM
def dem(res):
    out = RAW / f"copdem_glo{res}"
    tag = "10" if res == 30 else "30"
    bucket = f"https://copernicus-dem-{res}m.s3.amazonaws.com"
    lats = range(31, 35) if res == 90 else range(32, 34)
    lons = range(71, 75) if res == 90 else range(72, 74)
    for la in lats:
        for lo in lons:
            name = f"Copernicus_DSM_COG_{tag}_N{la:02d}_00_E{lo:03d}_00_DEM"
            dl(f"{bucket}/{name}/{name}.tif", out / f"{name}.tif")
    print(f"dem{res} ok")


# ------------------------------------------------------------------ SPAM2010
def spam():
    out = RAW / "spam2010"
    z = dl("https://dataverse.harvard.edu/api/access/datafile/3985010", out / "spam2010v2r0_global_phys_area.geotiff.zip")
    with zipfile.ZipFile(z) as zf:
        for n in zf.namelist():
            if any(k in n for k in ("_WHEA_", "_GROU_")) and n.endswith(".tif"):
                zf.extract(n, out)
    print("spam ok:", [p.name for p in out.rglob("*.tif")])


# ------------------------------------------------------------------ GDHY
def gdhy():
    out = RAW / "gdhy"
    z = dl("https://store.pangaea.de/Publications/IizumiT_2019/gdhy_v1.2_v1.3_20190128.zip", out / "gdhy_v1.2_v1.3_20190128.zip")
    with zipfile.ZipFile(z) as zf:
        zf.extractall(out)
    print("gdhy ok")


# ------------------------------------------------------------------ GWL crossing years (Hauser et al.)
def gwl():
    base = "https://raw.githubusercontent.com/mathause/cmip_warming_levels/main/warming_levels"
    for f in ("cmip6_all_ens/csv/cmip6_warming_levels_all_ens_1850_1900.csv", "cmip6/csv/cmip6_warming_levels_one_ens_1850_1900.csv"):
        dl(f"{base}/{f}", RAW / "gwl" / Path(f).name)
    dl("https://raw.githubusercontent.com/mathause/cmip_warming_levels/main/README.md", RAW / "gwl" / "README.md")
    print("gwl ok")


# ------------------------------------------------------------------ PMD/NDMC drought bulletins (reachable PDFs)
def bulletins():
    ids = ["1617864517", "1628229469", "1633087345", "1635848103", "1638516184", "1641293841", "1654155872",
           "1702641767", "1704800161", "1715326620"]
    ok = 0
    for i in ids:
        try:
            dl(f"https://ndmc.pmd.gov.pk/new/assets/bulletins/{i}.pdf", RAW / "pmd_bulletins" / f"{i}.pdf", tries=3); ok += 1
        except Exception as e:  # noqa: BLE001
            print("bulletin fail", i, e)
    print("bulletins ok:", ok)


TASKS = dict(terraclimate=terraclimate, cru=cru, worldcover=worldcover, dem30=lambda: dem(30), dem90=lambda: dem(90),
             spam=spam, gdhy=gdhy, gwl=gwl, bulletins=bulletins)

if __name__ == "__main__":
    rc = 0
    for t in sys.argv[1:]:
        try:
            print(f"== {t}", flush=True); TASKS[t]()
        except Exception as e:  # noqa: BLE001
            print(f"!! {t} failed: {e}", flush=True); rc = 1
    sys.exit(rc)

