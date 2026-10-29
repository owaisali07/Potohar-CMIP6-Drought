"""Step 12 - Results and Discussion (IEEE style, past tense) -> results_text/Results_Discussion.docx

Every number is read from results_text/key_numbers.json or from the CSV tables written by
Potohar_Drought_Analysis.Rmd, so the text can be regenerated after any re-run.
"""
import json
from pathlib import Path

import numpy as np
import pandas as pd
import yaml
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt

CFG = yaml.safe_load(open(Path(__file__).resolve().parents[1] / "config.yaml"))
ROOT = Path(CFG["paths"]["root"])
K = json.load(open(ROOT / "results_text" / "key_numbers.json", encoding="utf-8"))
T = lambda n: pd.read_csv(ROOT / "tables" / n)  # noqa: E731
df = lambda k: pd.DataFrame(K[k])  # noqa: E731
f1 = lambda x: f"{x:.1f}"  # noqa: E731
MONTHS = dict(Jan="January", Feb="February", Mar="March", Apr="April", Dec="December")
f2 = lambda x: f"{x:.2f}"  # noqa: E731
sgn = lambda x, d=1: (f"+{x:.{d}f}" if x >= 0 else f"−{abs(x):.{d}f}")  # noqa: E731

clim = df("obs_annual_clim_1985_2014").iloc[0]
tr = T("Table3_trends.csv")
grid = tr[tr.Series.str.startswith("Potohar (gridded")].set_index("Variable")
row = lambda key: grid.loc[[i for i in grid.index if i.startswith(key)][0]]  # noqa: E731
sel = K["selected_index"]
SEL = sel["index"]
obs_char = df("obs_char").set_index("index")
sel_key = SEL.replace("-", "")
ev = df("obs_events_sel")
prop = K["propagation"]
vhi = df("vhi_spei_cor").set_index("scale")
bench = df("speibase_benchmark").set_index("scale")
cc_reg = df("crosscomp_regional")
cc_st = df("crosscomp_station")
rank = df("gcm_rank")
top = K["top_models"]
qs = df("qdm_split")
ba = df("bias_before_after").set_index("variable")
wind = df("wind_rs_check")
t4 = T("Table4_projected_changes.csv").set_index("Case")
ens = df("ens_changes")
seas = pd.read_csv(ROOT / "08_projections" / "seasonal_changes_ensemble.csv")
rob = df("robust_cells_pct")
gwl = df("ens_gwl")
t5 = T("Table5_return_periods.csv").set_index("Set")
ref = df("ref_events")
expo = pd.read_csv(ROOT / "10_exposure" / "exposure_by_district.csv")
hs = df("hs_fractions")
t7 = T("Table7_sensitivity.csv")
isi = df("isimip_chain")
raw_qdm = df("raw_vs_qdm").set_index("scenario")
et0 = df("et0_annual").iloc[0]
basin = df("basin")
conc = df("concurrent_obs").set_index("scale")
mb = df("model_baseline_char").iloc[0]


def E(s, p, m):
    r = ens[(ens.scenario == s) & (ens.period == p) & (ens.metric == m)].iloc[0]
    return r


def G(level, m):
    return gwl[(gwl.gwl == level) & (gwl.metric == m)].iloc[0]


def S(s, p, season):
    return seas[(seas.scenario == s) & (seas.period == p) & (seas.season == season)].iloc[0]


def RC(s, p):
    return rob[(rob.scenario == s) & (rob.period == p)].iloc[0]


def HSF(what, year, src):
    r = hs[(hs.what.str.contains(what)) & (hs.year == year) & (hs.source == src)]
    return float(r.frac.iloc[0])


exp_far = expo[expo.period == "far"].groupby("scenario")[["wheat_exp", "wheat_total", "gnut_exp", "gnut_total"]].sum()
exp_mid = expo[expo.period == "mid"].groupby("scenario")[["wheat_exp", "wheat_total", "gnut_exp", "gnut_total"]].sum()
d_far = expo[(expo.period == "far") & (expo.scenario == "ssp585")].set_index("district")

