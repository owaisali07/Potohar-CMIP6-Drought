"""Step 1j (v2) - Download official district wheat statistics (download only; digitising is done in R, 04_digitise_yields.R).

  * PBS (Pakistan Bureau of Statistics): "Crops area and production by districts (28 years)", 1981-82 to 2008-09 (PDF)
  * Open Data Pakistan (Bureau of Statistics Punjab / Punjab Development Statistics): wheat area, production and
    yield by district, Punjab, 2007-08 to 2019-20 (CSV)
  * PBS Agricultural Statistics of Pakistan yearbook tables (latest district-wise wheat tables, if reachable)
Output: data_raw/yields/
"""
import time
from pathlib import Path

import requests
import yaml

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
OUT = Path(CFG["paths"]["raw"]) / "yields"
OUT.mkdir(parents=True, exist_ok=True)
H = {"User-Agent": "Mozilla/5.0 (research; Paper6 Potohar drought)"}
FILES = {
    "pbs_area_production_by_districts_28yrs.pdf":
        "https://www.pbs.gov.pk/wp-content/uploads/2020/07/area_and_production_by_districts_for_28_years.pdf",
    "opendata_punjab_wheat_production_districts.csv":
        "https://opendata.com.pk/dataset/d8455bce-a4ca-4ae9-bfab-9e6fbb03d6b6/resource/8f805abc-56c7-40d1-a2c1-708f31157479/download/area-sown-production-and-yield-per-hectare-of-wheat-by-districts-punjab-production-1000-matric-t.csv",
    "opendata_punjab_wheat_area_districts.csv":
        "https://opendata.com.pk/dataset/e6eaa63f-30c4-4d44-8e97-27d7dd35dd5f/resource/9b9f1869-834d-4fda-b9fc-5b6b73ac41b4/download/area-sown-production-and-yield-per-hectare-of-wheat-by-districts-punjab-area-1000-hectares.csv",
    "opendata_punjab_wheat_yield_districts.csv":
        "https://opendata.com.pk/dataset/7026d1dc-d7db-454e-bac5-1916e3110866/resource/5871026e-1918-43b4-b7ba-7578bdcd4123/download/area-sown-production-and-yield-per-hectare-of-wheat-by-districts-punjab-yield-per-hectare-in-kg-.csv",
    "PDS_2024.pdf": "https://bos.punjab.gov.pk/system/files/PDS%202024%2030-1-2024.pdf",
    "PDS_50_years_1972_2021.pdf":
        "https://opendata.com.pk/dataset/a58e7a47-1675-4c63-9b72-fc6377d36317/resource/1da797f5-ed34-4c24-ad9e-c7bf885138d1/download/50-years.pdf",
    "Punjab_Pocket_Book_2025.pdf": "https://bos.punjab.gov.pk/system/files/Statistical%20Pocket%20Book%202025%20Final.pdf",
    "MNFSR_crops_district_2022_23.pdf": "https://mnfsr.gov.pk/SiteImage/Downloads/Crops%20Area%20AND%20Production%20by%202022-23.pdf",
    "MNFSR_crops_district_2024_25.pdf": "https://mnfsr.gov.pk/SiteImage/Publication/CAP%202024-25.pdf",
}
# Crop Reporting Service, Agriculture Department Punjab (https://agripunjab.punjab.gov.pk/crs-crop-estimates):
# district wheat (irrigated / un-irrigated) in the Rabi books, groundnut in the Kharif books
CRS = "https://agripunjab.punjab.gov.pk/system/files/"   # the page links agripunjab.gov.pk, which does not resolve
for name, f in {
    "WHEAT_HISTORICAL.pdf": "WHEAT%20HISTORICAL.pdf",
    "Historical_Wheat_districtwise_2022_25.pdf": "Historical%20Data%20Wheat%20%28Districtwise%29%202022-25_0.pdf",
    "Plan_Groundnut_2026.pdf": "Plan%20Grounnut%202026.pdf",
    "Rabi_2012_13.pdf": "Final%20Rabi%20Estimate%202012-13.pdf",
    "Rabi_2017_18.pdf": "Book%20Rabi%20Final%20Estimates%202017-18.pdf",
    "Rabi_2019_20.pdf": "Book%20Final%20Rabi%20Estimates%202019-20_compressed%20%281%29.pdf",
    "Rabi_2020_21.pdf": "Book%20Rabi%20Final%20Estimates%202020-21.pdf",
    "Rabi_2021_22.pdf": "Book%20Rabi%20Final%202021-22.pdf",
    "Rabi_2022_23.pdf": "Final%20Rabi%20Estimates%202022-23_0.pdf",
    "Rabi_2023_24.pdf": "Final%20Rabi%20Estimates%202023-24_0.pdf",
    "Rabi_2024_25_book.pdf": "Final%20Rabi%20Estimates%20Book%202024-25.pdf",
    "Rabi_2025_26.pdf": "Final%20Rabi%20Estimates%202025-26_0.pdf",
    "Kharif_2017_18.pdf": "BOOK%20KHARIF%20Final%20Est%202017-18.pdf",
    "Kharif_2018_19.pdf": "Kharif%20Estimates%202018-19_compressed%20%281%29.pdf",
    "Kharif_2019_20.pdf": "Book%20Final%20Kharif%20Estimates%202019-20.pdf",
    "Kharif_2020_21.pdf": "Kharif%20Estimates%202020-2021.pdf",
    "Kharif_2021_22.pdf": "Book%20Kharif%20Final%202021-22.pdf",
    "Kharif_2022_23.pdf": "Final%20Kharif%20Estimates%202022-23%20%28Book%29.pdf",
    "Kharif_2023_24.pdf": "Final%20Kharif%20Estimates%202023-24_0.pdf",
    "Kharif_2024_25.pdf": "Final%20Kharif%20Estimates%202024-25_0.pdf",
    "Kharif_2025_26.pdf": "Final%20Kharif%20Estimates%202025-26_1.pdf",
}.items():
    FILES["crs/" + name] = CRS + f
(OUT / "crs").mkdir(exist_ok=True)
for name, url in FILES.items():
    dest = OUT / name
    if dest.exists() and dest.stat().st_size > 1000:
        print("have", name); continue
    for k in range(6):
        try:
            with requests.get(url, headers=H, timeout=300, stream=True) as r:
                r.raise_for_status()
                with open(dest, "wb") as f:
                    for b in r.iter_content(1 << 16):
                        f.write(b)
            print("ok", name, dest.stat().st_size); break
        except Exception as e:  # noqa: BLE001
            print("retry", name, k, str(e)[:120]); time.sleep(20 * (k + 1))

