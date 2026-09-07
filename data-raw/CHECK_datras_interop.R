# Live interop check: obus's published tables vs DATRAS/DATRASextra's own
# computation, on the same real data.
#
# Run by hand. Nothing here is package code and nothing is published; this is
# the empirical answer to "could DATRAS/DATRASextra live on HL_length +
# HL_summary instead of raw HL?" -- asked and answered against real numbers
# rather than by reading both implementations.
#
# TEST BED: DATRASextra's bundled `dab` -- a genuine DATRASraw for NS-IBTS
# 2020-2023 Q1+Q3, Limanda limanda (Valid_Aphia 127139), 2,651 hauls, 26,737
# HL rows. Built 2026-03-04 by download_datras() |> read_datras() |>
# clean_datras() |> subset(Valid_Aphia == "127139"), so it is already cleaned
# to HaulVal == "V" and StdSpecRecCode == 1 and obus's side is filtered to
# match. It happens to cover every branch that matters: all three raising
# conventions (DataType C/P/R), the CatIdentifier "11"+"12" pair obus
# documents as a shared-total hazard, pseudocategory "21" under DataType P,
# three LngtCodes, and SpecVal 1/6/10.
#
# SCOPE IS INTERSECTED ON PURPOSE. The fixture is missing 9 hauls obus has
# (section 1); comparing counts across a differing haul set would report that
# one scope difference over and over as if it were many numeric ones.
#
# Requires DATRAS and DATRASextra (GitHub-only, hence not a package
# dependency) and network access to the published parquets.

suppressMessages({
  library(dplyr)
  ## Needs DATRAS >= 1.1.1 and DATRASextra >= 0.4.0 -- both GitHub-only, and
  ## calc_stratified_index() exists only in the latter:
  ##   remotes::install_github("DTUAqua/DATRAS/DATRAS")
  ##   remotes::install_github("tokami/DATRASextra")
  ## Verified against 1.1.1 / 0.4.0 on 2026-09-04: adapter 11/11, interop 25/25.
  ## (This used to pkgload::load_all() the repos from absolute paths, which
  ## only worked on one machine.)
  library(DATRAS)
  library(DATRASextra)
})
library(obus)

PASS <- 0L; FAIL <- 0L
ok <- function(label, passed, detail = "") {
  if (isTRUE(passed)) PASS <<- PASS + 1L else FAIL <<- FAIL + 1L
  cat(sprintf("  [%s] %-56s %s\n", if (isTRUE(passed)) "OK  " else "DIFF",
              label, detail))
}
note <- function(...) cat(sprintf("  [note] %s\n", sprintf(...)))
hdr  <- function(x) cat(sprintf("\n== %s %s\n", x, strrep("=", max(0, 66 - nchar(x)))))

## By default the bundled fixture. Set OBUS_DAB_RDS to a saved datras_raw to
## run the same checks against a freshly downloaded one -- which is how the
## "stale snapshot" diagnosis in section 6 was confirmed.
.dab_rds <- Sys.getenv("OBUS_DAB_RDS", "")
if (nzchar(.dab_rds)) {
  dab <- readRDS(.dab_rds)
  cat(sprintf("FIXTURE: %s (freshly built)\n", .dab_rds))
} else {
  dab <- get("dab")
  cat("FIXTURE: DATRASextra's bundled `dab` (built 2026-03-04)\n")
}
APHIA <- 127139L

hh_d <- dab[["HH"]]
hl_d <- dab[["HL"]]

hh_o_all <- dr_con("HH") |>
  filter(Survey == "NS-IBTS", Year >= 2020L, Year <= 2023L,
         Quarter %in% c(1L, 3L),
         HaulValidity == "V", StandardSpeciesCode == "1") |>
  select(.id, StationName, DataType, HaulDuration) |>
  collect()

hdr("1. scope: do the two sides describe the same hauls?")
id_d <- as.character(hh_d$haul.id)
id_o <- hh_o_all$.id
common <- intersect(id_d, id_o)

