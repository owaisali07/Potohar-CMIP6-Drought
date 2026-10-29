"""Step 0 - Inventory of CMIP6 data available locally (read-only).

Walks every CMIP6 source on disk, parses file names, probes NetCDF headers
(units, calendar, grid, extent) and writes:
  00_inventory/cmip6_inventory.csv        one row per source/model/variant/experiment/variable
  00_inventory/cmip6_completeness.csv     one row per model: methodology requirements met?
  00_inventory/domain_coverage.csv        per probed file: does the grid cover Potohar + 0.5 deg?

Nothing is written outside analysis/. Source folders are opened read-only.
Usage: python 00_inventory.py
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

import h5py
import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
CFG = yaml.safe_load(open(ROOT / "config.yaml")); DS = Path(CFG["paths"]["downscaling_readonly"]); P3D = Path(CFG["paths"]["paper3_data"])
OUT = ROOT / "00_inventory"
OUT.mkdir(exist_ok=True)

SOURCES = {
    "downscaling_raw_cmip6": DS / "data" / "cmip6",
    "downscaling_processed": DS / "data" / "cmip6_processed",
    "downscaling_corrdiff_out": DS / "outputs" / "netcdf",
    "paper3_nexgddp_pervar": P3D / "nex-gddp-cmip6",
    "paper3_nexgddp_PAK": P3D / "nex_gddp_cmip6",
}

REQ_VARS = ["pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"]
REQ_EXP = {"historical": (1985, 2014), "ssp245": (2015, 2100), "ssp585": (2015, 2100)}
# Potohar Plateau (Attock, Chakwal, Jhelum, Rawalpindi, ICT, Soan basin) approx. bbox
# 71.7-73.7E, 32.4-34.0N (from district extents); required with >=0.5 deg buffer.
POTOHAR = dict(lon0=71.7, lon1=73.7, lat0=32.4, lat1=34.0)
BUF = 0.5

RX_CMIP = re.compile(
    r"^(?P<var>[A-Za-z]+)_day_(?P<model>.+?)_(?P<exp>historical|ssp\d{3})_(?P<variant>r\d+i\d+p\d+f\d+)_"
    r"(?P<grid>g[a-z0-9]+)_(?P<t0>\d{4})(?:\d{4})?(?:-(?P<t1>\d{4})\d{4})?(?:_(?P<ver>v[\d.]+))?\.nc$")
RX_PAK = re.compile(r"^nex_gddp_(?P<model>.+?)_(?P<exp>historical|ssp\d{3})_(?P<t0>\d{4})_PAK\.nc$")
RX_PROC = re.compile(r"^(?P<var>pr|tas)_(?P<model>.+?)_(?P<exp>historical|ssp\d{3})_(?P<t0>\d{4})_(?P<t1>\d{4})_(?P<kind>.+)\.nc$")
RX_CD = re.compile(r"^corrdiff_(?P<var>pr|tas)_(?P<model>.+?)_(?P<exp>historical|SSP\d{3})_(?P<t0>\d{4})_(?P<t1>\d{4})\.nc$")


def attr(obj, key):
    v = obj.attrs.get(key)
    if v is None:
        return ""
    if isinstance(v, bytes):
        return v.decode(errors="replace")
    if isinstance(v, np.ndarray):
        v = v.tolist()
        if len(v) == 1:
            v = v[0]
        if isinstance(v, bytes):
            return v.decode(errors="replace")
    return str(v)


def probe(path):
    """Read header info from a NetCDF4/HDF5 file; netCDF3 falls back to scipy."""
    info = {"format": "", "data_vars": "", "units": {}, "calendar": "", "lon_min": np.nan,
            "lon_max": np.nan, "lat_min": np.nan, "lat_max": np.nan, "dlon": np.nan, "dlat": np.nan,
            "ntime": np.nan, "time_units": "", "error": ""}
    try:
        with h5py.File(path, "r") as f:
            info["format"] = "NetCDF4/HDF5"
            names = list(f.keys())
            lon = next((n for n in names if n.lower() in ("lon", "longitude", "x")), None)
            lat = next((n for n in names if n.lower() in ("lat", "latitude", "y")), None)
            tim = next((n for n in names if n.lower() in ("time", "valid_time")), None)
            coords = {lon, lat, tim}
            dvars = [n for n in names if isinstance(f[n], h5py.Dataset) and n not in coords
                     and f[n].ndim >= 2]
            info["data_vars"] = ";".join(dvars)
            info["units"] = {v: attr(f[v], "units") for v in dvars}
            if tim:
                info["calendar"] = attr(f[tim], "calendar") or "(none: standard)"
                info["time_units"] = attr(f[tim], "units")
                info["ntime"] = f[tim].shape[0]
            if lon and lat:
                lo, la = f[lon][()], f[lat][()]
                info.update(lon_min=float(lo.min()), lon_max=float(lo.max()),
                            lat_min=float(la.min()), lat_max=float(la.max()))
                if lo.ndim == 1 and lo.size > 1:
                    info["dlon"] = float(np.round(np.median(np.abs(np.diff(lo))), 4))
                if la.ndim == 1 and la.size > 1:
                    info["dlat"] = float(np.round(np.median(np.abs(np.diff(la))), 4))
    except OSError:
        try:
            from scipy.io import netcdf_file
            with netcdf_file(path, "r", mmap=False) as f:
                info["format"] = "NetCDF3"
                dvars = [n for n, v in f.variables.items() if len(v.dimensions) >= 2]
                info["data_vars"] = ";".join(dvars)
                info["units"] = {v: getattr(f.variables[v], "units", b"").decode() for v in dvars}
        except Exception as e:  # noqa: BLE001
            info["error"] = f"unreadable: {e}"
    return info


def covers(info):
    if np.isnan(info["lon_min"]):
        return ""
    lon_min, lon_max = info["lon_min"], info["lon_max"]
    if lon_max > 180:  # 0-360 grids
        pass
    ok = (lon_min <= POTOHAR["lon0"] - BUF and lon_max >= POTOHAR["lon1"] + BUF
          and info["lat_min"] <= POTOHAR["lat0"] - BUF and info["lat_max"] >= POTOHAR["lat1"] + BUF)
    return "yes" if ok else "NO"


def year_span(years):
    ys = sorted(set(years))
    if not ys:
        return "", ""
    gaps, start = [], ys[0]
    for a, b in zip(ys, ys[1:]):
        if b != a + 1:
            gaps.append(f"{a + 1}-{b - 1}")
    return f"{ys[0]}-{ys[-1]}", ";".join(gaps)


def main():
    groups = defaultdict(list)  # key -> list of (path, y0, y1)
    unparsed = []
    for src, base in SOURCES.items():
        if not base.exists():
            print(f"[skip] {src}: {base} not found")
            continue
        for p in base.rglob("*.nc"):
            n = p.name
            m = RX_CMIP.match(n)
            if m:
                y0 = int(m["t0"]); y1 = int(m["t1"]) if m["t1"] else y0
                key = (src, m["model"], m["variant"], m["exp"], m["var"], m["grid"], m["ver"] or "")
                groups[key].append((p, y0, y1)); continue
            m = RX_PAK.match(n)
            if m:
                y0 = int(m["t0"])
                key = (src, m["model"], "", m["exp"], "*multi*", "", "")
                groups[key].append((p, y0, y0)); continue
            m = RX_PROC.match(n)
            if m:
                key = (src, m["model"], "r1i1p1f1", m["exp"], m["var"], "1deg", m["kind"])
                groups[key].append((p, int(m["t0"]), int(m["t1"]))); continue
            m = RX_CD.match(n)
            if m:
                key = (src, m["model"], "r1i1p1f1", m["exp"].lower(), m["var"], "0.1deg", "corrdiff")
                groups[key].append((p, int(m["t0"]), int(m["t1"]))); continue
            unparsed.append(str(p))

    rows, cov_rows = [], []
    multi_vars = defaultdict(set)
    for key, files in sorted(groups.items()):
        src, model, variant, exp, var, grid, ver = key
        files.sort(key=lambda t: t[1])
        years = [y for _, a, b in files for y in range(a, b + 1)]
        span, gaps = year_span(years)
        first = probe(files[0][0])
        last = probe(files[-1][0]) if len(files) > 1 else first
        if var == "*multi*":
            # per-year multi-variable files: confirm variable set on first, middle and last file
            mid = probe(files[len(files) // 2][0])
            vs = set(first["data_vars"].split(";")) & set(mid["data_vars"].split(";")) & set(last["data_vars"].split(";"))
            multi_vars[(model, exp)] = vs
            var_label = ";".join(sorted(vs))
            units = ";".join(f"{v}={first['units'].get(v, '')}" for v in sorted(vs))
        else:
            var_label = var
            units = first["units"].get(var, ";".join(f"{k}={v}" for k, v in first["units"].items()))
        res = f"{first['dlon']}x{first['dlat']} deg" if not np.isnan(first["dlon"]) else grid
        ext = (f"lon {first['lon_min']:.2f}..{first['lon_max']:.2f}, lat {first['lat_min']:.2f}..{first['lat_max']:.2f}"
               if not np.isnan(first["lon_min"]) else "")
        rows.append(dict(source=src, model=model, variant=variant, experiment=exp, variable=var_label,
                         years_covered=span, year_gaps=gaps, resolution=res, grid_label=grid,
                         spatial_extent=ext, potohar_covered_0p5buf=covers(first),
                         file_format=first["format"], units=units, calendar=first["calendar"],
                         version_tag=ver, file_count=len(files),
                         size_MB=round(sum(p.stat().st_size for p, _, _ in files) / 1e6, 1),
                         probe_error=first["error"] or last["error"],
                         example_file=files[0][0].name))
    inv = pd.DataFrame(rows)
    inv.to_csv(OUT / "cmip6_inventory.csv", index=False)

    # ---- completeness vs methodology (Table I NEX-GDDP row + III-E/F) ----
    comp = []
    nex = inv[inv.source.str.startswith("paper3_nexgddp") | inv.source.str.startswith("downscaling")]
    for (src, model), g in nex.groupby(["source", "model"]):
        row = dict(source=src, model=model)
        for exp, (y0, y1) in REQ_EXP.items():
            ge = g[g.experiment == exp]
            have = set()
            for v in ge.variable:
                have |= set(v.split(";"))
            yrs_ok = {}
            for v in REQ_VARS:
                gv = ge[ge.variable.str.split(";").apply(lambda s: v in s)]
                if gv.empty:
                    yrs_ok[v] = "missing"; continue
                spans = gv.years_covered.iloc[0].split("-")
                a, b = int(spans[0]), int(spans[1])
                gaps = gv.year_gaps.iloc[0]
                yrs_ok[v] = "ok" if (a <= y0 and b >= y1 and not gaps) else f"partial {a}-{b}{' gaps ' + gaps if gaps else ''}"
            for v in REQ_VARS:
                row[f"{exp}:{v}"] = yrs_ok[v]
        flat = [row[k] for k in row if ":" in k]
        row["complete_all6_hist_ssp245_ssp585"] = all(x == "ok" for x in flat)
        row["PM_ET0_possible"] = all(row[f"{e}:{v}"] == "ok" for e in REQ_EXP for v in ("tasmax", "tasmin", "hurs", "rsds", "sfcWind"))
        row["pr_tasmax_tasmin_complete"] = all(row[f"{e}:{v}"] == "ok" for e in REQ_EXP for v in ("pr", "tasmax", "tasmin"))
        comp.append(row)
    comp = pd.DataFrame(comp)
    comp.to_csv(OUT / "cmip6_completeness.csv", index=False)

    if unparsed:
        (OUT / "unparsed_files.txt").write_text("\n".join(unparsed), encoding="utf-8")
    print(f"groups={len(inv)}  unparsed={len(unparsed)}")
    print(inv.groupby("source").agg(models=("model", "nunique"), files=("file_count", "sum"), MB=("size_MB", "sum")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