# ------------------------------------------------------------------ document
doc = Document()
st = doc.styles["Normal"]
st.font.name = "Times New Roman"
st.font.size = Pt(10)
st.paragraph_format.space_after = Pt(3)
st.paragraph_format.first_line_indent = Pt(10)


def H1(t):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Pt(0)
    r = p.add_run(t.upper())
    r.font.size = Pt(10)
    r.font.small_caps = True


def H2(t):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    r = p.add_run(t)
    r.italic = True


def P(t):
    p = doc.add_paragraph(t)
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY


title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = title.add_run("Future Droughts in the Potohar Plateau under CMIP6 Scenarios — Results and Discussion")
r.bold = True
r.font.size = Pt(12)

H1("V. Results and Discussion")

# ---------------- A. Observed
H2("A. Observed Climate and Drought, 1981–2024")
P(f"Over the four districts and ICT, the 1985–2014 mean annual precipitation was {clim.P_chirps:.0f} mm in CHIRPS, "
  f"{clim.P_cru:.0f} mm in CRU TS 4.10 and {clim.P_e5l:.0f} mm in ERA5-Land. June–September contributed {K['monsoon_share_pct']:.0f}% "
  f"of the CHIRPS total, below the 70–75% reported for the Soan basin [4]. FAO-56 Penman–Monteith ET0 computed from the "
  f"TerraClimate inputs amounted to {et0['PM (TerraClimate inputs)']:.0f} mm yr⁻¹. It agreed closely with the TerraClimate PET "
  f"({et0['TerraClimate PET']:.0f} mm yr⁻¹; r = {K['et0_r_tc']:.3f} for monthly values) and the CRU TS PET ({et0['CRU TS PET']:.0f} mm yr⁻¹; "
  f"r = {K['et0_r_cru']:.3f}). The Hargreaves estimate was higher, at {et0['Hargreaves']:.0f} mm yr⁻¹ (Fig. S1). The implementation of Eq. (1) "
  f"reproduced the FAO method of the SPEI package (r = {K['pm_check_r']:.4f}).")
P("Of the seven stations in and around the plateau, only Islamabad-Chaklala and Jhelum met the completeness rule (≥80% complete "
  "months in 1985–2014; Table I). The SNHT and Pettitt tests flagged the Jhelum precipitation and the Chaklala and Jhelum Tmin series. "
  "Because these absolute tests also respond to genuine climatic trends, the flagged series were retained for the indices but their "
  "trends were not interpreted (Table III). The regional (gridded) analysis is therefore the primary observational basis.")
p_ = row("Annual precipitation"); e_ = row("Annual PM ET0"); tx = row("Mean Tmax"); tn = row("Mean Tmin"); wb = row("Annual P − ET0")
s12 = row("SPEI-12"); spi12 = row("SPI-12"); dm = row("Drought months")
P(f"The regional series showed significant increases (TFPW–Mann–Kendall, α = 0.05; Table III) in annual precipitation "
  f"({sgn(p_['Sen slope'])} mm decade⁻¹, p = {p_.p:.3f}), PM ET0 ({sgn(e_['Sen slope'])} mm decade⁻¹, p = {e_.p:.3f}), Tmax "
  f"({sgn(tx['Sen slope'], 2)} °C decade⁻¹) and Tmin ({sgn(tn['Sen slope'], 2)} °C decade⁻¹). The water balance P − ET0 also rose "
  f"({sgn(wb['Sen slope'])} mm decade⁻¹), but not significantly (p = {wb.p:.2f}). As a result, SPI-12 trended significantly towards wetter "
  f"conditions ({sgn(spi12['Sen slope'], 2)} decade⁻¹), whereas the SPEI-12 trend ({sgn(s12['Sen slope'], 2)} decade⁻¹, p = {s12.p:.2f}) "
  f"and the decline in {SEL} drought months ({sgn(dm['Sen slope'], 2)} months decade⁻¹, p = {dm.p:.2f}) were not significant. "
  f"The rise in evaporative demand thus offset {100 * e_['Sen slope'] / p_['Sen slope']:.0f}% of the observed precipitation increase. "
  f"At 0.05° resolution, {K['fine_trend_sig_pct']['P']:.1f}% of the cells had a significant precipitation trend and "
  f"{K['fine_trend_sig_pct']['ET0']:.0f}% a significant ET0 trend, but only {K['fine_trend_sig_pct']['SPEI12']:.0f}% a significant SPEI-12 "
  f"trend, concentrated in the south and east (Fig. 2c–e).")
