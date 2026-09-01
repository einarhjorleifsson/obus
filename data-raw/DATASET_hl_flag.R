# Build the flag tables that sit alongside HL_length and HL_summary.
#
#   data-raw/hl_flag_code.csv  ->  to_https/hl_flag_code.parquet   (the lookup)
#   raw HH + raw HL + products ->  to_https/hl_flag.parquet        (the flags)
#
# Two deliberate shape decisions:
#
#   LONG, NOT A COLUMN. One row per (.id, aphia, code), only for records that
#   carry a code. A record with three codes gets three rows, so nothing has to
#   be parsed out of a comma-separated string, and the table stays small.
#
#   A SEPARATE FILE, NOT A COLUMN IN THE PRODUCTS. HL_length.parquet is ~200 MB.
#   The flags encode the current understanding of the data; the data itself does
#   not change. Keeping them apart means revising a code costs a 2 MB republish
#   rather than a 200 MB one, and readers who do not need them pay nothing.
#
# The grain is .id x aphia, which joins onto HL_summary directly and onto
# HL_length as a group property of every length row for that haul and species.
#
# Run after DATASET_products.R.

source("data-raw/build_helpers.R")

hh <- dr_con_raw("HH", path = DR_RAW) |> dr_add_id() |>
  dplyr::select(.id, DataType, HaulDuration)
hl <- dr_con_raw("HL", path = DR_RAW) |> dr_add_id() |>
  dplyr::rename(aphia = Valid_Aphia, sex = SpeciesSex)

len  <- dr_con("HL_length",  path = DR_OUT)
smry <- dr_con("HL_summary", path = DR_OUT)

# ---- per-group facts the rules are built from -------------------------------
# The raising factor's shape, from the length rows only. Whether it is exactly
# 1, and whether it is an integer, is what separates arithmetic rounding from a
# whole-fish disagreement.
sf <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0) |>
  dplyr::group_by(.id, aphia) |>
  dplyr::summarise(
    sf_min   = min(SubsamplingFactor, na.rm = TRUE),
    sf_max   = max(SubsamplingFactor, na.rm = TRUE),
    sf_na    = sum(as.integer(is.na(SubsamplingFactor)), na.rm = TRUE),
    n_cat    = dplyr::n_distinct(SpeciesCategory),
    .groups  = "drop"
  ) |>
  dplyr::mutate(sf_is_1 = sf_min == 1 & sf_max == 1)

# Exact duplicate length rows within a haul x species: the same measurement
# submitted more than once, which inflates the reconstructed total only.
dup_len <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0) |>
  dplyr::count(.id, aphia, sex, DevelopmentStage, SpeciesCategory,
               LengthClass, NumberAtLength, SubsamplingFactor) |>
  dplyr::filter(n > 1) |>
  dplyr::distinct(.id, aphia) |>
  dplyr::mutate(has_dup = TRUE)

# ---- the count path ---------------------------------------------------------
# Compare in SUBMISSION units. DataType C scales both sides by HaulDuration/60,
# so a genuine one-fish gap in a 30-minute haul would otherwise read as 0.5 and
# be dismissed as arithmetic.
cnt <- smry |>
  dplyr::select(.id, aphia, n_totalnumber) |>
  dplyr::left_join(
    len |>
      dplyr::group_by(.id, aphia) |>
      dplyr::summarise(n_len   = sum(n_haul, na.rm = TRUE),
                       .n_rows = dplyr::n(),
                       .n_ok   = sum(as.integer(!is.na(n_haul)), na.rm = TRUE),
                       .groups = "drop"),
    by = c(".id", "aphia"), na_matches = "na"
  ) |>
  dplyr::inner_join(hh, by = ".id") |>
  dplyr::left_join(sf, by = c(".id", "aphia"), na_matches = "na") |>
  dplyr::left_join(dup_len, by = c(".id", "aphia"), na_matches = "na") |>
  dplyr::mutate(
    scale = dplyr::if_else(DataType == "C", HaulDuration / 60, 1),
    gap   = (n_totalnumber - n_len) / scale,
    agap  = abs(gap)
  ) |>
  dplyr::mutate(
    # Order matters. "No length measurements" must be tested on whether length
    # rows EXIST, not on whether the raised sum came out NA -- a group whose
    # raising factor is missing has lengths that simply cannot be raised, and
    # calling that "no length measurements" would be wrong.
    code = dplyr::case_when(
      is.na(.n_rows)                        ~ "CNT_NO_LENGTH",
      .n_ok == 0 | sf_na > 0                ~ "CNT_SF_MISSING",
      is.na(n_totalnumber) | is.na(n_len)   ~ NA_character_,
      agap < 1e-6                           ~ NA_character_,
      agap < 0.999                          ~ "CNT_ARITH",
      !is.na(has_dup)                       ~ "CNT_LEN_DUP",
      agap < 2.999                          ~ "CNT_SMALL_SYM",
      DataType == "C" & agap < 5.999        ~ "CNT_C_SMALL",
      gap < 0 & agap > 50                   ~ "CNT_LEN_HIGH",
      DataType == "C"                       ~ "CNT_C_SMALL",
      gap > 0 & sf_is_1                     ~ "CNT_RAISE_LOST",
      gap > 0 & agap <= 50                  ~ "CNT_DIRECTIONAL",
      TRUE                                  ~ "CNT_OTHER"
    )
  ) |>
  dplyr::filter(!is.na(code)) |>
  dplyr::select(.id, aphia, code)

