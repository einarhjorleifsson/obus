# The published column contract.
#
# WHAT THIS IS FOR, honestly scoped. It is a regression guard against
# ACCIDENTAL change: a rename or reordering slipped in during refactoring, a
# column dropped from a select(), a dr_con() table name changed. Nothing else
# in the package would notice any of those.
#
# WHAT IT IS NOT. It is not the main defence against consumer drift, and the
# example that would suggest otherwise does not survive checking. The
# HL_summary n_haul -> n_totalnumber rename broke nothing: `n_haul` in
# HL_length is a DIFFERENT QUANTITY (NumberAtLength x SubsamplingFactor, the
# raised length frequency) from HL_summary's reported TotalNo, and every
# `n_haul` reference in imbus and datrasdoodle2 was to the length-derived one,
# which is unchanged. Giving two different quantities two different names was
# a fix, not a hazard -- they agree only when a submission is internally
# consistent, and 3.85% of haul x species groups show they often do not.
#
# The drift that actually happened to the consumers was REMOVED FUNCTIONS --
# dr_HL_standardised() x30 in datrasdoodle2, dr_get() x15 in imbus, the whole
# dr_check_* family. Those fail loudly the moment anything runs them. Nobody
# noticed only because nothing re-executes obus: measured across imbus,
# 0 obus calls inside executable chunks and 53 in prose. The real fix for that
# is a scheduled render of the consumers, not a test in this package.
#
# So: worth having, cheap, catches a real class of accident. Not a substitute
# for something actually running the consumers.
#
# The ONLINE test at the bottom is the more valuable half. It compares the
# PUBLISHED files against this list, and catches a failure that did occur here:
# a server parquet sitting two fixes behind its own source, which no test of
# the code can reveal.
#
# IF A TEST BELOW FAILS AND YOU MEANT IT: update the vector, then update the
# consumers. As of 2026-09-01 those are imbus (deliverables/, DATRAS/) and
# datrasdoodle2 (21 chapters), neither of which re-executes obus, so neither
# will notice on its own.

PUBLISHED_SCHEMA <- list(
  HL_summary = c(
    ".id", "Survey", "Year", "Quarter", "aphia", "latin", "species", "rank",
    "n_totalnumber", "n_totalnumber_hour", "n_haul", "w_haul", "w_hour",
    "n_measured", "p_females", "SpeciesValidity"
  ),
  HL_length = c(
    ".id", "Survey", "Year", "Quarter", "aphia", "latin", "species", "rank",
    "length_mm", "length_cm", "accuracy", "LengthType", "sex",
    "DevelopmentStage", "n_haul", "n_hour", "SpeciesValidity"
  ),
  hl_flag      = c(".id", "aphia", "code"),
  hl_flag_code = c("code", "kind", "affects", "label", "meaning", "evidence"),
  species      = c("aphia", "latin", "species", "rank", "kingdom", "phylum",
                   "class", "order", "family", "genus", "status",
                   "valid_aphia", "valid_name")
)

# The tables dr_con() serves. Adding one is fine; removing or renaming one
# breaks every caller that names it.
PUBLISHED_TABLES <- c("HH", "species", "HL_length", "HL_summary",
                      "hl_flag", "hl_flag_code")

# --- offline: the functions define the contract -----------------------------
# A minimal haul carrying every branch the two functions key on: two sexes, a
# development stage, two species categories, and a bulk-only species with no
# length data.
.schema_fixture <- function() {
  hh <- data.frame(.id = 1L, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
                   DataType = "R", HaulDuration = 30, HaulValidity = "V")
  hl <- data.frame(
    .id = 1L,
    aphia = c(126417L, 126417L, 126417L, 999999L),
    NumberAtLength = c(3, 5, 2, NA),
    LengthClass = c(100, 100, 110, NA),
    LengthCode = c("1", "1", "1", NA),
    LengthType = c("1", "1", "1", NA),
    SubsamplingFactor = c(1, 1, 1, NA),
    sex = c("F", "M", NA, NA),
    DevelopmentStage = c(NA, NA, "B", NA),
    SpeciesValidity = 1L,
    TotalNumber = c(3, 5, 2, 12),
    SpeciesCategoryWeight = c(500, 500, 300, 900),
    SpeciesCategory = c("1", "1", "2", "1"),
    stringsAsFactors = FALSE
  )
  sp <- data.frame(aphia = c(126417L, 999999L),
                   latin = c("Test species", "Bulk species"),
                   species = c("Test species", "Bulk species"),
                   rank = c("Species", "Species"))
  list(hh = hh, hl = hl, species = sp)
}

test_that("dr_HL_summary() returns exactly the published columns, in order", {
  f <- .schema_fixture()
  out <- dr_HL_summary(f$hh, f$hl, species = f$species)
  expect_identical(names(out), PUBLISHED_SCHEMA$HL_summary)
})

test_that("dr_HL_length() returns exactly the published columns, in order", {
  f <- .schema_fixture()
  out <- dr_HL_length(f$hh, f$hl, species = f$species)
  expect_identical(names(out), PUBLISHED_SCHEMA$HL_length)
})

test_that("dr_con() serves exactly the published set of tables", {
  expect_identical(DR_TABLES, PUBLISHED_TABLES)
  expect_error(dr_con("HL"), "Invalid table")          # HL is dr_con_raw()'s
  expect_error(dr_con("HL_standardised"), "Invalid table")
})

test_that("dr_con_raw() serves exactly the four Tier 1 exchange tables", {
  expect_identical(DR_RAW_TABLES, c("HH", "HL", "CA", "LT"))
})

test_that("dr_add_id() produces the column downstream joins bind to", {
  d <- data.frame(Survey = "BITS", Year = 1991L, Quarter = 1L, Country = "DE",
                  Platform = "06S1", Gear = "H20", StationName = "33",
                  HaulNumber = 28L)
  expect_true(".id" %in% names(dr_add_id(d)))
  expect_identical(dr_add_id(d)$.id, "BITS:1991:1:DE:06S1:H20:33:28")
})

# --- online: what is actually on the server ---------------------------------
# The offline tests pin the code. This one pins the FILES, and catches the
# other failure seen on this project: a published parquet sitting two fixes
# behind its own source, which no amount of testing the code can reveal.
test_that("the published files carry the same columns as the code produces", {
  skip_on_cran()
  skip_if_offline()
  for (tbl in names(PUBLISHED_SCHEMA)) {
    got <- tryCatch(colnames(dr_con(tbl)), error = function(e) NULL)
    skip_if(is.null(got), paste("could not reach the published", tbl))
    expect_identical(got, PUBLISHED_SCHEMA[[tbl]],
                     info = paste("published", tbl, "disagrees with the code"))
  }
})