top5 = df("yield_top5")
P(f"Among all indices, time scales and Rabi months, the {SEL} ending in {MONTHS[sel['month']]} (October–December water balance) correlated best "
  f"with detrended GDHY wheat yields of the following harvest (mean r = {sel['mean_r']:.2f} over the five units; significant in "
  f"{sel['n_sig']} of 5; Fig. 3c). It was followed by {top5.iloc[1]['index'][:-1]}-{top5.iloc[1]['index'][-1]} ending in "
  f"{MONTHS[top5.iloc[1]['month']]} (r = {top5.iloc[1]['mean_r']:.2f}). This confirms that moisture at wheat sowing controls rainfed yields on the "
  f"plateau, so {SEL} was used for the characteristics, projections and return periods. Run theory with a threshold of −1 identified "
  f"{int(obs_char.loc[sel_key,'n_events'])} {SEL} events in 1981–2024 ({obs_char.loc[sel_key,'events_per_decade']:.1f} per decade). They had a mean "
  f"duration of {obs_char.loc[sel_key,'D_mean']:.1f} months and a mean severity of {obs_char.loc[sel_key,'S_mean']:.2f}. The most severe "
  f"events began in {pd.to_datetime(ev.start.iloc[0]):%B %Y} (D = {int(ev.D.iloc[0])}, S = {ev.S.iloc[0]:.1f}), "
  f"{pd.to_datetime(ev.start.iloc[1]):%B %Y} and {pd.to_datetime(ev.start.iloc[2]):%B %Y}; the last two fall within the 1999–2002 drought (Fig. 2a). "
  f"Concurrent drought (SPI-3 ≤ −1.5 and SPEI-3 ≤ −1.5) occurred in {int(conc.loc[3,'months_conc'])} months "
  f"({conc.loc[3,'pct']:.1f}%). SPEI-3 identified {int(conc.loc[3,'spei_only'])} additional severe months that SPI-3 missed, attributable to "
  f"evaporative demand.")
P(f"The cropland VHI (MODIS, 2000–2024) was below 40 in {K['vhi_drought_months_pct']:.0f}% of months. It correlated best with SPEI-3 "
  f"(r = {vhi.loc[3,'r_SPEI']:.2f}; SPI-3: {vhi.loc[3,'r_SPI']:.2f}), which supports the agricultural relevance of the selected index. "
  f"The regional SPEI agreed with the SPEIbase-equivalent SPEI computed from CRU TS 4.10 (r = {bench.loc[3,'r']:.2f} at 3 months, "
  f"{bench.loc[12,'r']:.2f} at 12 months; drought/no-drought agreement {100*bench.loc[3,'agree_drought']:.0f}%).")
r_cru = cc_reg[(cc_reg['vs CHIRPS-PM'] == 'CRU') & (cc_reg['index'] == 'SPEI3')].iloc[0]
r_e5 = cc_reg[(cc_reg['vs CHIRPS-PM'] == 'ERA5-Land') & (cc_reg['index'] == 'SPEI3')].iloc[0]
st_ch = cc_st[(cc_st.gridded == 'CHIRPS') & (cc_st['index'] == 'SPEI3')].iloc[0]
st_e5 = cc_st[(cc_st.gridded == 'ERA5-Land') & (cc_st['index'] == 'SPEI3')].iloc[0]
P(f"Cross-comparison showed that the observational uncertainty in rainfall is substantial. Regional SPEI-3 from CRU (r = {r_cru.r:.2f}) "
  f"and ERA5-Land (r = {r_e5.r:.2f}) agreed reasonably with the CHIRPS-based series. At the station cells, CHIRPS reproduced the "
  f"station SPEI-3 better (r = {st_ch.r:.2f}) than ERA5-Land (r = {st_e5.r:.2f}). This supports CHIRPS as the primary precipitation "
  f"product, in line with [3]. The PMD/NDMC drought bulletins could not be retrieved (server error), so this qualitative validation "
  f"remains open.")

