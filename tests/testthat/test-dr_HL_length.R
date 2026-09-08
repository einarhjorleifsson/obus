# Tests for dr_HL_length(): synthetic, offline, eager data frames only.
# Covers the LengthType plumbing (migrated from test-dr_HL_standardised.R,
# which tested this via dr_HL_standardised() + filter(type == "length")
# before the 2026-07 split) and the defining new behaviour: bulk-only
# species (no LengthClass at all) contribute no row here whatsoever.

.hl_length_fixture <- function(length_type = "4") {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(.id = 1L, Valid_Aphia = 126417L, NumberAtLength = 5,
                   LengthClass = 100, LengthCode = "1", LengthType = length_type,
                   SubsamplingFactor = 1, SpeciesSex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
                   TotalNumber = 5, SpeciesCategoryWeight = 500,
                   SpeciesCategory = "1")
  sp <- data.frame(Valid_Aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  list(hh = hh, hl = hl, species = sp)
}

test_that("LengthType is carried through", {
  f <- .hl_length_fixture(length_type = "4")
  out <- dr_HL_length(f$hh, f$hl, species = f$species)

  expect_true("LengthType" %in% names(out))
  expect_equal(out$LengthType, "4")
})

test_that("a missing LengthType (NA in the raw HL) survives as NA, not an error", {
  f <- .hl_length_fixture(length_type = NA_character_)
  out <- dr_HL_length(f$hh, f$hl, species = f$species)

  expect_true(is.na(out$LengthType))
})

test_that("no type/w_haul/w_hour columns -- those belong to dr_HL_summary() now", {
  f <- .hl_length_fixture()
  out <- dr_HL_length(f$hh, f$hl, species = f$species)

  expect_false(any(c("type", "w_haul", "w_hour") %in% names(out)))
})

# --- the defining new behaviour: bulk-only species are absent, not zero-filled ---

test_that("a species with no LengthClass at all (bulk-only) contributes no row here", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = c(1L, 1L),
    Valid_Aphia = c(126417L, 999999L),                  # 999999 = bulk-only species
    NumberAtLength = c(5, NA),
    LengthClass = c(100, NA),                      # NA -> bulk-only, no length taken
    LengthCode = c("1", NA),
    LengthType = c("4", NA),
    SubsamplingFactor = c(1, NA),
    SpeciesSex = c("F", NA),
    SpeciesValidity = c(1L, 1L), DevelopmentStage = NA_character_,
    TotalNumber = c(5, 12),                        # bulk species still has a recorded total
    SpeciesCategoryWeight = c(500, 3000),
    SpeciesCategory = c("1", "1")
  )
  sp <- data.frame(Valid_Aphia = c(126417L, 999999L),
                   latin = c("Test species", "Bulk species"),
                   species = c("Test species", "Bulk species"),
                   rank = c("Species", "Species"))
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 1L)
  expect_equal(out$Valid_Aphia, 126417L)
  expect_false(999999L %in% out$Valid_Aphia)
})

test_that("SpeciesSex is carried as its own column/row, not collapsed to p_females", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L,
    NumberAtLength = c(3, 5, 2),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    SpeciesSex = c("M", "F", "B"),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_false("p_females" %in% names(out))
  expect_equal(nrow(out), 3L)                 # one row per SpeciesSex, same .id x Valid_Aphia x length_mm
  expect_equal(sort(out$n_haul), c(2, 3, 5))
  expect_setequal(out$SpeciesSex, c("M", "F", "B"))   # "B" kept distinct, not pre-merged into "F"
})

test_that("the old p_females ratio is exactly recoverable by aggregating over SpeciesSex", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L,
    NumberAtLength = c(3, 5, 2),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    SpeciesSex = c("M", "F", "B"),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  n_f <- sum(out$n_haul[out$SpeciesSex %in% c("F", "B")])
  n_m <- sum(out$n_haul[out$SpeciesSex == "M"])
  expect_equal(n_f / (n_f + n_m), (5 + 2) / (3 + 5 + 2))
})