## A missing StationName is encoded differently on the two sides, and the
## difference is created by DATRASextra's own zip round-trip, not by obus:
##   straight from icesDatras  StNo is NA   -> paste() gives "...:GOV:NA:37"
##   after write_datras()      StNo is ""   -> paste() gives "...:GOV::37"
## because write_datras() writes na = "" and readICES()'s na.strings does not
## include "", so read.csv reads the blank back as an empty string on a
## character column. Same haul, two different haul.ids depending on whether
## the object was round-tripped. Normalise before comparing haul SETS.
norm_id <- function(x) gsub("::", ":NA:", x, fixed = TRUE)
ok("the two sides describe the same hauls (after normalising the token)",
   length(setdiff(norm_id(id_d), id_o)) == 0,
   sprintf("fixture hauls absent from obus: %s",
           length(setdiff(norm_id(id_d), id_o))))
ok("obus's token matches DATRAS's own paste() convention, pre-round-trip",
   all(!grepl("::", id_o, fixed = TRUE)),
   sprintf("%s fixture ids carry the empty-field form",
           sum(grepl("::", id_d, fixed = TRUE))))
extra <- setdiff(id_o, id_d)
note("obus has %s hauls the fixture lacks (%s vs %s). ALL %s have StationName",
     length(extra), length(id_o), length(id_d), length(extra))
note("missing -- the fixture has none at all. VERIFIED 2026-09-03: all 9 are")
note("present in a fresh download, so the fixture is simply a 2026-03-04")
note("snapshot of an archive ICES has since revised. See section 6.")
note("Comparisons below run on the %s common hauls.", length(common))

hh_o <- hh_o_all |> filter(.id %in% common)
len_o <- dr_con("HL_length") |>
  filter(Survey == "NS-IBTS", Year >= 2020L, Year <= 2023L,
         Quarter %in% c(1L, 3L), Valid_Aphia == APHIA) |>
  collect() |> filter(.id %in% common)
smry_o <- dr_con("HL_summary") |>
  filter(Survey == "NS-IBTS", Year >= 2020L, Year <= 2023L,
         Quarter %in% c(1L, 3L), Valid_Aphia == APHIA) |>
  collect() |> filter(.id %in% common)
hl_d <- hl_d |> filter(as.character(haul.id) %in% common)

hdr("2. type setting: DATRAS's classes vs obus's, field by field")
type_map <- tribble(
  ~concept,         ~tbl, ~datras_col,   ~obus_col,
  "haul key",       "HH", "haul.id",     ".id",
  "survey",         "HH", "Survey",      "Survey",
  "year",           "HH", "Year",        "Year",
  "quarter",        "HH", "Quarter",     "Quarter",
  "haul duration",  "HH", "HaulDur",     "HaulDuration",
  "data type",      "HH", "DataType",    "DataType",
  "species code",   "HL", "Valid_Aphia", "Valid_Aphia",
  "latin name",     "HL", "Species",     "latin",
  "length (cm)",    "HL", "LngtCm",      "length_cm",
  "raised count",   "HL", "Count",       "n_haul",
  "measured count", "HL", "HLNoAtLngt",  "n_measured",
  "sex",            "HL", "Sex",         "SpeciesSex",
  "dev stage",      "HL", "DevStage",    "DevelopmentStage",
  "record type",    "HL", "SpecVal",     "SpeciesValidity"
)
obus_side <- function(col) {
  for (d in list(hh_o_all, len_o)) if (col %in% names(d)) return(d[[col]])
  NULL
}
type_map <- type_map |> rowwise() |>
  mutate(datras_class = class(dab[[tbl]][[datras_col]])[1],
         obus_class   = class(obus_side(obus_col))[1],
         same         = datras_class == obus_class) |>
  ungroup()
print(as.data.frame(type_map[, c("concept", "datras_col", "datras_class",
                                 "obus_col", "obus_class", "same")]))
cat(sprintf("\n  %d of %d shared fields carry the same R class.\n",
            sum(type_map$same), nrow(type_map)))
note("Every mismatch is DATRAS's read-time coercion, not a value difference:")
note("readICES() uses stringsAsFactors = TRUE and addExtraVariables() then")
note("factor()s Year and Quarter. obus keeps opus's staged types. So DATRAS")
note("gives factors where obus gives character, and factor Year/Quarter where")
note("obus gives integer. Consequences a consumer will actually hit:")
note("  - factor Year needs as.integer(as.character(x)), not as.integer(x)")
note("  - SpecVal is integer in DATRAS, character in obus: SpecVal == 1 vs")
note("    SpeciesValidity == \"1\"")
note("  - Valid_Aphia is numeric in DATRAS, integer in obus (joins fine)")
note("The VALUES are then checked field by field below.")