# ---------------- B. Propagation
H2("B. Propagation from Meteorological to Hydrological Drought")
P(f"Basin-mean SPEI-k correlated most strongly with GloFAS-based SRI-1 at Dhok Pathan for k = {prop['best_k']} month at lag "
  f"{prop['best_lag']} (r = {prop['r']:.2f}; Fig. 3a,b). The correlation decreased steadily for longer time scales and for lags of 1–6 "
  f"months. At the headwater outlet (Chirah), the maximum occurred at k = {prop['chirah_best_k']} months. Meteorological anomalies "
  f"therefore propagate to streamflow within about one month at the basin outlet and within about one season in the headwaters. "
  f"This is a rapid response consistent with the flashy, rain-fed regime of the Soan described in [4], [5]. Because the open GloFAS "
  f"service starts in 1997, SRI was calibrated on 1997–2024, and the propagation times are indicative rather than gauge-based.")

# ---------------- C. GCMs
H2("C. GCM Performance and Bias Correction")
best = rank.iloc[0]
gm = pd.read_csv(ROOT / "06_gcm_eval" / "gcm_metrics.csv")
kr = lambda v: (gm[gm.variable == v].KGE.min(), gm[gm.variable == v].KGE.max())  # noqa: E731
kt = (min(kr("tasmax")[0], kr("tasmin")[0]), max(kr("tasmax")[1], kr("tasmin")[1]))
kp = gm[(gm.variable == "pr") & (gm.KGE >= 0)].KGE
P(f"The 27 NEX-GDDP-CMIP6 models reproduced the observed temperature climatology closely (KGE {kt[0]:.2f}–{kt[1]:.2f}). Their skill "
  f"varied more for precipitation (KGE {kp.min():.2f}–{kp.max():.2f} for the models with skill) and was lowest for ET0 "
  f"(KGE {kr('ET0')[0]:.2f}–{kr('ET0')[1]:.2f}; Table II, Fig. 4). KIOST-ESM had no precipitation skill (KGE < 0) and was "
  f"ranked last. Compromise programming retained {', '.join(top)}. {best.model} ranked first (L2 = {best.L2:.3f}); the skill "
  f"weights ranged from {rank[rank['rank'] <= 10].weight.min():.3f} to {rank[rank['rank'] <= 10].weight.max():.3f}.")
