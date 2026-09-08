# Build the flag tables that sit alongside HL_length and HL_summary.
#
#   data-raw/hl_flag_code.csv  ->  to_https/hl_flag_code.parquet   (the lookup)
#   raw HH + raw HL + products ->  to_https/hl_flag.parquet        (the flags)
#
# Two deliberate shape decisions:
#
#   LONG, NOT A COLUMN. One row per (.id, Valid_Aphia, code), only for records that
#   carry a code. A record with three codes gets three rows, so nothing has to
#   be parsed out of a comma-separated string, and the table stays small.
#
#   A SEPARATE FILE, NOT A COLUMN IN THE PRODUCTS. HL_length.parquet is ~200 MB.
#   The flags encode the current understanding of the data; the data itself does
#   not change. Keeping them apart means revising a code costs a 2 MB republish
#   rather than a 200 MB one, and readers who do not need them pay nothing.
#
# The grain is .id x Valid_Aphia, which joins onto HL_summary directly and onto
# HL_length as a group property of every length row for that haul and species.
#
# Run after DATASET_products.R.

source("data-raw/build_helpers.R")

hh <- dr_con_raw("HH", path = DR_RAW) |> dr_add_id() |>
  dplyr::select(.id, DataType, HaulDuration)
hl <- dr_con_raw("HL", path = DR_RAW) |> dr_add_id()

len  <- dr_con("HL_length",  path = DR_OUT)
smry <- dr_con("HL_summary", path = DR_OUT)

# ---- per-group facts the rules are built from -------------------------------
# The raising factor's shape, from the length rows only. Whether it is exactly
# 1, and whether it is an integer, is what separates arithmetic rounding from a
# whole-fish disagreement.
sf <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0) |>
  dplyr::group_by(.id, Valid_Aphia) |>
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
  dplyr::count(.id, Valid_Aphia, SpeciesSex, DevelopmentStage, SpeciesCategory,
               LengthClass, NumberAtLength, SubsamplingFactor) |>
  dplyr::filter(n > 1) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(has_dup = TRUE)

# ---- the count path ---------------------------------------------------------
# Compare in SUBMISSION units. DataType C scales both sides by HaulDuration/60,
# so a genuine one-fish gap in a 30-minute haul would otherwise read as 0.5 and
# be dismissed as arithmetic.
cnt <- smry |>
  dplyr::select(.id, Valid_Aphia, n_totalnumber) |>
  dplyr::left_join(
    len |>
      dplyr::group_by(.id, Valid_Aphia) |>
      dplyr::summarise(n_len   = sum(n_haul, na.rm = TRUE),
                       .n_rows = dplyr::n(),
                       .n_ok   = sum(as.integer(!is.na(n_haul)), na.rm = TRUE),
                       .groups = "drop"),
    by = c(".id", "Valid_Aphia"), na_matches = "na"
  ) |>
  dplyr::inner_join(hh, by = ".id") |>
  dplyr::left_join(sf, by = c(".id", "Valid_Aphia"), na_matches = "na") |>
  dplyr::left_join(dup_len, by = c(".id", "Valid_Aphia"), na_matches = "na") |>
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
  dplyr::select(.id, Valid_Aphia, code)

# ---- the weight path --------------------------------------------------------
# A catch weight repeated across category codes is added once per category by
# obus's weight key. Under DataType P that repetition is the documented
# convention -- the raising factor IS category weight / sample weight, so the
# category weight necessarily appears on every pseudocategory row.
wgt_rep <- hl |>
  dplyr::filter(!is.na(SpeciesCategoryWeight)) |>
  dplyr::distinct(.id, Valid_Aphia, SpeciesCategory, SpeciesCategoryWeight) |>
  dplyr::group_by(.id, Valid_Aphia, SpeciesCategoryWeight) |>
  dplyr::summarise(n_cat_sharing = dplyr::n(), .groups = "drop") |>
  dplyr::filter(n_cat_sharing > 1) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::inner_join(hh, by = ".id") |>
  dplyr::mutate(
    code = dplyr::case_when(
      DataType == "P" ~ "WGT_CAT_REPEAT_P",
      DataType == "R" ~ "WGT_CAT_REPEAT_R",
      TRUE            ~ "WGT_CAT_REPEAT_R"
    )
  ) |>
  dplyr::select(.id, Valid_Aphia, code)

