# v2.1 (Phase B) data check: discontinuities between the historical (to 2014) and scenario (from 2015) NEX-GDDP-CMIP6 files.
# For every model and variable: relative (pr, rsds, sfcWind) or absolute (tasmax, tasmin, hurs) change of the regional mean from
# 2005-2014 to 2015-2024, compared with the across-model distribution (robust z = (x - median) / (1.4826 * MAD)).
# Output: 06_gcm_eval/scenario_discontinuity_check.csv
suppressMessages({ library(data.table); library(ncdf4) })
cfg <- yaml::read_yaml(Sys.getenv("P6_CONFIG", "config.yaml"))
GM <- file.path(cfg$paths$root, "06_gcm_eval", "gcm_monthly")
rd <- function(f, v) { nc <- nc_open(f); a <- ncvar_get(nc, v); t <- ncvar_get(nc, "time"); tu <- ncatt_get(nc, "time", "units")$value; nc_close(nc)
  y <- as.integer(format(as.Date(sub("^days since ([0-9-]+).*", "\\1", tu)) + t, "%Y")); data.table(year = y, x = apply(a, 3, mean, na.rm = TRUE)) }
mods <- sub("_ssp245.nc$", "", list.files(GM, "_ssp245.nc$"))
R <- rbindlist(lapply(mods, function(m) rbindlist(lapply(c("pr", "tasmax", "tasmin", "hurs", "rsds", "sfcWind"), function(v) {
  h <- rd(file.path(GM, paste0(m, "_historical.nc")), v)[year >= 2005]; s <- rd(file.path(GM, paste0(m, "_ssp245.nc")), v)[year <= 2024]
  rel <- v %in% c("pr", "rsds", "sfcWind")
  data.table(model = m, variable = v, change = if (rel) 100 * (mean(s$x) / mean(h$x) - 1) else mean(s$x) - mean(h$x)) }))))
R[, z := (change - median(change)) / (1.4826 * mad(change)), by = variable]
R[, flag := abs(z) > 5]
fwrite(R, file.path(cfg$paths$root, "06_gcm_eval", "scenario_discontinuity_check.csv"))
print(R[flag == TRUE]); cat("models checked:", length(mods), "\n")
print(R[, .(median_change = round(median(change), 2), mad = round(mad(change), 2)), by = variable])