w0 = wind.iloc[0]
P(f"The low ET0 skill arose from residual biases in the NEX-GDDP inputs. The 10 m wind of the ensemble exceeded both the station "
  f"wind and TerraClimate by a factor of about three (e.g., Islamabad-Chaklala: {w0.wind_NEX_mean:.1f} vs {w0.wind_station:.1f} and "
  f"{w0.wind_TerraClimate:.1f} m s⁻¹). Shortwave radiation was about {ba.loc['rsds','raw']:.0f}% too high and relative humidity about "
  f"{ba.loc['hurs','raw']:.0f} percentage points too high. QDM removed these biases over 1985–2014 (remaining mean bias "
  f"{ba.loc['pr','QDM']:.2f}% for precipitation and at most {ba.drop('pr').QDM.abs().max():.2f} (°C, %-points or %) in the other "
  f"variables). In split-sample validation (Fig. 5), the mean "
  f"absolute bias fell from {qs[(qs.variable=='sfcWind')&(qs.stage=='raw')].mean_abs_bias.iloc[0]:.0f}% to "
  f"{qs[(qs.variable=='sfcWind')&(qs.stage=='QDM')].mean_abs_bias.iloc[0]:.1f}% for wind, from "
  f"{qs[(qs.variable=='rsds')&(qs.stage=='raw')].mean_abs_bias.iloc[0]:.0f}% to {qs[(qs.variable=='rsds')&(qs.stage=='QDM')].mean_abs_bias.iloc[0]:.1f}% "
  f"for radiation, from {qs[(qs.variable=='hurs')&(qs.stage=='raw')].mean_abs_bias.iloc[0]:.0f} to "
  f"{qs[(qs.variable=='hurs')&(qs.stage=='QDM')].mean_abs_bias.iloc[0]:.1f} %-points for humidity, and from "
  f"{qs[(qs.variable=='pr')&(qs.stage=='raw')].mean_abs_bias.iloc[0]:.1f}% to {qs[(qs.variable=='pr')&(qs.stage=='QDM')].mean_abs_bias.iloc[0]:.1f}% "
  f"for precipitation (90th-percentile bias {qs[(qs.variable=='pr')&(qs.stage=='raw')].q90_abs_bias.iloc[0]:.0f}% → "
  f"{qs[(qs.variable=='pr')&(qs.stage=='QDM')].q90_abs_bias.iloc[0]:.0f}%). For Tmax and Tmin, the validation bias was larger after QDM "
  f"({qs[(qs.variable=='tasmax')&(qs.stage=='QDM')].mean_abs_bias.iloc[0]:.2f} vs {qs[(qs.variable=='tasmax')&(qs.stage=='raw')].mean_abs_bias.iloc[0]:.2f} °C). "
  f"This probably reflects the observed warming between the two halves of the record (non-stationarity), which a stationary correction cannot "
  f"anticipate. NEX-GDDP had already removed most of the temperature bias.")
P(f"QDM preserved the projected relative change of each quantile. Monthly quantile functions were estimated from pooled three-month "
  f"windows because single-month samples inflated the mean precipitation change. The ensemble far-future (2076–2100) precipitation change "
  f"was {sgn(raw_qdm.loc['ssp245','dP_qdm'])}% (SSP2-4.5) and {sgn(raw_qdm.loc['ssp585','dP_qdm'])}% (SSP5-8.5) after QDM, against "
  f"{sgn(raw_qdm.loc['ssp245','dP_raw'])}% and {sgn(raw_qdm.loc['ssp585','dP_raw'])}% in the published NEX-GDDP. The ET0 change was "
  f"{sgn(raw_qdm.loc['ssp245','dET0_qdm'])}% and {sgn(raw_qdm.loc['ssp585','dET0_qdm'])}% after QDM, against "
  f"{sgn(raw_qdm.loc['ssp245','dET0_raw'])}% and {sgn(raw_qdm.loc['ssp585','dET0_raw'])}% before.")

# ---------------- D. Projections
H2("D. Projected Changes in Drought Characteristics")
f245, f585 = E("ssp245", "far", "d_freq"), E("ssp585", "far", "d_freq")
P(f"Relative to the model baseline (1985–2014; frequency {mb.freq:.1f}% of months, D = {mb.D:.2f} months, S = {mb.S:.2f}), the "
  f"{SEL} drought frequency changed little in the near future (2025–2050). It then increased robustly by the far future: by "
  f"{sgn(f245.wmean)} percentage points under SSP2-4.5 (10th–90th model range {f1(f245.p10)} to {f1(f245.p90)}) and by "
  f"{sgn(f585.wmean)} percentage points under SSP5-8.5 ({f1(f585.p10)} to {f1(f585.p90)}) (Table IV). Mean severity "
  f"({sgn(E('ssp245','far','d_S').wmean,2)} and {sgn(E('ssp585','far','d_S').wmean,2)}) and intensity "
  f"({sgn(E('ssp245','far','d_I').wmean,3)} and {sgn(E('ssp585','far','d_I').wmean,3)}) also increased robustly. Spatially, the increase "
  f"was robust in {RC('ssp245','far').pct_robust:.0f}% (SSP2-4.5) and {RC('ssp585','far').pct_robust:.0f}% (SSP5-8.5) of the 0.25° cells "
  f"of the plateau. It was largest in Attock, Chakwal and southern Jhelum and weakest in the humid Murree hills (Fig. 6).")
