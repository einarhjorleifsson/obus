# Tests for dr_HL_summary(): synthetic, offline, eager data frames only.
# Covers the sex-split SpeciesCategoryWeight deduplication fix (migrated
# from test-dr_HL_standardised.R, which tested this via
# dr_HL_standardised() + filter(type == "haul") before the 2026-07 split)
# and the new n_measured field's three-way semantics (0 / NA / real count).

# --- sex-split SpeciesCategoryWeight deduplication (real bug, fixed 2026-07-08) ---
# TotalNumber legitimately varies by sex and must be summed across sex rows to
# get the true haul total; SpeciesCategoryWeight is a single per-category total
# that DATRAS repeats identically on every sex-split row for that category, so
# it must be deduplicated (not summed once per sex row) before being added up.
# Modelled directly on a real NS-IBTS haul (NS-IBTS:2019:1:NO:58G2:GOV:60003:3)
# where this inflated w_haul by exactly 3x.

.hl_summary_fixture <- function(rows) {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- do.call(rbind, lapply(rows, function(r) data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = r$TotalNumber,
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1, sex = r$sex, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = r$TotalNumber, SpeciesCategoryWeight = r$SpeciesCategoryWeight,
    SpeciesCategory = r$SpeciesCategory, stringsAsFactors = FALSE
  )))
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  list(hh = hh, hl = hl, species = sp)
}

test_that("a weight repeated identically across sex-split rows is counted once, not per sex", {
  f <- .hl_summary_fixture(list(
    list(sex = "M",  TotalNumber = 8,  SpeciesCategoryWeight = 33160, SpeciesCategory = 1),
    list(sex = "F",  TotalNumber = 14, SpeciesCategoryWeight = 33160, SpeciesCategory = 1),
    list(sex = NA,   TotalNumber = 3,  SpeciesCategoryWeight = 33160, SpeciesCategory = 1)
  ))
  out <- dr_HL_summary(f$hh, f$hl, species = f$species)

  expect_equal(out$w_haul, 33160)          # NOT 33160 * 3 = 99480
  expect_equal(out$n_totalnumber, 8 + 14 + 3)     # counts still sum correctly across sex
})

test_that("genuinely distinct per-sex weights are still summed, not deduplicated away", {
  f <- .hl_summary_fixture(list(
    list(sex = "M", TotalNumber = 23, SpeciesCategoryWeight = 4000, SpeciesCategory = 1),
    list(sex = "F", TotalNumber = 4,  SpeciesCategoryWeight = 900,  SpeciesCategory = 1)
  ))
  out <- dr_HL_summary(f$hh, f$hl, species = f$species)

  expect_equal(out$w_haul, 4000 + 900)
  expect_equal(out$n_totalnumber, 23 + 4)
})

test_that("two SpeciesCategory codes, each internally sex-duplicated, sum to the true total", {
  f <- .hl_summary_fixture(list(
    list(sex = "M", TotalNumber = 8,  SpeciesCategoryWeight = 33160, SpeciesCategory = 1),
    list(sex = "F", TotalNumber = 14, SpeciesCategoryWeight = 33160, SpeciesCategory = 1),
    list(sex = NA,  TotalNumber = 3,  SpeciesCategoryWeight = 33160, SpeciesCategory = 1),
    list(sex = "M", TotalNumber = 3,  SpeciesCategoryWeight = 850,   SpeciesCategory = 2),
    list(sex = "F", TotalNumber = 2,  SpeciesCategoryWeight = 850,   SpeciesCategory = 2),
    list(sex = NA,  TotalNumber = 14, SpeciesCategoryWeight = 850,   SpeciesCategory = 2)
  ))
  out <- dr_HL_summary(f$hh, f$hl, species = f$species)

  expect_equal(out$w_haul, 33160 + 850)    # NOT (33160 + 850) * 3 = 102030
  expect_equal(out$n_totalnumber, (8 + 14 + 3) + (3 + 2 + 14))
})

test_that("a single sex row (the common, no-risk case) is unaffected", {
  f <- .hl_summary_fixture(list(
    list(sex = "F", TotalNumber = 10, SpeciesCategoryWeight = 5000, SpeciesCategory = 1)
  ))
  out <- dr_HL_summary(f$hh, f$hl, species = f$species)

  expect_equal(out$w_haul, 5000)
  expect_equal(out$n_totalnumber, 10)
})

