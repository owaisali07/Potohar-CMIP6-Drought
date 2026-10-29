"""Step 0d - Probe locally available observational data (read-only).

Reports variables/periods of ERA5-Land daily, CHIRPS, CPC, HadISD, GSOD, GHCN-D files
and lists stations inside the Potohar box + 0.5 deg buffer.
Output: 00_inventory/obs_local_probe.txt, 00_inventory/stations_potohar.csv
"""
from pathlib import Path

import h5py
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
CFG = yaml.safe_load(open(ROOT / "config.yaml")); DS = Path(CFG["paths"]["downscaling_readonly"]); P3D = Path(CFG["paths"]["paper3_data"])
D = P3D
BOX = (71.2, 74.2, 31.9, 34.5)  # Potohar 71.7-73.7E, 32.4-34.0N + 0.5 deg
out = []


def h5vars(f):
    with h5py.File(f, "r") as h:
        return {k: (h[k].shape, {a: (h[k].attrs[a].decode() if isinstance(h[k].attrs[a], bytes) else str(h[k].attrs[a]))[:30]
                                 for a in ("units", "long_name") if a in h[k].attrs}) for k in h if isinstance(h[k], h5py.Dataset)}


for name, pattern in [("era5land_daily", "era5land_daily/*.nc"), ("era5land_tmax", "era5land/tmax/*.nc"),
                      ("chirps", "chirps/*.nc"), ("imerg", "imerg/*.nc"), ("cpc_precip", "cpc_global/precip/*.nc"),
                      ("cpc_tmax", "cpc_global/tmax/*.nc"), ("berkeley", "berkeley_earth/*.nc"), ("hadisd", "stations/hadisd/*.nc")]:
    fs = sorted(D.glob(pattern))
    out.append(f"== {name}: {len(fs)} files; first={fs[0].name if fs else ''} last={fs[-1].name if fs else ''}")
    if fs:
        try:
            for k, v in h5vars(fs[0]).items():
                out.append(f"     {k}: {v}")
        except OSError as e:
            out.append(f"     (not HDF5: {e})")

# stations
st = []
gs = D / "stations" / "gsod" / "gsod_pakistan.csv"
if gs.exists():
    g = pd.read_csv(gs, nrows=200000, low_memory=False)
    out.append(f"== GSOD merged columns: {list(g.columns)}")
merged = D / "stations" / "merged" / "stations_merged_daily.csv"
if merged.exists():
    m = pd.read_csv(merged, nrows=5, low_memory=False)
    out.append(f"== stations_merged_daily columns: {list(m.columns)}")
for f in sorted((D / "stations").rglob("*station*.csv")) + sorted((D / "stations").rglob("*inventory*.csv")):
    out.append(f"   meta file: {f.relative_to(D)}")
ghcn = D / "stations" / "ghcnd" / "ghcnd-stations.txt"
if ghcn.exists():
    rows = []
    for line in ghcn.read_text(errors="ignore").splitlines():
        if line.startswith("PK"):
            rows.append(dict(source="GHCN-D", id=line[0:11], lat=float(line[12:20]), lon=float(line[21:30]),
                             elev=float(line[31:37]), name=line[41:71].strip()))
    st += [r for r in rows if BOX[0] <= r["lon"] <= BOX[1] and BOX[2] <= r["lat"] <= BOX[3]]
for f in sorted((D / "stations" / "hadisd").glob("*.nc")):
    with h5py.File(f, "r") as h:
        lat = float(h["latitude"][()].ravel()[0]) if "latitude" in h else float("nan")
        lon = float(h["longitude"][()].ravel()[0]) if "longitude" in h else float("nan")
        vs = [k for k in h if isinstance(h[k], h5py.Dataset) and k in ("temperatures", "dewpoints", "windspeeds", "precip1_depth", "slp", "cloud_cover", "sunshine")]
    if BOX[0] <= lon <= BOX[1] and BOX[2] <= lat <= BOX[3]:
        st.append(dict(source="HadISD", id=f.name.split("_")[-1].replace(".nc", ""), lat=lat, lon=lon, elev=None,
                       name=f.name, vars=";".join(vs)))
pd.DataFrame(st).to_csv(ROOT / "00_inventory" / "stations_potohar.csv", index=False)
out.append(f"== stations in Potohar+0.5deg: {len(st)}")
for r in st:
    out.append(f"   {r}")
(ROOT / "00_inventory" / "obs_local_probe.txt").write_text("\n".join(out), encoding="utf-8")
print("\n".join(out))
