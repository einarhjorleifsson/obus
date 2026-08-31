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

# Compare in SUBMISSION units, and count whole fish -- not haul-scaled values
# against a fractional tolerance.
#
# Two things that a magnitude threshold gets wrong, both found 2026-08-31:
#   1. DataType "C" scales BOTH sides by HaulDuration/60, so a genuine one-fish
#      disagreement in a 30-minute haul shows up as 0.5 and slips under any
#      sub-unit tolerance. Dividing the scaling out first is what makes the gap
#      mean "fish".
#   2. A sub-unit gap is arithmetic, full stop: a non-integer SubsamplingFactor
#      applied to integer counts cannot produce an integer, while the reported
#      TotalNumber is one. Counting those as "disagreements" inflates the rate
#      with something that carries no information about the data.
#
# So: gap < 1 fish is arithmetic and excluded; gap >= 1 fish is real.
cmp <- smry_out |>
  dplyr::select(.id, aphia, n_totalnumber) |>
  dplyr::inner_join(
    len_out |>
      dplyr::group_by(.id, aphia) |>
      dplyr::summarise(n_len = sum(n_haul, na.rm = TRUE), .groups = "drop"),
    by = c(".id", "aphia"), na_matches = "na"
  ) |>
  dplyr::filter(!is.na(n_totalnumber), !is.na(n_len)) |>
  dplyr::inner_join(dplyr::select(hh, .id, DataType, HaulDuration), by = ".id") |>
  dplyr::mutate(
    gap = abs(n_totalnumber - n_len) /
            dplyr::if_else(DataType == "C", HaulDuration / 60, 1)
  ) |>
  dplyr::summarise(
    groups     = dplyr::n(),
    exact      = sum(as.integer(gap < 1e-6), na.rm = TRUE),
    sub_unit   = sum(as.integer(gap >= 1e-6 & gap < 0.999), na.rm = TRUE),
    real       = sum(as.integer(gap >= 0.999), na.rm = TRUE),
    real_big   = sum(as.integer(gap >= 5.999), na.rm = TRUE)
  ) |>
  dplyr::collect()

message(sprintf("  %s comparable groups", format(cmp$groups, big.mark = ",")))
message(sprintf("    exact match          : %s (%.2f%%)",
                format(cmp$exact, big.mark = ","), 100 * cmp$exact / cmp$groups))
message(sprintf("    < 1 fish (arithmetic): %s (%.2f%%)  -- excluded, not a data issue",
                format(cmp$sub_unit, big.mark = ","), 100 * cmp$sub_unit / cmp$groups))
message(sprintf("    >= 1 fish (real)     : %s (%.2f%%)  <- the figure to quote",
                format(cmp$real, big.mark = ","), 100 * cmp$real / cmp$groups))
message(sprintf("      of which >= 6 fish : %s (%.2f%%)  -- the directional, systematic part",
                format(cmp$real_big, big.mark = ","), 100 * cmp$real_big / cmp$groups))

message("\nPublish with:")
for (f in c("HH", "HL_length", "HL_summary")) {
  message(sprintf("  scp data-raw/to_https/%s.parquet einarhj@heima.hafro.is:~/public_html/datras/%s.parquet", f, f))
}