test_that("SpeciesSex == 'U' (assessed, undetermined) stays distinct from SpeciesSex is NA (never assessed)", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L,
    NumberAtLength = c(4, 6),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    SpeciesSex = c("U", NA_character_),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 2L)
  expect_equal(out$n_haul[!is.na(out$SpeciesSex) & out$SpeciesSex == "U"], 4)
  expect_equal(out$n_haul[is.na(out$SpeciesSex)], 6)
})
# --- DevelopmentStage is part of the record key -----------------------------
# ICES's own field description defines TotalNumber and SpeciesCategoryWeight as
# totals "per category (unique combination of cruise haul, species, SpeciesSex,
# devstage and subsampling category identifier)". Two rows differing only in
# DevelopmentStage are therefore separate observational units and must not be
# summed together -- a berried female and an unstaged one at the same length
# are not the same record.

test_that("DevelopmentStage splits the grain rather than being summed away", {
  hh <- data.frame(.id = 1L, Survey = "BTS", Year = 2024L, Quarter = 3L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 141444L,
    NumberAtLength = c(4, 6),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1, SpeciesSex = NA_character_,
    DevelopmentStage = c("E", NA_character_),
    SpeciesValidity = 1L, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 141444L, latin = "Sepia officinalis",
                   species = "common cuttlefish", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 2L)                       # NOT collapsed to one row of 10
  expect_true("DevelopmentStage" %in% names(out))
  expect_setequal(out$n_haul, c(4, 6))
})

# --- a missing SubsamplingFactor is "no information", not 1 -----------------
# ICES makes SubsamplingFactor mandatory, defines 1 as the specific claim
# "not subsampled", and tells submitters that a field with no information is
# submitted as -9 (which opus nulls as a numeric sentinel). So NA means no
# information was supplied. The DATRAS R package treats DataType "R" + NA as
# 1; obus deliberately does not, because that asserts a fact the submission
# does not contain.

test_that("DataType 'R' with a missing SubsamplingFactor gives NA, not a coalesce to 1", {
  hh <- data.frame(.id = 1L, Survey = "Can-Mar", Year = 1995L, Quarter = 3L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = NA_real_,
    SpeciesSex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 7, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 1L)
  expect_true(is.na(out$n_haul))     # NOT 7
  expect_true(is.na(out$n_hour))
})

test_that("a present SubsamplingFactor of 1 still means 'not subsampled' and raises normally", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    SpeciesSex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 7, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(out$n_haul, 7)
  expect_equal(out$n_hour, 14)
})

# --- n_measured: the un-raised NumberAtLength, as submitted ------------------
# Added 2026-09-03. The raised n_haul was the only count here, which made the
# submitted length frequency unrecoverable from the published table -- the one
# HL field a QC consumer (DATRAS/DATRASextra's `Count` vs HLNoAtLngt) could
# want and not find. n_measured is dr_HL_summary()'s column of the same name at
# this finer grain, so the two tables stay one vocabulary.

test_that("n_measured is the un-raised NumberAtLength, and n_haul the raised one", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 4,
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 28, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(out$n_measured, 7)     # what went through the calipers
  expect_equal(out$n_haul, 28)        # raised to the whole haul
})

test_that("n_measured is NOT recoverable from n_haul when one row aggregates two raising factors", {
  # SubsamplingFactor is not part of this table's grain, so two raw HL rows
  # differing only in SpeciesCategory collapse into one output row. With
  # different factors on them, no single divisor gets back to the submitted
  # count -- 42,089 archive rows are in exactly this position.
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L,
    NumberAtLength = c(4, 6),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = c(1, 3),
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 22, SpeciesCategoryWeight = 500,
    SpeciesCategory = c("1", "2")
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 1L)
  expect_equal(out$n_measured, 10)               # 4 + 6, as submitted
  expect_equal(out$n_haul, 22)                   # 4*1 + 6*3
  # %in% binds tighter than /, so the ratio needs its own parentheses.
  expect_false((out$n_haul / out$n_measured) %in% hl$SubsamplingFactor)
})

test_that("n_measured is NA under DataType 'C', which reports a rate rather than a count", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "C", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 8, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 8, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_true(is.na(out$n_measured))   # NOT 8, and NOT 0
  expect_equal(out$n_hour, 8)          # the reported rate still survives
  expect_equal(out$n_haul, 4)          # 8 per hour over a 30-minute haul
})

