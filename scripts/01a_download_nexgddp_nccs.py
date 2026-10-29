"""Step 1a - Download NEX-GDDP-CMIP6 hurs, rsds, sfcWind (v2.0) from NASA NCCS THREDDS (NCSS subset).

Only the Potohar download box (config domain.download_bbox) is requested. pr, tasmax and tasmin are
read from the local NEX-GDDP copy (Paper 3), see DEVIATIONS.md D2. Resumable: existing, readable files
are skipped. A few pr/tasmax files are also fetched (--check) to compare v2.0 with the local v1.x copy.

Usage: python 01a_download_nexgddp_nccs.py [--threads 6] [--check]
v2.1 (Phase B): --out additional --vars pr tasmax tasmin hurs rsds sfcWind --models ... downloads all six variables to
<paths.downscaling_additional>/nexgddp_cmip6/data/<model>/<exp>/ (author instruction) and logs every file with its
SHA-256 in <paths.downscaling_additional>/MANIFEST_sha256.csv.
"""
import argparse
import csv
import hashlib
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import h5py
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
OUT = Path(CFG["paths"]["raw"]) / "nexgddp_nccs"
CAT = "https://ds.nccs.nasa.gov/thredds/catalog/AMES/NEX/GDDP-CMIP6"
NCSS = "https://ds.nccs.nasa.gov/thredds/ncss/grid"
W, E, S, N = CFG["domain"]["download_bbox"]
VARS = ["hurs", "rsds", "sfcWind"]
YEARS = {"historical": range(CFG["periods"]["hist_sim"][0], 2015), "ssp245": range(2015, 2101), "ssp585": range(2015, 2101)}
LOG = Path(CFG["paths"]["root"]) / "logs" / "download_nexgddp_nccs.log"


def get(url, tries=8, binary=False, timeout=120):
    err = None
    for k in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as r:
                data = r.read()
                return data if binary else data.decode()
        except urllib.error.HTTPError as e:
            if e.code in (400, 404):
                raise
            err = e
        except Exception as e:  # noqa: BLE001
            err = e
        time.sleep(min(60, 5 * (k + 1)))
    raise err


MAN = Path(CFG["paths"]["downscaling_additional"]) / "MANIFEST_sha256.csv"
_mlock = __import__("threading").Lock()


def manifest(dest, url):
    h = hashlib.sha256(dest.read_bytes()).hexdigest()
    base = Path(CFG["paths"]["downscaling_additional"])
    with _mlock:
        new = not MAN.exists()
        with open(MAN, "a", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["file", "bytes", "sha256", "source", "note", "logged_utc"])
            w.writerow([str(dest.relative_to(base)).replace("\\", "/"), dest.stat().st_size, h, "NASA NCCS THREDDS NCSS (NEX-GDDP-CMIP6 v2.0)",
                        url.split("?")[0].split("/grid/")[-1], time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())])


def ok(path):
    try:
        with h5py.File(path, "r") as f:
            return any(v in f for v in VARS + ["pr", "tasmax", "tasmin"]) and f["time"].shape[0] >= 360
    except Exception:  # noqa: BLE001
        return False


def task_list(check, models=None, exps=None, variables=None):
    variables = ["pr", "tasmax"] if check else (variables or VARS)
    combos = [(m, var, e, v) for m, var in CFG["models"].items() for e in YEARS for v in variables
              if (not check or (e == "historical" and m in ("ACCESS-CM2", "MRI-ESM2-0", "UKESM1-0-LL", "GFDL-ESM4")))
              and (models is None or m in models) and (exps is None or e in exps)]

    def one(c):
        model, variant, exp, v = c
        xml = get(f"{CAT}/{model}/{exp}/{variant}/{v}/catalog.xml")
        out = []
        for p in re.findall(r'urlPath="([^"]+\.nc)"', xml):
            y = int(re.search(r"_(\d{4})(?:_v[\d.]+)?\.nc$", p).group(1))
            if check and y != 2000:
                continue
            if y in YEARS[exp]:
                out.append((model, exp, v, y, p))
        return out

    with ThreadPoolExecutor(6) as ex:
        return [t for ts in ex.map(one, combos) for t in ts]


def fetch(t, sub, out=None):
    model, exp, v, y, p = t
    dest = (out or OUT) / sub / model / exp / Path(p).name
    if dest.exists() and ok(dest):
        return "skip"
    dest.parent.mkdir(parents=True, exist_ok=True)
    url = (f"{NCSS}/{p}?var={v}&north={N}&south={S}&west={W}&east={E}&horizStride=1"
           f"&temporal=all&accept=netcdf4")  # one file = one model year (any calendar)
    data = get(url, binary=True, timeout=300)
    tmp = dest.with_suffix(".part")
    tmp.write_bytes(data)
    tmp.replace(dest)
    if not ok(dest):
        dest.unlink()
        raise RuntimeError(f"invalid file {dest.name}")
    if out is not None:
        manifest(dest, url)
    return "ok"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--threads", type=int, default=6)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--models", nargs="+", default=None, help="subset of models (default: all in config)")
    ap.add_argument("--exps", nargs="+", default=None, help="subset of experiments (historical ssp245 ssp585)")
    ap.add_argument("--vars", nargs="+", default=None, help="variables (default hurs rsds sfcWind)")
    ap.add_argument("--out", choices=["raw", "additional"], default="raw", help="additional = <paths.downscaling_additional>/nexgddp_cmip6 (config.yaml) + SHA-256 manifest")
    a = ap.parse_args()
    sub = "check_v2" if a.check else "data"
    out = Path(CFG["paths"]["downscaling_additional"]) / "nexgddp_cmip6" if a.out == "additional" else None
    tasks = task_list(a.check, a.models, a.exps, a.vars)
    tasks = [t for t in tasks if not (((out or OUT) / sub / t[0] / t[1] / Path(t[4]).name).exists())]
    print(f"{len(tasks)} files to process", flush=True)
    done = fail = 0
    with ThreadPoolExecutor(a.threads) as ex, open(LOG, "a", encoding="utf-8") as log:
        futs = {ex.submit(fetch, t, sub, out): t for t in tasks}
        for i, f in enumerate(as_completed(futs), 1):
            t = futs[f]
            try:
                f.result(); done += 1
            except Exception as e:  # noqa: BLE001
                fail += 1
                log.write(f"FAIL {t[:4]} {e}\n"); log.flush()
            if i % 200 == 0:
                print(f"{time.strftime('%H:%M:%S')} {i}/{len(tasks)} ok={done} fail={fail}", flush=True)
    print(f"finished ok={done} fail={fail}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
