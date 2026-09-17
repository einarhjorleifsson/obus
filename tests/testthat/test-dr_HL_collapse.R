# Tests for dr_HL_collapse(): synthetic and offline. The two guards it exists
# for -- the all-NA 0-in-R / NULL-in-SQL divergence and the DataType == "C"
# rule for n_measured -- only diverge ACROSS backends, so the aggregation
# tests run twice: once on an eager data frame and once on the same rows in an
# in-memory DuckDB, which is the same SQL translation the published tables use.

.collapse_fixture <- function() {
  # One haul, one species, one length. Two sexes x two stages = four rows that
  # must collapse to one. Row 3 carries an all-NA n_hour group after the sexes
  # merge; the second length_mm is all-NA in n_measured, standing in for
  # DataType == "C".
  data.frame(
    .id              = "S:2020:1:XX:SHIP:GEAR:1:1",
    Survey           = "NS-IBTS",
    Year             = 2020L,
    Quarter          = 1L,
    Valid_Aphia      = 126417L,
    latin            = "Gadus morhua",
    species          = "Atlantic cod",
    rank             = "Species",
    length_mm        = c(100L, 100L, 100L, 100L, 200L, 200L),
    length_cm        = c(10, 10, 10, 10, 20, 20),
    accuracy         = 0.1,
    LengthType       = "1",
    SpeciesSex       = c("F", "M", "F", "M", "F", "M"),
    DevelopmentStage = c("1", "1", "2", "2", NA_character_, NA_character_),
    n_haul           = c(1, 2, 4, 8, 16, 32),
    n_hour           = c(NA_real_, NA_real_, 3, 5, 7, 11),
    n_measured       = c(1, 2, 4, 8, NA_real_, NA_real_),
    SpeciesValidity  = "1",
    stringsAsFactors = FALSE
  )
}

# Same rows, as a lazy tbl over a real SQL backend.
.as_lazy <- function(df) {
  testthat::skip_if_not_installed("duckdb")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  DBI::dbWriteTable(con, "x", df)
  dplyr::tbl(con, "x")
}

.sorted <- function(x) {
  x <- as.data.frame(dplyr::collect(x))
  x <- x[do.call(order, x[intersect(c(".id", "length_mm", "SpeciesSex",
                                      "DevelopmentStage"), names(x))]), ]
  rownames(x) <- NULL
  x
}

# --- aggregation, on both backends ------------------------------------------

test_that("collapsing sex sums the measures and drops only that column", {
  f <- .collapse_fixture()
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    out <- .sorted(dr_HL_collapse(x, "SpeciesSex"))

    expect_false("SpeciesSex" %in% names(out), info = nm)
    expect_equal(names(out), setdiff(names(f), "SpeciesSex"), info = nm)
    expect_equal(nrow(out), 3L, info = nm)
    # 1+2, 4+8, 16+32
    expect_equal(sort(out$n_haul), c(3, 12, 48), info = nm)
  }
})

test_that("the two backends agree row for row", {
  f <- .collapse_fixture()
  eager <- .sorted(dr_HL_collapse(f, c("SpeciesSex", "DevelopmentStage")))
  lazy  <- .sorted(dr_HL_collapse(.as_lazy(f), c("SpeciesSex", "DevelopmentStage")))
  expect_equal(eager, lazy)
})

test_that("column order is preserved", {
  f <- .collapse_fixture()
  out <- dr_HL_collapse(f, "DevelopmentStage")
  expect_equal(names(out), setdiff(names(f), "DevelopmentStage"))
})

# --- the all-NA guard: 0 in R, NULL in SQL ----------------------------------

test_that("a group with nothing to sum stays NA rather than becoming 0", {
  f <- .collapse_fixture()
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    out <- .sorted(dr_HL_collapse(x, "SpeciesSex"))
    # length_mm 100 / stage 1 has n_hour NA on both rows
    g <- out[out$length_mm == 100 & !is.na(out$DevelopmentStage) &
               out$DevelopmentStage == "1", ]
    expect_equal(nrow(g), 1L, info = nm)
    expect_true(is.na(g$n_hour), info = nm)
    expect_false(isTRUE(g$n_hour == 0), info = nm)
    # the other group has real values and must still sum
    expect_equal(out$n_hour[out$length_mm == 200], 18, info = nm)
  }
})

test_that("n_measured NA survives the collapse -- the DataType == 'C' rule", {
  # DataType is haul-level and .id is never collapsed, so a group is all-NA or
  # none; the all-NA guard is what reproduces the rule, since HL_length does
  # not carry DataType.
  f <- .collapse_fixture()
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    out <- .sorted(dr_HL_collapse(x, c("SpeciesSex", "DevelopmentStage")))
    expect_true(is.na(out$n_measured[out$length_mm == 200]), info = nm)
    expect_equal(out$n_measured[out$length_mm == 100], 15, info = nm)
    expect_false(any(out$n_measured == 0, na.rm = TRUE), info = nm)
  }
})

