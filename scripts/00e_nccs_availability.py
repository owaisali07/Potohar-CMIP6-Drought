"""Step 0e - Query NASA NCCS THREDDS for NEX-GDDP-CMIP6 variable availability (read-only, no download).

For every model/experiment/variant, lists which of the six methodology variables exist
and the year span + version tags of the files. Output: 00_inventory/nccs_availability.csv
"""
import re
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://ds.nccs.nasa.gov/thredds/catalog/AMES/NEX/GDDP-CMIP6"
VARS = ["pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"]
EXPS = ["historical", "ssp245", "ssp585"]


def get(url, tries=6):
    for k in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=90) as r:
                return r.read().decode()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            err = e
        except Exception as e:  # noqa: BLE001  (timeouts, SSL EOF, dropped connections)
            err = e
        time.sleep(5 * (k + 1))
    raise err


def refs(url):
    return re.findall(r'xlink:title="([^"]+)"', get(url))


def one(model, exp):
    rows = []
    try:
        for variant in refs(f"{BASE}/{model}/{exp}/catalog.xml"):
            avail = refs(f"{BASE}/{model}/{exp}/{variant}/catalog.xml")
            for v in VARS:
                r = dict(model=model, experiment=exp, variant=variant, variable=v, available=v in avail)
                if v in avail:
                    files = re.findall(r'urlPath="[^"]*/([^/"]+\.nc)"', get(f"{BASE}/{model}/{exp}/{variant}/{v}/catalog.xml"))
                    yrs = sorted({int(m) for f in files for m in re.findall(r"_(\d{4})(?:_v[\d.]+)?\.nc$", f)})
                    vers = sorted({(re.findall(r"_(v[\d.]+)\.nc$", f) or ["v1.0"])[0] for f in files})
                    r.update(n_files=len(files), y0=yrs[0] if yrs else None, y1=yrs[-1] if yrs else None,
                             n_years=len(yrs), versions=";".join(vers))
                rows.append(r)
    except Exception as e:  # noqa: BLE001
        rows.append(dict(model=model, experiment=exp, error=str(e)[:100]))
    return rows


models = refs(f"{BASE}/catalog.xml")
with ThreadPoolExecutor(3) as ex:
    res = list(ex.map(lambda me: one(*me), [(m, e) for m in models for e in EXPS]))
df = pd.DataFrame([r for rs in res for r in rs])
df.to_csv(ROOT / "00_inventory" / "nccs_availability.csv", index=False)
pd.set_option("display.width", 250, "display.max_rows", 400)
piv = df[df.get("available", False) == True].pivot_table(index="model", columns=["experiment", "variable"], values="n_years", aggfunc="max")
print(f"models on NCCS: {len(models)}")
print(piv.fillna(0).astype(int).to_string())