hdr("3. missingness: DATRAS's \"\" factor level vs obus's NA")
ok("DATRAS encodes unsexed Sex as \"\", never NA",
   sum(as.character(hl_d$Sex) == "", na.rm = TRUE) > 0 && sum(is.na(hl_d$Sex)) == 0,
   sprintf("\"\"=%s NA=%s", sum(as.character(hl_d$Sex) == ""), sum(is.na(hl_d$Sex))))
ok("obus encodes the same records as NA", sum(is.na(len_o$SpeciesSex)) > 0,
   sprintf("NA=%s of %s rows", sum(is.na(len_o$SpeciesSex)), nrow(len_o)))
# Restricted to rows carrying a length: HL_length has no row for the 2
# blank-LngtCode records, so comparing against ALL dab rows reports those 2
# as a sex difference, which they are not.
sex_d <- hl_d |> filter(!is.na(LngtCm)) |>
  transmute(.id = as.character(haul.id),
            s = na_if(as.character(Sex), "")) |> distinct()
sex_o <- len_o |> transmute(.id, s = SpeciesSex) |> distinct()
ok("once \"\" is mapped to NA the (haul, sex) sets agree",
   setequal(paste(sex_d$.id, sex_d$s), paste(sex_o$.id, sex_o$s)),
   sprintf("%s vs %s pairs", nrow(sex_d), nrow(sex_o)))

hdr("4. length conversion: LngtCm vs length_cm")
lc_d <- hl_d |> filter(!is.na(LngtCm)) |>
  transmute(.id = as.character(haul.id), l = as.numeric(LngtCm)) |> distinct()
lc_o <- len_o |> transmute(.id, l = length_cm) |> distinct()
ok("distinct (haul, length) pairs identical",
   setequal(paste(lc_d$.id, lc_d$l), paste(lc_o$.id, lc_o$l)),
   sprintf("%s vs %s pairs", nrow(lc_d), nrow(lc_o)))
note("The 2 fixture rows with a blank LngtCode (LngtClas NA) are absent from")
note("HL_length by design -- obus filters !is.na(LengthClass) -- and DATRAS")
note("keeps them with LngtCm NA, where cut() drops them from the spectrum.")

hdr("5. measurement resolution: get_accuracy_cm() vs max(accuracy)")
acc_d <- suppressWarnings(get_accuracy_cm(dab))
ok("coarsest resolution agrees",
   isTRUE(all.equal(acc_d, max(len_o$accuracy, na.rm = TRUE))),
   sprintf("DATRAS %s cm | obus %s cm", acc_d, max(len_o$accuracy, na.rm = TRUE)))
map_lc <- c(`.` = 0.1, `0` = 0.5, `1` = 1, `2` = 2, `5` = 5)
ok("obus's per-row accuracy is the same LngtCode mapping",
   setequal(sort(unique(len_o$accuracy)),
            sort(unname(map_lc[setdiff(as.character(unique(hl_d$LngtCode)), "")]))),
   sprintf("obus %s", paste(sort(unique(len_o$accuracy)), collapse = "/")))

