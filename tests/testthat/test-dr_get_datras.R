# Tests for dr_get_datras(): synthetic, offline. The function itself reads from
# dr_con(), so the end-to-end run lives in data-raw/CHECK_datras_adapter.R
# (online, 11/11 against DATRASextra's own `dab`). What is testable here is the
# structural contract {DATRAS} relies on, and the two lookup tables copied out
# of its unexported addExtraVariables().

test_that("the object is a three-element list in CA, HH, HL order", {
  # {DATRAS} indexes positionally -- x[[1]] is CA, x[[2]] is HH, x[[3]] is HL --
  # while {DATRASextra} indexes by name. Both must work, and a NULL CA must
  # still occupy position 1 rather than shortening the list.
  d <- list(CA = NULL,
            HH = data.frame(haul.id = "a"),
            HL = data.frame(haul.id = "a"))
  class(d) <- c("datras_raw", "DATRASraw")

  expect_length(unclass(d), 3L)
  expect_identical(names(unclass(d)), c("CA", "HH", "HL"))
  expect_null(unclass(d)[[1]])
  expect_identical(unclass(d)[[2]], d[["HH"]])
})

test_that("the class vector matches DATRASextra:::.add_class_datras()", {
  # Hard-coded rather than called, because {DATRASextra} is Suggests. If the
  # order ever flips, print/summary dispatch goes to the wrong method.
  d <- list(CA = NULL, HH = data.frame(), HL = data.frame())
  class(d) <- c("datras_raw", "DATRASraw")
  expect_identical(class(d), c("datras_raw", "DATRASraw"))
  expect_s3_class(d, "DATRASraw")
})

test_that(".dr_lngtcode_cm rescales LengthClass, and is not the bin width", {
  # From DATRAS::addExtraVariables(): codes "." and "0" record LengthClass in
  # mm, "1"/"2"/"5" in cm. getAccuracyCM()'s c(0.1, 0.5, 1, 2, 5) is the bin
  # WIDTH and a different quantity -- conflating them is a real bug elsewhere.
  expect_identical(unname(.dr_lngtcode_cm[c(".", "0", "1", "2", "5")]),
                   c(0.1, 0.1, 1, 1, 1))
  expect_equal(unname(.dr_lngtcode_cm["0"]) * 255, 25.5)   # mm -> cm
  expect_equal(unname(.dr_lngtcode_cm["5"]) * 65, 65)      # already cm
})

test_that("accuracy maps to LngtCode as a bijection on the five valid codes", {
  expect_identical(unname(.dr_code_of_accuracy[c("0.1", "0.5", "1", "2", "5")]),
                   c(".", "0", "1", "2", "5"))
  expect_length(unique(.dr_code_of_accuracy), 5L)
})

test_that(".dr_facify levels haul.id on HH so subset() stays consistent", {
  # subset.DATRASraw() filters HH then keeps CA/HL rows whose haul.id is in
  # levels(factor(HH$haul.id)). If HL carried its own levels, a haul present in
  # HL but absent from HH would survive as a level and desynchronise the two.
  lev <- c("h1", "h2")
  hl  <- data.frame(haul.id = c("h1", "h1"), Year = 2020L, Quarter = 1L,
                    Species = "Gadus morhua", stringsAsFactors = FALSE)
  out <- .dr_facify(hl, lev)

  expect_identical(levels(out$haul.id), lev)
  expect_s3_class(out$Year, "factor")
  expect_s3_class(out$Quarter, "factor")
  expect_s3_class(out$Species, "factor")
  expect_s3_class(out, "data.frame")
})

test_that(".dr_facify keeps a haul.id that is not in HH as NA, not a new level", {
  out <- .dr_facify(data.frame(haul.id = "orphan", Year = 2020L, Quarter = 1L),
                    lev = c("h1", "h2"))
  expect_true(is.na(out$haul.id))
  expect_identical(levels(out$haul.id), c("h1", "h2"))
})