djf, mam, jja, son, dec = (S("ssp585", "far", s) for s in ("DJF", "MAM", "JJA", "SON", "Dec (sowing)"))
djf2, mam2 = S("ssp245", "far", "DJF"), S("ssp245", "far", "MAM")
P(f"This drying occurred despite a robust increase in annual precipitation ({sgn(E('ssp245','far','d_P').wmean)}% and "
  f"{sgn(E('ssp585','far','d_P').wmean)}%), because ET0 rose by {sgn(E('ssp245','far','d_ET0').wmean)}% and "
  f"{sgn(E('ssp585','far','d_ET0').wmean)}% and the rainfall gain was confined to the monsoon. Under SSP5-8.5, JJA precipitation "
  f"increased by {sgn(jja.d_P)}%, whereas DJF precipitation changed by {sgn(djf.d_P)}% while DJF ET0 rose by {sgn(djf.d_ET0)}%. Drought "
  f"frequency consequently increased robustly in winter ({sgn(djf.d_freq)} %-pt; SSP2-4.5 {sgn(djf2.d_freq)}) and spring "
  f"({sgn(mam.d_freq)} %-pt; SSP2-4.5 {sgn(mam2.d_freq)}). It decreased in the monsoon and post-monsoon seasons "
  f"({sgn(jja.d_freq)} and {sgn(son.d_freq)} %-pt). The drought frequency at the end of the wheat-sowing window (December {SEL}) "
  f"increased by {sgn(dec.d_freq)} %-pt (SSP5-8.5). The projected drying is therefore concentrated in the Rabi season, the season that "
  f"carries the rainfed wheat crop.")
P(f"In terms of global warming levels, the change in drought frequency was {sgn(G(1.5,'d_freq').wmean)} %-pt at +1.5 °C, "
  f"{sgn(G(2.0,'d_freq').wmean)} at +2 °C and {sgn(G(3.0,'d_freq').wmean)} at +3 °C (robust only at +3 °C). ET0 increased almost "
  f"linearly ({sgn(G(1.5,'d_ET0').wmean)}%, {sgn(G(2.0,'d_ET0').wmean)}% and {sgn(G(3.0,'d_ET0').wmean)}%), while the precipitation increase "
  f"was similar at all levels (Fig. 7). The drought signal therefore emerges only once warming exceeds about +2 °C, when evaporative "
  f"demand outpaces the rainfall gain.")

# ---------------- E. Return periods
H2("E. Joint Duration–Severity Return Periods")
b0 = t5.loc["Baseline (models)"]
tv = lambda s, c: float(t5.loc[s, c].split(" ")[0])  # noqa: E731
facs = [tv("Baseline (models)", c) / tv(f"{sc} far", c) for c in ("T_AND of 10-yr event", "T_AND of 25-yr event", "T_AND of 50-yr event")
        for sc in ("SSP2-4.5", "SSP5-8.5")]
