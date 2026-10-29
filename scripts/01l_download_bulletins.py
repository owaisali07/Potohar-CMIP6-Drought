"""Step 1l (v2) - PMD/NDMC drought bulletins from Internet Archive (Wayback Machine) snapshots of
ndmc.pmd.gov.pk/new/assets/bulletins/*.pdf (the live NDMC server returns HTTP 500).
Download only (paced, 1 request / 3 s); text extraction and tabulation of declared drought months are done in R.
Output: data_raw/pmd_bulletins/wayback/*.pdf and wayback_index.csv
"""
import json
import time
from pathlib import Path

import requests
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
OUT = Path(CFG["paths"]["raw"]) / "pmd_bulletins" / "wayback"
OUT.mkdir(parents=True, exist_ok=True)
H = {"User-Agent": "Mozilla/5.0 (academic research; Paper6 Potohar drought; contact owner of project)"}
CDX = ("https://web.archive.org/cdx/search/cdx?url=ndmc.pmd.gov.pk/new/assets/bulletins/*&output=json"
       "&filter=statuscode:200&filter=mimetype:application/pdf&collapse=urlkey&limit=5000")


def get(url, tries=8):
    for k in range(tries):
        try:
            r = requests.get(url, headers=H, timeout=180)
            if r.status_code in (429, 503):
                time.sleep(60 * (k + 1)); continue
            r.raise_for_status()
            return r
        except Exception:  # noqa: BLE001
            time.sleep(20 * (k + 1))
    return None


idx = OUT / "wayback_index.json"
if idx.exists():
    rows = json.loads(idx.read_text())
else:
    r = get(CDX)
    rows = r.json()[1:]
    idx.write_text(json.dumps(rows))
print("archived bulletin PDFs:", len(rows), flush=True)
ok = 0
with open(OUT / "wayback_index.csv", "w", encoding="utf-8") as log:
    log.write("file,timestamp,original\n")
    for row in rows:
        ts, orig = row[1], row[2]
        f = OUT / orig.rsplit("/", 1)[-1]
        log.write(f"{f.name},{ts},{orig}\n")
        if f.exists() and f.stat().st_size > 1000:
            ok += 1; continue
        r = get(f"https://web.archive.org/web/{ts}id_/{orig}")
        if r is not None and r.content[:4] == b"%PDF":
            f.write_bytes(r.content); ok += 1
        time.sleep(3)
print("downloaded:", ok)

# ---- older NDMC products (pre-2020 site) and advisories: quarterly bulletins 2012-2019 (quater<Q><YY>.pdf), annual drought
# reports 2013-2018, drought advisories 2024-25, and every distinct capture of the files that were overwritten each issue
# (docs/Monthly_Bulletin.pdf, docs/Quarterly_bulletin.pdf). Output: data_raw/pmd_bulletins/wayback_old/ + index_old.csv
OLD = OUT.parent / "wayback_old"
OLD.mkdir(exist_ok=True)
pat = ("quater", "report", "drought-advis", "drought-alert", "Drought-Advisory", "docs/Monthly_Bulletin", "docs/Quarterly_bulletin")
rows_old = []
for host in ("ndmc.pmd.gov.pk", "www.ndmc.pmd.gov.pk", "www.pmd.gov.pk/ndmc", "pmd.gov.pk/ndmc"):
    r = get(f"https://web.archive.org/cdx/search/cdx?url={host}/*&output=json&filter=statuscode:200"
            f"&filter=mimetype:application/pdf&collapse=digest&fl=timestamp,original&limit=20000")
    if r is not None and r.text.strip():
        rows_old += [x for x in r.json()[1:] if any(p in x[1] for p in pat) and "assets/bulletins" not in x[1]]
seen, ok2 = set(), 0
with open(OLD / "index_old.csv", "w", encoding="utf-8") as log:
    log.write("file,timestamp,original\n")
    for ts, orig in sorted(rows_old):
        base = orig.split("?")[0].rsplit("/", 1)[-1].replace("%20", "")
        if not base.lower().endswith(".pdf"):
            continue
        name = (f"{ts[:8]}_{base}" if "docs/" in orig else base)      # overwritten files: keep each capture
        if name in seen:
            continue
        seen.add(name); f = OLD / name
        log.write(f"{name},{ts},{orig}\n")
        if f.exists() and f.stat().st_size > 1000:
            ok2 += 1; continue
        r = get(f"https://web.archive.org/web/{ts}id_/{orig}")
        if r is not None and r.content[:4] == b"%PDF":
            f.write_bytes(r.content); ok2 += 1
        time.sleep(3)
print("older NDMC products downloaded:", ok2, "of", len(seen))