hdr("6. the fixture is a STALE SNAPSHOT, not a defect in either package")
# The 10 Scottish hauls below are where `dab` disagrees with obus. Established
# 2026-09-03, by re-downloading NS-IBTS 2020-2023 Q1+Q3 from ICES:
#
#   source                rows  DateofCalculation      CatIdentifier
#   dab (2026-03-04)       424  20220125               1 (all)
#   obus published         424  2026-06-25             11 (415), 12 (9)
#   fresh XML (today)      424  20260625               11 (415), 12 (9)
#
# The SAME 424 GB-SCT records were recalculated by ICES on 2026-06-25, after
# the fixture was built. That recalculation split the flat category "1" into
# the real subsampling categories 11/12 and restored SubFactor 10.855 in place
# of 1. Across the whole species-slice, 13,308 of 26,824 records now carry the
# 2026-06-25 stamp.
#
# Checked record by record against a fresh download: 26,824 records each side,
# 0 fresh-only keys, 0 obus-only keys, 0 SubFactor differences, 0 count
# differences. obus's published HL is equivalent to a download made today.
# The fixture's 9 missing hauls are likewise all present now, and the fresh
# haul set under dab's own cleaning filter is IDENTICAL to obus's 2,660.
#
# So this is not the CSV route (download_datras() uses getDatrasExchange() ->
# icesDatras::getDATRAS(), the XML/ASMX service), and not the build pipeline
# (nothing in DATRASextra assigns to SubFactor, CatIdentifier or HLNoAtLngt).
# It is ICES revising its own archive, and DateofCalculation is how to see it.
#
# NOTE: the fixture cannot currently be rebuilt with its own tooling --
# icesDatras::getDATRAS("HH", ...) now returns Year as CHARACTER, and
# DATRAS:::addExtraVariables() computes Year + (Month-1)/12, so
# download_datras() dies with "non-numeric argument to binary operator".
sf_h <- inner_join(
  hl_d |> group_by(.id = as.character(haul.id)) |>
    summarise(sf_fix = suppressWarnings(max(as.numeric(SubFactor), na.rm = TRUE)),
              .groups = "drop"),
  dr_con("HL") |>
    filter(Survey == "NS-IBTS", Year >= 2020L, Year <= 2023L,
           Quarter %in% c(1L, 3L), Valid_Aphia == APHIA) |>
    collect() |> filter(.id %in% common) |>
    group_by(.id) |>
    summarise(sf_obus = suppressWarnings(max(SubsamplingFactor, na.rm = TRUE)),
              .groups = "drop"),
  by = ".id") |>
  mutate(lost = is.finite(sf_fix) & is.finite(sf_obus) &
           sf_fix < 1.0001 & sf_obus > 1.0001)
lost_ids <- sf_h$.id[sf_h$lost]
## 10 on the bundled 2026-03-04 fixture; 0 on a freshly downloaded one, which
## is the point -- ICES's 2026-06-25 recalculation removed them.
ok("stale-snapshot hauls are absent, or few and wholly Scottish",
   all(grepl("^NS-IBTS:[0-9]+:[13]:GB-SCT:", lost_ids)),
   sprintf("%s of %s hauls%s", length(lost_ids), nrow(sf_h),
           if (length(lost_ids) == 0) " -- fixture is current" else ", all GB-SCT"))
ok("record counts are equal, so records were recoded, not dropped",
   nrow(hl_d) == nrow(dr_con("HL") |>
     filter(Survey == "NS-IBTS", Year >= 2020L, Year <= 2023L,
            Quarter %in% c(1L, 3L), Valid_Aphia == APHIA) |>
     collect() |> filter(.id %in% common)),
   sprintf("%s records each side", nrow(hl_d)))

hdr("7. raised count: DATRAS's Count vs obus's n_haul")
cnt <- full_join(
  hl_d |> filter(!is.na(LngtCm)) |>
    group_by(.id = as.character(haul.id), l = as.numeric(LngtCm)) |>
    summarise(datras = sum(Count, na.rm = TRUE), .groups = "drop"),
  len_o |> group_by(.id, l = length_cm) |>
    summarise(obus = sum(n_haul, na.rm = TRUE), .groups = "drop"),
  by = c(".id", "l"))
ok("every (haul, length) cell present on both sides",
   !anyNA(cnt$datras) && !anyNA(cnt$obus),
   sprintf("DATRAS-only %s | obus-only %s", sum(is.na(cnt$obus)),
           sum(is.na(cnt$datras))))
cnt <- cnt |> mutate(gap = abs(datras - obus), lost = .id %in% lost_ids)
ok("Count == n_haul exactly, off the stale-snapshot hauls",
   max(cnt$gap[!cnt$lost], na.rm = TRUE) < 1e-9,
   sprintf("max gap %.3g over %s cells", max(cnt$gap[!cnt$lost], na.rm = TRUE),
           sum(!cnt$lost)))
ok("every disagreeing cell is on a stale-snapshot haul",
   all(cnt$lost[cnt$gap > 1e-9]),
   sprintf("%s cells disagree, %s of them pre-raised",
           sum(cnt$gap > 1e-9), sum(cnt$gap > 1e-9 & cnt$lost)))