fac_lo, fac_hi = min(facs), max(facs)
P(f"For the observed and all pooled model event sets, log-normal marginals fitted best for D and S, and the Gumbel copula was selected "
  f"by AIC (Kendall τ = {t5['Kendall τ'].min():.2f}–{t5['Kendall τ'].max():.2f}; Table V). With the large pooled samples "
  f"(n = {int(t5.Events[t5.index != 'Observed'].min())}–{int(t5.Events[t5.index != 'Observed'].max())}), the Kendall-process goodness-of-fit "
  f"test rejected the Gumbel copula, also after breaking ties in the integer durations. Mixing ten models produces a heterogeneous "
  f"dependence structure, so the parametric return periods were cross-checked with empirical joint exceedances. The baseline 25-year event "
  f"(D ≥ {ref.d.iloc[1]:.1f} months and S ≥ {ref.s.iloc[1]:.1f}) had a T_AND of {b0['T_AND of 25-yr event']} years in the baseline. "
  f"This shortened to {t5.loc['SSP2-4.5 far','T_AND of 25-yr event']} years (SSP2-4.5) and {t5.loc['SSP5-8.5 far','T_AND of 25-yr event']} "
  f"years (SSP5-8.5) by 2076–2100; the empirical estimates were "
  f"{t5.loc['SSP2-4.5 far','Empirical T_AND (10/25/50-yr event)'].split(' / ')[1]} and "
  f"{t5.loc['SSP5-8.5 far','Empirical T_AND (10/25/50-yr event)'].split(' / ')[1]} years. The baseline 50-year event became a "
  f"{t5.loc['SSP5-8.5 far','T_AND of 50-yr event'].split(' ')[0]}-year event under SSP5-8.5 (Fig. 8). Drought events of a given duration "
  f"and severity are therefore projected to recur {fac_lo:.1f} to {fac_hi:.1f} times more often by the end of the century.")

# ---------------- F. Exposure
H2("F. Exposure of Rainfed Crops")
P(f"Hotspots were defined as cells with a robust increase in {SEL} drought frequency. They covered "
  f"{exp_mid.loc['ssp585','wheat_exp']/1e3:.0f} × 10³ ha of rainfed wheat "
  f"({100*exp_mid.loc['ssp585','wheat_exp']/exp_mid.loc['ssp585','wheat_total']:.0f}% of the SPAM2010 rainfed wheat area) under SSP5-8.5 "
  f"in 2051–2075, against {exp_mid.loc['ssp245','wheat_exp']/1e3:.0f} × 10³ ha under SSP2-4.5. By 2076–2100 they covered "
  f"{exp_far.loc['ssp245','wheat_exp']/1e3:.0f} and {exp_far.loc['ssp585','wheat_exp']/1e3:.0f} × 10³ ha "
  f"({100*exp_far.loc['ssp585','wheat_exp']/exp_far.loc['ssp585','wheat_total']:.0f}% under SSP5-8.5; Table VI, Fig. 9). Attock "
  f"({d_far.loc['Attock','wheat_exp']/1e3:.0f} × 10³ ha) and Chakwal ({d_far.loc['Chakwal','wheat_exp']/1e3:.0f} × 10³ ha) carried the "
  f"largest exposed wheat areas, and Chakwal carried most of the exposed groundnut ({d_far.loc['Chakwal','gnut_exp']/1e3:.0f} of "
  f"{exp_far.loc['ssp585','gnut_exp']/1e3:.0f} × 10³ ha). SPAM2010 refers to 2010 and partly exceeds the WorldCover 2021 cropland, "
  f"so the absolute areas are indicative. The ranking of the districts is robust.")

# ---------------- G. Uncertainty & sensitivity
H2("G. Uncertainty and Sensitivity")
P(f"Model uncertainty dominated the projections (Fig. 10). For drought frequency it explained {HSF('Drought', 2050, 'model'):.0f}% of "
  f"the decadal variance in 2050 and {HSF('Drought', 2095, 'model'):.0f}% in 2095. Internal variability declined from "
  f"{HSF('Drought', 2030, 'internal'):.0f}% in 2030 to {HSF('Drought', 2095, 'internal'):.0f}% in 2095, and scenario uncertainty remained "
  f"below {max(HSF('Drought', y, 'scenario') for y in (2030, 2050, 2075, 2095)):.0f}%. For the annual water balance, model uncertainty "
  f"explained {HSF('water', 2050, 'model'):.0f}–{HSF('water', 2095, 'model'):.0f}%.")
