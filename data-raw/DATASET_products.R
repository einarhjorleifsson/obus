# Build the published catch tables from the raw archive.
#
#   raw HH  + .id                                  ->  to_https/HH.parquet
#   raw HH + raw HL  -> dr_HL_length()             ->  to_https/HL_length.parquet
#   raw HH + raw HL  -> dr_HL_summary()            ->  to_https/HL_summary.parquet
#
# Run DATASET_species.R first -- both catch tables join to species.parquet.
#
# Design choices, carried over deliberately:
#   - haulval = NULL: every HaulValidity code is kept. Callers filter.
#   - SpeciesValidity is not filtered either; it is carried as a column, so
#     anyone wanting the official DATRAS products can filter to "1".
#   - Everything stays lazy. DuckDB streams each table straight out to parquet;
#     nothing is collect()ed into R.
#
# Nothing here is published. The scp lines are printed at the end.

source("data-raw/build_helpers.R")

dr_cache_raw(c("HH", "HL"))

# ---- inputs -----------------------------------------------------------------
# Valid_Aphia -> aphia and SpeciesSex -> sex is obus's own naming layer, applied
# on top of opus's current names. It is a rename and nothing else: no values
# change, and the raw archive is left exactly as opus staged it.
hh <- dr_con_raw("HH", path = DR_RAW) |> dr_add_id()
hl <- dr_con_raw("HL", path = DR_RAW) |> dr_add_id() |>
  dplyr::rename(aphia = Valid_Aphia, sex = SpeciesSex)

species <- dr_con("species", path = DR_OUT)

message(sprintf("HH %s rows | HL %s rows | species %s rows",
                format(dr_n(hh), big.mark = ","),
                format(dr_n(hl), big.mark = ","),
                format(dr_n(species), big.mark = ",")))

# ---- the haul key, checked before anything is built on it -------------------
# .id is the join key for both catch tables. A duplicate would silently fan out
# every downstream join, so this is checked, not assumed.
id_check <- hh |>
  dplyr::summarise(n = dplyr::n(),
                   n_id = dplyr::n_distinct(.id),
                   n_na = sum(as.integer(is.na(.id)), na.rm = TRUE)) |>
  dplyr::collect()
message(sprintf("HH .id: %s rows, %s distinct, %s NA",
                format(id_check$n, big.mark = ","),
                format(id_check$n_id, big.mark = ","),
                format(id_check$n_na, big.mark = ",")))
if (id_check$n_id != id_check$n) {
  stop("HH .id is not unique -- a join on .id would fan out. Investigate ",
       "before publishing anything built on it.", call. = FALSE)
}

orphans <- hl |> dplyr::anti_join(dplyr::select(hh, .id), by = ".id") |> dr_n()
message(sprintf("HL rows with no matching HH haul: %s", format(orphans, big.mark = ",")))

# ---- build ------------------------------------------------------------------
message("\nHH ...")
dr_write(hh, "HH")

message("HL_length ...")
len <- dr_HL_length(hh, hl, species = species, haulval = NULL)
dr_write(len, "HL_length")

message("HL_summary ...")
smry <- dr_HL_summary(hh, hl, species = species, haulval = NULL)
dr_write(smry, "HL_summary")

# ---- cross-check ------------------------------------------------------------
# HL_summary's n_haul (from the recorded TotalNumber) and HL_length's summed
# length classes describe the same count whenever the source submission is
# internally consistent. They are computed from different fields by different
# routes, so a stable disagreement rate is the sharpest single check that both
# tables were built correctly -- and the residual is real data, not a bug: it
# is intrinsic to DataType == "C" (an independently reported rate need not
# match a raised length-frequency sum) plus rounding noise from non-integer
# SubsamplingFactors, and it concentrates in particular surveys rather than
# spreading evenly. The retired implementation measured 3.5% over 1,920,932
# groups; landing far from that means something changed.
message("\nCross-check: HL_summary n_totalnumber vs summed HL_length n_haul ...")
len_out  <- dr_con("HL_length",  path = DR_OUT)
smry_out <- dr_con("HL_summary", path = DR_OUT)

cmp <- smry_out |>
  dplyr::select(.id, aphia, n_totalnumber) |>
  dplyr::inner_join(
    len_out |>
      dplyr::group_by(.id, aphia) |>
      dplyr::summarise(n_len = sum(n_haul, na.rm = TRUE), .groups = "drop"),
    by = c(".id", "aphia")
  ) |>
  dplyr::filter(!is.na(n_totalnumber), !is.na(n_len)) |>
  dplyr::mutate(d = abs(n_totalnumber - n_len)) |>
  dplyr::summarise(
    groups  = dplyr::n(),
    # `abs > 0.5` reproduces the tolerance obus_retired measured its own 3.5%
    # at, and is kept only for that comparison -- it is NOT a good statistic.
    # 13,829 groups sit at a difference of *exactly* 0.5 (measured
    # 2026-08-31), so the threshold lands on a large cluster: whether a given
    # group falls above or below it comes down to the order DuckDB's parallel
    # sum() happened to add the length classes in, and the count drifts by
    # about +/-10 between identical runs. Reported as approximate for that
    # reason.
    #
    # `abs > 0.51` clears the cluster and is stable run to run -- use it as
    # the real figure. The relative variant is reported because a raw count
    # says nothing about whether a disagreement is material.
    gt_half  = sum(as.integer(d > 0.5), na.rm = TRUE),
    gt_stable = sum(as.integer(d > 0.51), na.rm = TRUE),
    gt_1pct  = sum(as.integer(d > 0.5 & d > 0.01 * n_totalnumber), na.rm = TRUE)
  ) |>
  dplyr::collect()

message(sprintf("  %s comparable groups", format(cmp$groups, big.mark = ",")))
message(sprintf("    abs > 0.51 (stable): %s (%.2f%%)   <- the figure to quote",
                format(cmp$gt_stable, big.mark = ","), 100 * cmp$gt_stable / cmp$groups))
message(sprintf("    abs > 0.5  (+/-10) : ~%s (%.2f%%)  <- benchmark only: retired measured 3.5%%",
                format(cmp$gt_half, big.mark = ","), 100 * cmp$gt_half / cmp$groups))
message(sprintf("    and also rel > 1%%  : %s (%.2f%%)",
                format(cmp$gt_1pct, big.mark = ","), 100 * cmp$gt_1pct / cmp$groups))

message("\nPublish with:")
for (f in c("HH", "HL_length", "HL_summary")) {
  message(sprintf("  scp data-raw/to_https/%s.parquet einarhj@heima.hafro.is:~/public_html/datras/%s.parquet", f, f))
}