ok("even there the raised totals agree to under half a fish",
   max(cnt$gap[cnt$lost], na.rm = TRUE) < 0.5,
   sprintf("max gap %.3g -- the fraction the old submission's rounding lost",
           max(cnt$gap[cnt$lost], na.rm = TRUE)))

hdr("8. un-raised count: DATRAS's HLNoAtLngt vs obus's n_measured")
c_hauls <- hh_o$.id[hh_o$DataType == "C"]
meas <- inner_join(
  hl_d |> filter(!is.na(LngtCm)) |>
    group_by(.id = as.character(haul.id), l = as.numeric(LngtCm)) |>
    summarise(datras = sum(HLNoAtLngt, na.rm = TRUE), .groups = "drop"),
  # NOTE: all_na must NOT be computed in the same summarise() that rebinds
  # n_measured -- dplyr evaluates in order, so it would see the new scalar.
  # This is the exact trap dr_HL_length()'s source comments warn about; the
  # first draft of this script fell into it and reported 0 NAs.
  len_o |> group_by(.id, l = length_cm) |>
    summarise(all_na = all(is.na(n_measured)),
              s = sum(n_measured, na.rm = TRUE), .groups = "drop") |>
    mutate(obus = if_else(all_na, NA_real_, s)) |> select(.id, l, obus),
  by = c(".id", "l")) |>
  mutate(is_c = .id %in% c_hauls)
ok("n_measured is NA exactly on the DataType C rows",
   all(is.na(meas$obus) == meas$is_c),
   sprintf("NA %s | C cells %s", sum(is.na(meas$obus)), sum(meas$is_c)))
non_c <- meas |> filter(!is_c) |> mutate(lost = .id %in% lost_ids)
ok("HLNoAtLngt == n_measured off DataType C and the stale hauls",
   max(abs(non_c$datras - non_c$obus)[!non_c$lost], na.rm = TRUE) < 1e-9,
   sprintf("max gap %.3g over %s cells",
           max(abs(non_c$datras - non_c$obus)[!non_c$lost], na.rm = TRUE),
           sum(!non_c$lost)))
ok("on the stale hauls the fixture is larger, never smaller",
   all((non_c$datras - non_c$obus)[non_c$lost] >= -1e-9),
   sprintf("%s cells, fixture > obus on %s -- it reports raised numbers as measured",
           sum(non_c$lost),
           sum((non_c$datras - non_c$obus)[non_c$lost] > 1e-9)))
non_c <- non_c |> filter(!lost)
# n_haul / n_measured must reproduce the submitted SubFactor wherever one
# factor applies to the whole cell.
sf <- hl_d |> filter(!is.na(LngtCm)) |>
  group_by(.id = as.character(haul.id), l = as.numeric(LngtCm)) |>
  summarise(nsf = n_distinct(SubFactor), sf = first(SubFactor), .groups = "drop") |>
  filter(nsf == 1)
ratio <- non_c |> inner_join(sf, by = c(".id", "l")) |> filter(obus > 0) |>
  mutate(f = cnt$obus[match(paste(.id, l), paste(cnt$.id, cnt$l))] / obus)
ok("n_haul / n_measured == the submitted SubFactor",
   max(abs(ratio$f - ratio$sf), na.rm = TRUE) < 1e-9,
   sprintf("max gap %.3g over %s single-factor cells",
           max(abs(ratio$f - ratio$sf), na.rm = TRUE), nrow(ratio)))

hdr("9. the N matrix: addSpectrum() vs binning HL_length")
d2  <- add_numbers_at_length(dab)
N   <- d2[["HH"]][["N"]][common, , drop = FALSE]
brk <- attr(d2, "cm.breaks")
cmp_N <- full_join(
  as.data.frame(as.table(N)) |> setNames(c(".id", "bin", "datras")) |>
    mutate(.id = as.character(.id), bin = as.character(bin)) |>
    filter(datras != 0),
  len_o |> mutate(bin = as.character(cut(length_cm, breaks = brk, right = FALSE))) |>
    filter(!is.na(bin)) |> group_by(.id, bin) |>
    summarise(obus = sum(n_haul, na.rm = TRUE), .groups = "drop"),
  by = c(".id", "bin"))
ok("same set of non-zero (haul, bin) cells",
   !anyNA(cmp_N$datras) && !anyNA(cmp_N$obus),
   sprintf("DATRAS-only %s | obus-only %s", sum(is.na(cmp_N$obus)),
           sum(is.na(cmp_N$datras))))