ref_row = t7[t7.Test.str.startswith("Reference")]
hg = t7[t7.Test.str.contains("Hargreaves")]
th = t7[t7.Test.str.contains("Threshold")]
ab = t7[t7.Test.str.contains("Alternative baseline")]
nq = t7[t7.Test.str.contains("No QDM")]
P(f"The far-future increase in drought frequency (reference: {ref_row.iloc[0,2]:.1f} and {ref_row.iloc[1,2]:.1f} %-pt) was robust "
  f"to every sensitivity test (Table VII): Hargreaves ET0 ({hg.iloc[0,2]:.1f}, {hg.iloc[1,2]:.1f}), threshold −1.5 "
  f"({th.iloc[0,2]:.1f}, {th.iloc[1,2]:.1f}), the 1981–2010 baseline ({ab.iloc[0,2]:.1f}, {ab.iloc[1,2]:.1f}) and the uncorrected "
  f"NEX-GDDP ({nq.iloc[0,2]:.1f}, {nq.iloc[1,2]:.1f}). Hargreaves ET0 and the uncorrected data amplified the signal, so the PM-based, "
  f"bias-corrected estimate is conservative. The independent ISIMIP3b chain gave {isi.isimip_dfreq.mean():.1f} %-pt for the same five "
  f"GCMs under SSP5-8.5, against {isi.nex_dfreq.mean():.1f} %-pt from NEX-GDDP with QDM. The sign agreed for "
  f"{int((np.sign(isi.isimip_dfreq) == np.sign(isi.nex_dfreq)).sum())} of {len(isi)} GCMs. Both chains projected fewer droughts only for "
  f"{' and '.join(isi[isi.nex_dfreq < 0].model)}, the GCMs with the largest precipitation increases "
  f"({', '.join(f'{v:+.0f}%' for v in isi[isi.nex_dfreq < 0].nex_dP)} in NEX-GDDP).")

# ---------------- H. Discussion vs literature
H2("H. Comparison with Previous Studies")
P("The evaluation-to-projection chain followed [1]: multi-model CMIP6 evaluation against reanalysis and gridded observations, followed "
  "by Penman–Monteith-based SPEI projections. The result that evaporative demand turns an increase in precipitation into more frequent "
  "agricultural drought is consistent with the emphasis of [1] on ET0-sensitive indices. Ain et al. [2] analysed Kharif and Rabi droughts "
  "over the Potwar Plateau from two CORDEX regional models under RCP4.5 and RCP8.5. The present study extends that seasonal view to a "
  "skill-weighted ten-model CMIP6 ensemble under SSP2-4.5 and SSP5-8.5 and identifies the Rabi season as the season of increasing "
  "drought. The CHIRPS- and MODIS-based risk mapping of Goheer et al. [3] for 2000–2020 is complemented here by the VHI–SPEI-3 link and "
  "by district exposure under future climates; Attock and Chakwal emerged as the most exposed districts. For the Soan basin, Abbas et "
  "al. [4] and Sarwar et al. [5] characterised meteorological and hydrological droughts and their propagation from gauge records. The "
  "short propagation time found here with GloFAS discharge is consistent with the rapid hydrological response of the basin. Because "
  "WAPDA gauge data were not available, these propagation estimates should be confirmed with observed discharge.")
P("The main limitations were the following. No PMD station data were openly available. Gridded Penman–Monteith inputs came from "
  "TerraClimate rather than ERA5-Land. The open GloFAS record starts in 1997. Wheat yields were available only from GDHY (to 2016). The "
  "pooled-copula fit was formally rejected. All these departures from the methodology are documented in DEVIATIONS.md.")

doc.add_paragraph()
p = doc.add_paragraph()
p.paragraph_format.first_line_indent = Pt(0)
p.add_run("Note on traceability: ").bold = True
p.add_run("All numbers were generated from analysis/results_text/key_numbers.json and analysis/tables/*.csv "
          "(Potohar_Drought_Analysis.Rmd). Figures: analysis/figures/Fig01–Fig10, FigS1. Tables: analysis/tables/Table1–Table7.")
out = ROOT / "results_text" / "Results_Discussion.docx"
doc.save(out)
print("written", out)


