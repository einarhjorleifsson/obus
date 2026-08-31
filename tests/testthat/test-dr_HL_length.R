# Tests for dr_HL_length(): synthetic, offline, eager data frames only.
# Covers the LengthType plumbing (migrated from test-dr_HL_standardised.R,
# which tested this via dr_HL_standardised() + filter(type == "length")
# before the 2026-07 split) and the defining new behaviour: bulk-only
# species (no LengthClass at all) contribute no row here whatsoever.

.hl_length_fixture <- function(length_type = "4") {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(.id = 1L, aphia = 126417L, NumberAtLength = 5,
                   LengthClass = 100, LengthCode = "1", LengthType = length_type,
                   SubsamplingFactor = 1, sex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
                   TotalNumber = 5, SpeciesCategoryWeight = 500,
                   SpeciesCategory = "1")
  sp <- data.frame(aphia = 126417L, latin = "Test species",
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
    aphia = c(126417L, 999999L),                  # 999999 = bulk-only species
    NumberAtLength = c(5, NA),
    LengthClass = c(100, NA),                      # NA -> bulk-only, no length taken
    LengthCode = c("1", NA),
    LengthType = c("4", NA),
    SubsamplingFactor = c(1, NA),
    sex = c("F", NA),
    SpeciesValidity = c(1L, 1L), DevelopmentStage = NA_character_,
    TotalNumber = c(5, 12),                        # bulk species still has a recorded total
    SpeciesCategoryWeight = c(500, 3000),
    SpeciesCategory = c("1", "1")
  )
  sp <- data.frame(aphia = c(126417L, 999999L),
                   latin = c("Test species", "Bulk species"),
                   species = c("Test species", "Bulk species"),
                   rank = c("Species", "Species"))
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 1L)
  expect_equal(out$aphia, 126417L)
  expect_false(999999L %in% out$aphia)
})

test_that("sex is carried as its own column/row, not collapsed to p_females", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    NumberAtLength = c(3, 5, 2),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    sex = c("M", "F", "B"),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_false("p_females" %in% names(out))
  expect_equal(nrow(out), 3L)                 # one row per sex, same .id x aphia x length_mm
  expect_equal(sort(out$n_haul), c(2, 3, 5))
  expect_setequal(out$sex, c("M", "F", "B"))   # "B" kept distinct, not pre-merged into "F"
})

test_that("the old p_females ratio is exactly recoverable by aggregating over sex", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    NumberAtLength = c(3, 5, 2),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    sex = c("M", "F", "B"),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  n_f <- sum(out$n_haul[out$sex %in% c("F", "B")])
  n_m <- sum(out$n_haul[out$sex == "M"])
  expect_equal(n_f / (n_f + n_m), (5 + 2) / (3 + 5 + 2))
})

test_that("sex == 'U' (assessed, undetermined) stays distinct from sex is NA (never assessed)", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L,
    NumberAtLength = c(4, 6),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1,
    sex = c("U", NA_character_),
    SpeciesValidity = 1L, DevelopmentStage = NA_character_, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "Test species",
                   species = "Test species", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 2L)
  expect_equal(out$n_haul[!is.na(out$sex) & out$sex == "U"], 4)
  expect_equal(out$n_haul[is.na(out$sex)], 6)
})
# --- DevelopmentStage is part of the record key -----------------------------
# ICES's own field description defines TotalNumber and SpeciesCategoryWeight as
# totals "per category (unique combination of cruise haul, species, sex,
# devstage and subsampling category identifier)". Two rows differing only in
# DevelopmentStage are therefore separate observational units and must not be
# summed together -- a berried female and an unstaged one at the same length
# are not the same record.

test_that("DevelopmentStage splits the grain rather than being summed away", {
  hh <- data.frame(.id = 1L, Survey = "BTS", Year = 2024L, Quarter = 3L,
                   DataType = "R", HaulDuration = 60, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 141444L,
    NumberAtLength = c(4, 6),
    LengthClass = 100, LengthCode = "1", LengthType = "1",
    SubsamplingFactor = 1, sex = NA_character_,
    DevelopmentStage = c("E", NA_character_),
    SpeciesValidity = 1L, TotalNumber = 10, SpeciesCategoryWeight = 100,
    SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 141444L, latin = "Sepia officinalis",
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
    .id = 1L, aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = NA_real_,
    sex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 7, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(nrow(out), 1L)
  expect_true(is.na(out$n_haul))     # NOT 7
  expect_true(is.na(out$n_hour))
})

test_that("a present SubsamplingFactor of 1 still means 'not subsampled' and raises normally", {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L, aphia = 126417L, NumberAtLength = 7, LengthClass = 100,
    LengthCode = "1", LengthType = "1", SubsamplingFactor = 1,
    sex = "F", SpeciesValidity = 1L, DevelopmentStage = NA_character_,
    TotalNumber = 7, SpeciesCategoryWeight = 700, SpeciesCategory = "1"
  )
  sp <- data.frame(aphia = 126417L, latin = "T", species = "T", rank = "Species")
  out <- dr_HL_length(hh, hl, species = sp)

  expect_equal(out$n_haul, 7)
  expect_equal(out$n_hour, 14)
})