# addSpectrum() applies round() to the whole matrix; obus does not round.
ok("cell values agree after addSpectrum()'s own round()",
   max(abs(cmp_N$datras - round(cmp_N$obus)), na.rm = TRUE) == 0,
   sprintf("max gap %s over %s cells",
           max(abs(cmp_N$datras - round(cmp_N$obus)), na.rm = TRUE), nrow(cmp_N)))
ok("N carries a row per haul; obus carries rows only where there is catch",
   nrow(N) == length(common) && n_distinct(cmp_N$.id) < length(common),
   sprintf("N rows %s | hauls with a dab row %s", nrow(N), n_distinct(cmp_N$.id)))

hdr("10. haul totals: HaulN vs summed n_haul (the zero-haul question)")
d3 <- add_total_numbers_by_haul(d2)
tot <- tibble(.id = as.character(d3[["HH"]]$haul.id),
              HaulN = as.numeric(d3[["HH"]]$HaulN)) |>
  filter(.id %in% common) |>
  # HaulN is rowSums of the ROUNDED matrix, so obus must be rounded per cell
  # before summing -- rounding the sum is not the same thing.
  left_join(cmp_N |> group_by(.id) |>
              summarise(obus = sum(round(obus)), .groups = "drop"), by = ".id")
ok("hauls with no obus row are exactly DATRAS's zero hauls",
   all(tot$HaulN[is.na(tot$obus)] == 0),
   sprintf("%s such hauls, all HaulN == 0", sum(is.na(tot$obus))))
matched <- tot |> filter(!is.na(obus))
ok("HaulN == sum of per-cell-rounded n_haul",
   max(abs(matched$HaulN - matched$obus)) == 0,
   sprintf("max gap %s over %s hauls", max(abs(matched$HaulN - matched$obus)),
           nrow(matched)))

hdr("11. HL_summary vs the naive DATRAS-style dedup (EXPECTED to differ)")
# obus's n_totalnumber disambiguates TotalNumber repeated across sub-rows;
# a dedup on ICES's documented 5-part key does not. Where they disagree,
# the raised length frequency is the independent third opinion -- so this
# does not just measure the gap, it says which side the data supports.
len_tot <- cnt |> group_by(.id) |> summarise(len = sum(obus), .groups = "drop")
tn <- inner_join(
  hl_d |> mutate(k = paste(haul.id, SpecCode, CatIdentifier, Sex, DevStage,
                           sep = "\r")) |>
    filter(!duplicated(k)) |>
    group_by(.id = as.character(haul.id)) |>
    summarise(datras = sum(as.numeric(TotalNo), na.rm = TRUE), .groups = "drop"),
  smry_o |> group_by(.id) |>
    summarise(obus = sum(n_totalnumber, na.rm = TRUE), .groups = "drop"),
  by = ".id") |>
  inner_join(len_tot, by = ".id")
diff <- tn |> filter(abs(datras - obus) > 0.5)
note("%s of %s hauls disagree. On those, distance from the length-derived",
     nrow(diff), nrow(tn))
note("total (an independently computed third figure):")
note("  naive dedup : median %.1f fish off, max %.0f",
     median(abs(diff$datras - diff$len)), max(abs(diff$datras - diff$len)))
note("  obus        : median %.1f fish off, max %.0f",
     median(abs(diff$obus - diff$len)), max(abs(diff$obus - diff$len)))
ok("obus's total is closer to the length-derived total than the naive dedup",
   median(abs(diff$obus - diff$len)) < median(abs(diff$datras - diff$len)),
   sprintf("obus closer on %s of %s disagreeing hauls",
           sum(abs(diff$obus - diff$len) < abs(diff$datras - diff$len)), nrow(diff)))
ok("the naive dedup's error is the documented repeated-total doubling",
   { r <- diff$datras / diff$obus; sum(abs(r - 2) < 0.01) > nrow(diff) / 2 },
   sprintf("%s of %s disagreements are an exact factor of 2",
           sum(abs(diff$datras / diff$obus - 2) < 0.01), nrow(diff)))

hdr(sprintf("RESULT: %d checks passed, %d showed a difference", PASS, FAIL))