# REGRESSION GUARD. Under DataType "C" obus applies BOTH multipliers --
# HaulDur/60 AND SubFactor -- and this deliberately contradicts ICES's own
# published recipe, so it looks like a bug to anyone reading WKABSENS. It has
# already been "fixed" to one multiplier once and reverted. Do not do it again.
#
# WKABSENS 2021 (3.3, step 17): "Multiplier = HaulDur/60 if DataType in ('C');
# Multiplier = SubFactor if DataType in ('S','R')". The DATRAS R package did
# exactly that until commit 880b553 (2023-04-11), which switched to two
# multipliers over the note "some BITS hauls (all LT and some DK) have dataType
# C but SubFactor>1 - two multipliers needed!". WKABSENS predates the discovery.
#
# The submissions settle it: over the 113 groups with "C" and SubFactor > 1,
# TotalNo never equals sum(HLNoAtLngt) but equals sum x SubFactor in 102, and
# sum(HLNoAtLngt) equals NoMeas in 108 -- so HLNoAtLngt there is the measured
# subsample, and the haul is shaped like "R" while labelled "C".
test_that("DataType 'C' with SubFactor > 1 applies both multipliers", {
  # Modelled on BITS DK 2018: 30-minute haul, SubFactor 167.939, NoMeas 120,
  # sum(HLNoAtLngt) 120, TotalNo 20152.68 = 120 * 167.939.
  hh <- data.frame(.id = 1L, Survey = "BITS", Year = 2018L, Quarter = 4L,
                   DataType = "C", HaulDuration = 30, HaulValidity = "N")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126425L, NumberAtLength = 120, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 167.939,
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 20152.68, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126425L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  # 120 * 167.939 * 30/60 -- NOT 60 (duration only) and NOT 20152.68 (factor only)
  expect_equal(out$n_haul, 120 * 167.939 * 0.5)
  expect_equal(out$n_hour, 120 * 167.939)
  expect_equal(out$n_hour, out$n_haul / 30 * 60)   # the two must stay consistent
})

test_that("DataType 'C' with a missing SubFactor gives NA, unlike the DATRAS package", {
  # DATRAS coalesces a missing SubFactor to 1 (multiplier2 in read_datras.R);
  # obus propagates the NA, under the same rule it applies to "R" -- "not
  # recorded" is not the claim "not subsampled". In the archive every "C" row
  # with no factor is a bulk record with no length data, so this guards the
  # rule rather than a case that currently occurs.
  hh <- data.frame(.id = 1L, Survey = "BITS", Year = 2012L, Quarter = 1L,
                   DataType = "C", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 8, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = NA_real_,
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 8, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_true(is.na(out$n_haul))
  expect_true(is.na(out$n_measured))
})

test_that("a missing SubsamplingFactor voids n_haul but leaves n_measured intact", {
  # The submitted count is a fact regardless of whether the raising factor
  # was supplied; only the raised figure becomes unknowable.
  hh <- data.frame(.id = 1L, Survey = "Can-Mar", Year = 1995L, Quarter = 3L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = NA_real_,
    SpeciesSex = "F", SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = 7, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_true(is.na(out$n_haul))
  expect_equal(out$n_measured, 7)
})

test_that("summing n_measured to dr_HL_summary()'s grain reproduces its n_measured", {
  # The invariant that lets the two tables carry one name for one quantity.
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, Valid_Aphia = 126417L,
    NumberAtLength = c(3, 5, 2),
    LengthClass = c(100, 100, 110), LengthCode = "1", LengthType = "1",
    SubsamplingFactor = c(1, 2, 1),
    SpeciesSex = c("F", "M", "M"),
    SpeciesValidity = "1", DevelopmentStage = NA_character_,
    TotalNumber = c(3, 10, 2), SpeciesCategoryWeight = 500,
    SpeciesCategory = "1"
  )
  sp <- data.frame(Valid_Aphia = 126417L, latin = "T", species = "T", rank = "Species")

  len  <- dr_HL_length(hh, hl, species = sp)
  smry <- dr_HL_summary(hh, hl, species = sp)

  rolled <- stats::aggregate(n_measured ~ .id + Valid_Aphia + SpeciesValidity,
                             data = len, FUN = sum, na.rm = TRUE)
  expect_equal(rolled$n_measured, smry$n_measured)
  expect_equal(smry$n_measured, 10)               # 3 + 5 + 2, un-raised
})