# ---- the weight path --------------------------------------------------------
# A catch weight repeated across category codes is added once per category by
# obus's weight key. Under DataType P that repetition is the documented
# convention -- the raising factor IS category weight / sample weight, so the
# category weight necessarily appears on every pseudocategory row.
wgt_rep <- hl |>
  dplyr::filter(!is.na(SpeciesCategoryWeight)) |>
  dplyr::distinct(.id, aphia, SpeciesCategory, SpeciesCategoryWeight) |>
  dplyr::group_by(.id, aphia, SpeciesCategoryWeight) |>
  dplyr::summarise(n_cat_sharing = dplyr::n(), .groups = "drop") |>
  dplyr::filter(n_cat_sharing > 1) |>
  dplyr::distinct(.id, aphia) |>
  dplyr::inner_join(hh, by = ".id") |>
  dplyr::mutate(
    code = dplyr::case_when(
      DataType == "P" ~ "WGT_CAT_REPEAT_P",
      DataType == "R" ~ "WGT_CAT_REPEAT_R",
      TRUE            ~ "WGT_CAT_REPEAT_R"
    )
  ) |>
  dplyr::select(.id, aphia, code)

wgt_none <- smry |>
  dplyr::filter(is.na(w_haul)) |>
  dplyr::distinct(.id, aphia) |>
  dplyr::mutate(code = "WGT_NONE")

# ---- record properties (whole-haul, broadcast to every species) -------------
rec <- dplyr::union_all(
  hh |> dplyr::filter(HaulDuration <= 0) |> dplyr::select(.id) |>
    dplyr::mutate(code = "REC_DUR_NONPOS"),
  hh |> dplyr::filter(DataType == "-9") |> dplyr::select(.id) |>
    dplyr::mutate(code = "REC_DATATYPE_INVALID")
) |>
  dplyr::inner_join(dplyr::distinct(smry, .id, aphia), by = ".id") |>
  dplyr::select(.id, aphia, code)

# ---- assemble ---------------------------------------------------------------
flags <- dplyr::union_all(cnt, wgt_rep) |>
  dplyr::union_all(wgt_none) |>
  dplyr::union_all(rec) |>
  dplyr::distinct(.id, aphia, code)

message("\nflag counts by code:")
tally <- flags |> dplyr::count(code) |> dplyr::arrange(dplyr::desc(n)) |> dplyr::collect()
for (i in seq_len(nrow(tally))) {
  message(sprintf("  %-22s %s", tally$code[i], format(tally$n[i], big.mark = ",")))
}
message(sprintf("  %-22s %s", "TOTAL rows", format(sum(tally$n), big.mark = ",")))

dr_write(flags, "hl_flag")

# ---- the lookup -------------------------------------------------------------
codes <- utils::read.csv("data-raw/hl_flag_code.csv", stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(codes$code))
missing <- setdiff(tally$code, codes$code)
if (length(missing)) stop("codes emitted but not documented: ", paste(missing, collapse = ", "))
unused  <- setdiff(codes$code, tally$code)
if (length(unused)) message("\nnote: documented but not emitted: ", paste(unused, collapse = ", "))

dr_write(dplyr::copy_to(duckdbfs::cached_connection(), codes,
                        "_obus_flag_code", overwrite = TRUE),
         "hl_flag_code")

message("\nPublish with:")
for (f in c("hl_flag", "hl_flag_code")) {
  message(sprintf("  scp data-raw/to_https/%s.parquet einarhj@heima.hafro.is:~/public_html/datras/%s.parquet", f, f))
}