# --- TotalNumber duplicated identically across sex (the analogous count bug, ---
# --- found 2026-07-26 and fixed here; confirmed live on a real Can-Mar haul, ---
# --- witch flounder (Can-Mar:1970:3:CA:18AT:Y36:11:80): TotalNumber == 2 on ---
# --- both an F row and an M row, true total 2, this code previously summed ---
# --- to 4. Same mechanism as the already-known weight bug, just not caught ---
# --- for counts until now because TotalNumber genuinely IS per-sex often ---
# --- enough (66% of multi-sex groups, archive-wide) that no existing test ---
# --- exercised the duplicate case. ---

test_that("TotalNumber duplicated identically across sex is counted once, not per sex", {
  # NOT built on .hl_summary_fixture(): that helper sets NumberAtLength ==
  # TotalNumber for convenience, which would make this specific case
  # self-consistent per sex (each sex's own data would genuinely reconcile
  # with its own TotalNumber, at which point summing them IS the correct
  # accounting answer, not a bug). A genuine placeholder duplicate needs
  # NumberAtLength that does NOT reconcile with the (larger, duplicated)
  # TotalNumber for either sex -- modelled directly on the real Can-Mar
  # example (witch flounder, Can-Mar:1970:3:CA:18AT:Y36:11:80): 1 F
  # individual, 1 M individual, TotalNumber == 2 (the true combined total)
  # repeated on both rows.
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    NumberAtLength = c(1, 1), LengthClass = c(100, 110),
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    sex = c("F", "M"), SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = c(2, 2), SpeciesCategoryWeight = c(1550, 1550),
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 2)     # NOT 1+1 summed against a duplicated total = 4
  expect_equal(out$n_totalnumber_hour, 4)     # HaulDuration = 30 -> n_hour = n_haul/30*60
})

test_that("two different sexes coincidentally reporting the SAME real value are both trusted and summed", {
  # The blind spot the first fix (distinct()-on-value-alone) had: unlike the
  # placeholder case above, here EACH sex's own NumberAtLength genuinely
  # reconciles with its own TotalNumber -- they just happen to be equal by
  # coincidence, not duplication. Modelled on a real BITS haul
  # (BITS:1999:1:DK:26HI:TVS:017492:22, aphia 127143): F's own total is 2
  # (two length rows, both correctly repeating TotalNumber=2), M's own total
  # is 1, an unsexed row's own total is ALSO 1 -- three genuinely separate
  # values, two of which coincide. True total 2+1+1=4.
  hh <- data.frame(.id = 1L, Survey = "BITS", Year = 1999L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 127143L,
    NumberAtLength = c(1, 1, 1, 1),
    LengthClass = c(12, 25, 20, 11),
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    sex = c("F", "F", "M", NA_character_), SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = c(2, 2, 1, 1), SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 127143L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 4)     # NOT distinct(2,1) = 3 -- M and unsexed are genuinely separate
})

# --- TotalNumber duplicated across SpeciesCategory (found + fixed 2026-07-26) ---
# The same placeholder-duplication mechanism as sex above, one dimension over:
# some surveys report the SAME haul-species total on two different
# SpeciesCategory rows (size strata) instead of two independent per-category
# totals. Modelled directly on a real NS-IBTS haul
# (NS-IBTS:2025:3:GB-SCT:748S:JTFS:259:259, aphia 126438): category "12"
# (3 large individuals, SubsamplingFactor == 1) and category "11" (the bulk
# of the catch, SubsamplingFactor == 1.825), both rows carrying
# TotalNumber == 660 -- the combined species total, not either stratum's own.

test_that("TotalNumber duplicated across SpeciesCategory is counted once, not per category", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2025L, Quarter = 3L,
                   DataType = "P", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126438L,
    NumberAtLength = c(1, 1, 1, 17, 70, 71, 47, 24, 15, 24, 25, 27, 17, 11, 11, 1),
    LengthClass = c(330, 340, 350, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320),
    LengthCode = "1", LengthType = "1",
    SubsamplingFactor = c(1, 1, 1, rep(1.825, 13)),
    sex = NA_character_, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 660,
    SpeciesCategoryWeight = 5000,
    SpeciesCategory = c(rep("12", 3), rep("11", 13))
  )
  sp <- data.frame(aphia = 126438L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 660)   # NOT 660 + 660 = 1320 (once per category)
})