# --- .dr_as_datras_build(): the reshape, offline -----------------------------
# Fixtures are written in opus's CURRENT field names, exactly as dr_con()
# serves them, so what is tested is the same rename/derive path the online
# function takes. op_rename() tolerates a partial column set, so these stay
# small.

.datras_fixture <- function() {
  hh <- data.frame(
    .id = "NS-IBTS:2020:1:DK:SHIP:GOV:1:1",
    Survey = "NS-IBTS", Year = 2020L, Quarter = 1L, Country = "DK",
    Platform = "SHIP", Gear = "GOV", StationName = "1", HaulNumber = 1L,
    Month = 2L, Day = 15L, StartTime = "0730", HaulDuration = 30,
    ShootLongitude = 4.5, ShootLatitude = 55.5,
    StatisticalRectangle = "44F0", DataType = "R",
    stringsAsFactors = FALSE
  )
  # 126436 was measured; 126437 was counted but never run through calipers.
  len <- data.frame(
    .id = hh$.id, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
    Valid_Aphia = 126436L, latin = "Gadus morhua", species = "Cod",
    rank = "Species", length_mm = 255L, length_cm = 25.5, accuracy = 1,
    LengthType = "1", SpeciesSex = "F", DevelopmentStage = NA_character_,
    n_haul = 8, n_hour = 16, n_measured = 4, SpeciesValidity = 1L,
    stringsAsFactors = FALSE
  )
  smry <- data.frame(
    .id = hh$.id, Survey = "NS-IBTS", Year = 2020L, Quarter = 1L,
    Valid_Aphia = c(126436L, 126437L),
    latin = c("Gadus morhua", "Melanogrammus aeglefinus"),
    species = c("Cod", "Haddock"), rank = "Species",
    n_totalnumber = c(8, 3), n_haul = c(8, 3), w_haul = c(500, 200),
    n_measured = c(4, 0), SpeciesValidity = 1L,
    stringsAsFactors = FALSE
  )
  ca <- data.frame(
    .id = c(hh$.id, "NO:SUCH:HAUL:X:X:X:NA:NA"),
    Survey = "NS-IBTS", Year = 2020L, Quarter = 1L, Country = "DK",
    Platform = "SHIP", Gear = "GOV", StationName = "1", HaulNumber = 1L,
    Valid_Aphia = 126436L, SpeciesCode = 126436L, SpeciesCodeType = "W",
    AreaCode = "44F0", LengthCode = "1", LengthClass = 25L,
    IndividualSex = "F", Age = 3L, NumberAtLength = 2, IndividualWeight = 180,
    stringsAsFactors = FALSE
  )
  sp <- data.frame(Valid_Aphia = c(126436L, 126437L),
                   latin = c("Gadus morhua", "Melanogrammus aeglefinus"),
                   stringsAsFactors = FALSE)
  list(hh = hh, len = len, smry = smry, ca = ca, species = sp)
}

# The fixture carries one deliberate orphan CA row, so every build emits the
# drop message. Quiet it here; the test that asserts it calls .build_loud().
.build_loud <- function(f = .datras_fixture(), ...) {
  args <- list(hh = f$hh, hl_length = f$len, hl_summary = f$smry,
               ca = f$ca, species = f$species)
  do.call(.dr_as_datras_build, utils::modifyList(args, list(...)))
}
.build <- function(...) suppressMessages(.build_loud(...))

test_that("the builder needs no connection and returns a valid object", {
  out <- .build()
  expect_identical(class(out), c("datras_raw", "DATRASraw"))
  expect_identical(names(unclass(out)), c("CA", "HH", "HL"))
  expect_equal(nrow(out[["HH"]]), 1L)
})

test_that("HH arrives under legacy ICES names", {
  hh <- .build()[["HH"]]
  expect_true(all(c("Ship", "StNo", "HaulNo", "TimeShot", "HaulDur",
                    "StatRec") %in% names(hh)))
  expect_false(any(c("Platform", "StationName", "HaulNumber", "StartTime",
                     "HaulDuration") %in% names(hh)))
})