# --- the mixing check -------------------------------------------------------

test_that("collapsing accuracy or LengthType errors where the data mixes them", {
  f <- .collapse_fixture()
  f$LengthType[2] <- "2"      # same length_mm, two length conventions
  f$accuracy[4]   <- 0.5      # same length_mm, two bin widths
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    expect_error(dr_HL_collapse(x, c("SpeciesSex", "LengthType")),
                 "mixes total against standard length", info = nm)
    expect_error(dr_HL_collapse(x, c("SpeciesSex", "accuracy")),
                 "different bins", info = nm)
  }
})

test_that("the mixing check passes where the data does not mix", {
  f <- .collapse_fixture()
  out <- dr_HL_collapse(f, c("SpeciesSex", "DevelopmentStage",
                             "accuracy", "LengthType"))
  expect_false(any(c("accuracy", "LengthType") %in% names(out)))
  expect_equal(nrow(out), 2L)
})

test_that("check = FALSE skips the check", {
  f <- .collapse_fixture()
  f$LengthType[2] <- "2"
  expect_error(dr_HL_collapse(f, c("SpeciesSex", "LengthType")), "mixes total")
  expect_silent(dr_HL_collapse(f, c("SpeciesSex", "LengthType"), check = FALSE))
})

test_that("the check is against the RESULTING grain, not the input", {
  # Two rows differ in LengthType but also in SpeciesSex, so collapsing only
  # LengthType never puts them in one group and nothing is summed across the
  # mixed convention. Erroring here would refuse a safe reduction.
  f <- .collapse_fixture()
  f$LengthType[2] <- "2"
  expect_silent(dr_HL_collapse(f, "LengthType"))
  expect_error(dr_HL_collapse(f, c("SpeciesSex", "LengthType")), "mixes total")
})

test_that("an NA LengthType is a level of its own, not skipped", {
  # n_distinct() counts NA in R while COUNT(DISTINCT) ignores NULL in SQL, and
  # LengthType is NA on 70.74% of HL_length -- so the backends would disagree
  # on exactly the rows that matter without the coalesce-to-sentinel.
  f <- .collapse_fixture()
  f$LengthType[2] <- NA_character_
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    expect_error(dr_HL_collapse(x, c("SpeciesSex", "LengthType")),
                 "mixes total against standard length", info = nm)
  }
})

# --- refusals ---------------------------------------------------------------

test_that("SpeciesValidity collapses -- it is a record type, not a quality flag", {
  # Filtering to `1` would discard real records: DATRAS allows several record
  # types per species per haul. Summing across it is the right operation for a
  # total; naming it in `collapse` is what makes that deliberate.
  f <- .collapse_fixture()
  f$SpeciesValidity <- c("1", "1", "1", "5", "1", "1")
  for (nm in c("eager", "lazy")) {
    x <- if (nm == "eager") f else .as_lazy(f)
    out <- .sorted(dr_HL_collapse(x, c("SpeciesSex", "DevelopmentStage",
                                       "SpeciesValidity")))
    expect_false("SpeciesValidity" %in% names(out), info = nm)
    expect_equal(nrow(out), 2L, info = nm)
    expect_equal(out$n_haul, c(1 + 2 + 4 + 8, 16 + 32), info = nm)
  }
})

test_that("length is refused, and points at dr_HL_summary()", {
  f <- .collapse_fixture()
  expect_error(dr_HL_collapse(f, "length_mm"), "dr_HL_summary")
  expect_error(dr_HL_collapse(f, "length_cm"), "dr_HL_summary")
})

test_that("the identifying fields are refused", {
  f <- .collapse_fixture()
  expect_error(dr_HL_collapse(f, ".id"), "identify the observation")
  expect_error(dr_HL_collapse(f, "Valid_Aphia"), "identify the observation")
})

test_that("an unknown or absent column is refused by name", {
  f <- .collapse_fixture()
  expect_error(dr_HL_collapse(f, "Quarter"), "Cannot collapse 'Quarter'")
  expect_error(dr_HL_collapse(f, character(0)), "non-empty character vector")
  expect_error(dr_HL_collapse(f[setdiff(names(f), "SpeciesSex")], "SpeciesSex"),
               "Not a column")
})

test_that("a table with no measure columns is refused", {
  f <- .collapse_fixture()[, c(".id", "Valid_Aphia", "length_mm", "SpeciesSex")]
  expect_error(dr_HL_collapse(f, "SpeciesSex"), "does not look like")
})