test_that("genuinely distinct SpeciesCategory totals are still summed, not collapsed", {
  # Guards the fix above against over-collapsing: two categories that each
  # reconcile with their OWN length data (not a shared placeholder) must
  # still be added together, exactly like the existing multi-category
  # weight test above.
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    NumberAtLength = c(4, 2),
    LengthClass = c(100, 110),
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    sex = NA_character_, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = c(4, 2), SpeciesCategoryWeight = c(500, 300),
    SpeciesCategory = c("1", "2")
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 4 + 2)   # NOT collapsed to distinct-value 4 (they differ anyway)
})

test_that("p_females is sourced from NumberAtLength, not the (possibly duplicated) TotalNumber", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    # TotalNumber is a duplicated placeholder (same value on both sex rows) --
    # if p_females were still derived from it, F and M would look equal (0.5)
    # regardless of the true split. NumberAtLength carries the true, uneven one.
    NumberAtLength = c(2, 6),
    LengthClass = c(100, 110), LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    sex = c("F", "M"),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = c(10, 10), SpeciesCategoryWeight = c(500, 500),
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 10)                 # counts correctly deduplicated (not 10+10=20)
  expect_equal(out$p_females, 2 / (2 + 6))      # NOT 10/(10+10) = 0.5
})

# --- n_measured: three-way semantics (0 / NA / real count) ------------------
# 0    = species genuinely never individually measured (no LengthClass rows)
# NA   = DataType == "C" -- NumberAtLength is an hourly rate, not a per-haul
#        count, so no true physical count is recoverable
# real = DataType %in% c("R","S","P") -- raw, un-raised individuals measured

test_that("n_measured is 0 for a bulk-only species (no LengthClass at all)", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 999999L, NumberAtLength = NA_real_,
    LengthClass = NA_real_, LengthCode = NA_character_, LengthType = NA_character_,
    SubsamplingFactor = NA_real_, sex = NA_character_, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 12, SpeciesCategoryWeight = 3000, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 999999L, latin = "Bulk species",
                   species = "Bulk species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber, 12)              # a real, non-zero catch
  expect_equal(out$n_measured, 0)           # but zero individuals measured
})

test_that("n_measured is NA (not a misleading rate) when DataType == 'C'", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "C", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = 4,
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1, sex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 4, SpeciesCategoryWeight = 400, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_true(is.na(out$n_measured))
  expect_false(is.na(out$n_totalnumber))           # n_haul itself is still resolved
})

test_that("n_measured is the raw un-raised count for DataType == 'R'/'S'/'P'", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "S", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = c(3, 5),
    LengthClass = c(100, 110), LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 2, sex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 16, SpeciesCategoryWeight = 800, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_measured, 3 + 5)        # raw, un-raised by SubsamplingFactor
  expect_equal(out$n_totalnumber, 16)               # the recorded (raised) total, unaffected
})

test_that("dr_HL_summary() covers every species, unlike dr_HL_length()", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = c(1L, 1L),
    aphia = c(126417L, 999999L),
    NumberAtLength = c(5, NA),
    LengthClass = c(100, NA),
    LengthCode = c("1", NA), LengthType = c("1", NA),
    SubsamplingFactor = c(1, NA), sex = c("F", NA),
    SpeciesValidity = c(1L, 1L), DevelopmentStage = NA_character_,
    TotalNumber = c(5, 12), SpeciesCategoryWeight = c(500, 3000),
    SpeciesCategory = c("1", "1")
  )
  sp <- data.frame(aphia = c(126417L, 999999L),
                   latin = c("Test species", "Bulk species"),
                   species = c("Test species", "Bulk species"),
                   rank = c("Species", "Species"))
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(nrow(out), 2L)
  expect_true(all(c(126417L, 999999L) %in% out$aphia))
})

# --- HaulDuration <= 0: undefined, not Inf and not a false zero -------------
# A rate per hour cannot be derived from a haul with no (or negative) duration.
# Left alone the arithmetic hides this: the derived hourly figure comes out
# Inf, while a DataType "C" per-haul figure -- which multiplies BY the duration
# rather than dividing by it -- comes out a plausible-looking 0. Archive-wide:
# 217 hauls at duration 0 (200 of them "C"), plus 2 negative.