test_that("the six columns addExtraVariables() derives are reproduced", {
  hh <- .build()[["HH"]]
  expect_identical(as.character(hh$haul.id), "NS-IBTS:2020:1:DK:SHIP:GOV:1:1")
  expect_equal(hh$lon, 4.5)
  expect_equal(hh$lat, 55.5)
  expect_equal(hh$TimeShotHour, 7.5)                       # "0730" -> 7.5
  expect_equal(hh$abstime, 2020 + 1/12 + 14/365)
  expect_equal(hh$timeOfYear, 1/12 + 14/365)
})

test_that("a measured species becomes an HL row carrying its length", {
  hl <- .build()[["HL"]]
  m  <- hl[!is.na(hl$LngtCm), ]
  expect_equal(nrow(m), 1L)
  expect_equal(m$LngtCm, 25.5)
  expect_identical(as.character(m$LngtCode), "1")
  expect_equal(m$LngtClas, 25L)          # accuracy 1 cm -> mm/10
  expect_equal(m$Count, 8)               # Count IS n_haul
  expect_equal(m$HLNoAtLngt, 4)
  expect_equal(m$SubFactor, 2)           # n_haul / n_measured
  expect_equal(m$TotalNo, 8)             # joined from HL_summary
})

test_that("LngtClas keeps mm when the accuracy is finer than 1 cm", {
  f <- .datras_fixture()
  f$len$accuracy <- 0.5
  m <- .build(f)[["HL"]]
  m <- m[!is.na(m$LngtCm), ]
  expect_equal(m$LngtClas, 255L)
  expect_identical(as.character(m$LngtCode), "0")
})

test_that("a bulk-only species becomes an HL row with no length", {
  # In HL_summary but not HL_length -- counted, never measured. DATRAS carries
  # these as length-less HL rows, and species richness needs them.
  hl <- .build()[["HL"]]
  b  <- hl[is.na(hl$LngtCm), ]
  expect_equal(nrow(b), 1L)
  expect_identical(as.character(b$Species), "Melanogrammus aeglefinus")
  expect_true(is.na(b$Count))
  expect_equal(b$TotalNo, 3)
})

test_that("CA gets renameDATRAS()'s two renames and its derived columns", {
  ca <- .build()[["CA"]]
  expect_true(all(c("LngtClas", "NoAtALK") %in% names(ca)))
  expect_false(any(c("LngtClass", "CANoAtLngt", "NumberAtLength") %in% names(ca)))
  expect_equal(ca$LngtCm, 25)                       # code "1" -> multiplier 1
  expect_identical(as.character(ca$Species), "Gadus morhua")
  expect_identical(as.character(ca$StatRec), "44F0")  # from AreaCode
  expect_equal(ca$Age, 3L)
})

test_that("CA rows matching no haul are dropped, with a message", {
  expect_message(out <- .build_loud(), "1 of 2 CA rows that match no haul")
  expect_equal(nrow(out[["CA"]]), 1L)
})

test_that("ca = NULL leaves CA NULL but the list still has three slots", {
  out <- .build(ca = NULL, species = NULL)
  expect_null(out[["CA"]])
  expect_length(unclass(out), 3L)
  expect_identical(names(unclass(out)), c("CA", "HH", "HL"))
})

test_that("an HL with no rows warns rather than failing quietly", {
  f <- .datras_fixture()
  f$len  <- f$len[0, ]
  f$smry <- f$smry[0, ]
  expect_warning(out <- .build(f), "no HL rows did")
  expect_equal(nrow(out[["HL"]]), 0L)
})

test_that("no haul at all is an error naming the filters", {
  f <- .datras_fixture()
  f$hh <- f$hh[0, ]
  expect_error(suppressWarnings(.build(f)), "no hauls matched")
})