# ---- DataType C: subsampling that was raised away before submission --------
# Under C the submission arrives already raised to one hour and ICES instructs
# SubFactor to be reported as 1 (DATRAS FAQ, "DataType C" block), so on-board
# subsampling leaves no trace in the raising factor. It does leave one in NoMeas
# (SubsampledNumber), which the same block makes optional ("or report -9"):
# where NoMeas IS reported and falls below the back-computed catch, subsampling
# demonstrably happened and the submitter raised it away.
#
# Computed at HL's own subsampling grain -- haul x species x sex x category --
# because that is the grain NoMeas is reported at, then reduced to this table's
# grain. The half-fish tolerance matches the other count rules.
c_hidden <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0,
                !is.na(SubsampledNumber)) |>
  dplyr::inner_join(dplyr::filter(hh, DataType == "C", HaulDuration > 0),
                    by = ".id") |>
  dplyr::group_by(.id, Valid_Aphia, SpeciesSex, SpeciesCategory) |>
  dplyr::summarise(
    n_back = sum(NumberAtLength, na.rm = TRUE) *
             max(HaulDuration, na.rm = TRUE) / 60,
    nomeas = max(SubsampledNumber, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::filter(nomeas < n_back - 0.5) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(code = "CNT_C_SUBSAMPLE_HIDDEN")

# ---- DataType C carrying a raising factor it should not have ----------------
# ICES instructs a "C" submission to report SubFactor as 1 (DATRAS FAQ). Where
# it is greater than 1 the submission is not shaped like C at all: TotalNo
# matches sum(HLNoAtLngt) x SubFactor and sum(HLNoAtLngt) matches NoMeas, i.e.
# HLNoAtLngt is the measured subsample, exactly as under DataType R.
#
# obus applies BOTH multipliers on these (see dr_add_n_and_cpue), following the
# DATRAS R package's 2023 correction rather than WKABSENS's one-multiplier
# recipe, which predates it. This flag is the per-record record of that choice:
# n_haul here rests on a rule ICES has not published, and 35 of the 36 hauls
# are marked HaulValidity "V", so nothing else in the archive marks them.
c_conflict <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0,
                SubsamplingFactor > 1) |>
  dplyr::inner_join(dplyr::filter(hh, DataType == "C"), by = ".id") |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(code = "CNT_C_SUBFACTOR_CONFLICT")

# ---- does the submission agree with its own arithmetic? ---------------------
# The generic form of the DataType/SubFactor cross-check ICES's Data Centre was
# actioned to produce at WKDATR 2013 (s3.2.2.1) and which does not appear in any
# ICES tooling: icesDatsuQC mentions neither field. It needs no per-survey
# knowledge -- every submission unit states TotalNo, SubFactor and a set of
# length rows, and exactly one of two identities should hold:
#
#   TotalNo == sum(HLNoAtLngt)               the lengths are already raised
#   TotalNo == sum(HLNoAtLngt) * SubFactor   the lengths are the subsample
#
# ICES's own FAQ permits BOTH readings of HLNoAtLngt ("TotalNo = Sum(HLNoAtLngt)
# or NoMeas = Sum(HLNoAtLngt)"), which is why this has to be measured rather
# than assumed.
#
# Grain: haul x species x sex x category, which is where TotalNo and SubFactor
# are reported -- coarser than that and categories with different factors get
# mixed. Everything is converted to FISH IN THE HAUL first, so DataType C's
# hourly convention does not inflate the tolerance (an unscaled test reports
# every 1-fish gap in a 30-minute C haul as 2 and floods on near-misses).
#
# DataType P is excluded on purpose. Under the pseudocategory convention the
# factor is category weight / sample weight, so neither identity applies; left
# in, GB-SCT alone contributes ~2,500 false positives, declaring a median
# SubFactor of 2.07 against an implied 17.88. "-9" is excluded as an invalid haul.
ident <- hl |>
  dplyr::filter(!is.na(LengthClass), NumberAtLength != 0, !is.na(TotalNumber)) |>
  dplyr::inner_join(hh, by = ".id") |>
  dplyr::filter(DataType %in% c("R", "S", "C"), HaulDuration > 0) |>
  dplyr::mutate(mult = dplyr::if_else(DataType == "C", HaulDuration / 60, 1)) |>
  dplyr::group_by(.id, Valid_Aphia, SpeciesSex, SpeciesCategory) |>
  dplyr::summarise(
    total_fish = max(TotalNumber, na.rm = TRUE)     * max(mult, na.rm = TRUE),
    len_fish   = sum(NumberAtLength, na.rm = TRUE)  * max(mult, na.rm = TRUE),
    ssf        = max(SubsamplingFactor, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  dplyr::filter(len_fish > 0, !is.na(ssf)) |>
  dplyr::mutate(
    tol            = pmax(0.5, 1e-6 * abs(total_fish)),
    implied        = total_fish / len_fish,
    fits_raised    = abs(total_fish - len_fish)       <= tol,
    fits_subsample = abs(total_fish - len_fish * ssf) <= tol
  )

# Declared 1, but the record implies a real factor. The 1.5 floor keeps rounding
# noise out; the 1-fish floor keeps sub-unit arithmetic out (CNT_ARITH's job).
sf_reset <- ident |>
  dplyr::filter(!fits_raised, ssf <= 1, implied >= 1.5,
                abs(total_fish - len_fish) >= 1) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(code = "CNT_SF_RESET")

# Declared > 1 and neither identity holds: no raising is derivable at all.
sf_unrec <- ident |>
  dplyr::filter(ssf > 1, !fits_raised, !fits_subsample,
                abs(total_fish - len_fish * ssf) >= 1) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(code = "CNT_SF_UNRECONCILED")

wgt_none <- smry |>
  dplyr::filter(is.na(w_haul)) |>
  dplyr::distinct(.id, Valid_Aphia) |>
  dplyr::mutate(code = "WGT_NONE")

# ---- record properties (whole-haul, broadcast to every species) -------------
rec <- dplyr::union_all(
  hh |> dplyr::filter(HaulDuration <= 0) |> dplyr::select(.id) |>
    dplyr::mutate(code = "REC_DUR_NONPOS"),
  hh |> dplyr::filter(DataType == "-9") |> dplyr::select(.id) |>
    dplyr::mutate(code = "REC_DATATYPE_INVALID")
) |>
  dplyr::inner_join(dplyr::distinct(smry, .id, Valid_Aphia), by = ".id") |>
  dplyr::select(.id, Valid_Aphia, code)

# ---- assemble ---------------------------------------------------------------
flags <- dplyr::union_all(cnt, wgt_rep) |>
  dplyr::union_all(wgt_none) |>
  dplyr::union_all(c_hidden) |>
  dplyr::union_all(c_conflict) |>
  dplyr::union_all(sf_reset) |>
  dplyr::union_all(sf_unrec) |>
  dplyr::union_all(rec) |>
  dplyr::distinct(.id, Valid_Aphia, code)

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