test_that("HaulDuration == 0 gives NA hourly figures, not Inf", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2018L, Quarter = 1L,
                   DataType = "R", HaulDuration = 0, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = 5, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1, sex = "F",
    SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 5, SpeciesCategoryWeight = 500, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_true(is.na(out$n_totalnumber_hour))
  expect_true(is.na(out$w_hour))
  expect_equal(out$n_totalnumber, 5)      # the per-haul total is still known
  expect_equal(out$w_haul, 500)
})

test_that("HaulDuration < 0 gives NA hourly figures too", {
  hh <- data.frame(.id = 1L, Survey = "Can-Mar", Year = 2017L, Quarter = 3L,
                   DataType = "R", HaulDuration = -514, HaulValidity = "I")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = 5, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1, sex = "F",
    SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 5, SpeciesCategoryWeight = 500, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_true(is.na(out$n_totalnumber_hour))
  expect_true(is.na(out$w_hour))
})

test_that("DataType 'C' with HaulDuration == 0 keeps the reported rate, NAs the haul total", {
  # "C" reports an hourly rate directly, so the rate survives; it is the
  # per-haul figure -- rate x duration -- that becomes undefined, and it must
  # not come back as 0.
  hh <- data.frame(.id = 1L, Survey = "BITS", Year = 2020L, Quarter = 1L,
                   DataType = "C", HaulDuration = 0, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = 4, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1, sex = "F",
    SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 8, SpeciesCategoryWeight = 800, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$n_totalnumber_hour, 8)   # reported rate, kept
  expect_equal(out$w_hour, 800)
  expect_true(is.na(out$n_totalnumber))     # NOT 0
  expect_true(is.na(out$w_haul))
})

# --- DataType P: the main category, not the pseudocategory, keys the weight ---
# Modelled on ICES's own worked haddock example (D2.2 Field Dependency, Annex 1
# Example 3.3): category 1 weighs 0.991 kg; category 2 weighs 290.1 kg and is
# split into pseudocategories 21 (factor 290.1/122.1988 = 2.374) and 22
# (factor 1). The factor IS category weight / sample weight, so 290.1 kg
# appears on BOTH pseudocategory rows. True catch weight is 991 + 290100 g.

test_that("a weight repeated across pseudocategories is counted once per main category", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 4L,
                   DataType = "P", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126437L,
    NumberAtLength = c(4, 9, 16, 6,  1, 7, 20,  31, 31, 27),
    LengthClass    = c(15, 16, 17, 18,  22, 23, 24,  33, 34, 35),
    LengthCode = "1", LengthType = "1",
    SubsamplingFactor = c(rep(1, 4), rep(2.374, 3), rep(1, 3)),
    sex = NA_character_, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = c(rep(35, 4), rep(916.364, 3), rep(249, 3)),
    SpeciesCategoryWeight = c(rep(991, 4), rep(290100, 3), rep(290100, 3)),
    SpeciesCategory = c(rep("11", 4), rep("21", 3), rep("22", 3))
  )
  sp <- data.frame(aphia = 126437L, latin = "Melanogrammus aeglefinus",
                   species = "haddock", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$w_haul, 991 + 290100)   # NOT 991 + 290100 + 290100
})

test_that("under DataType R, genuinely distinct per-category weights are still summed", {
  # The control case: CatIdentifier is a true partition under "R", so two
  # categories with their own weights must be added, not collapsed.
  hh <- data.frame(.id = 1L, Survey = "BTS", Year = 2020L, Quarter = 3L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 127139L,
    NumberAtLength = c(16, 105), LengthClass = c(100, 200),
    LengthCode = "1", LengthType = "1",
    SubsamplingFactor = c(1, 20.2776),
    sex = NA_character_, SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = c(16, 2129.1),
    SpeciesCategoryWeight = c(1950, 572030),
    SpeciesCategory = c("1", "2")
  )
  sp <- data.frame(aphia = 127139L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_summary(hh, hl, species = sp)

  expect_equal(out$w_haul, 1950 + 572030)
})
