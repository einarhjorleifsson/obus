# Everything renamed or demoted in 2026.10 still works, warns once, and gives
# the same answer as its replacement.

id_frame <- function() {
  data.frame(Survey = "BITS", Year = 1991L, Quarter = 1L, Country = "DE",
             Platform = "06S1", Gear = "H20", StationName = "33", HaulNumber = 28L)
}

test_that("a renamed first argument still works and warns", {
  lifecycle::expect_deprecated(x <- dr_add_id(d = id_frame()))
  expect_equal(x$.id, dr_add_id(id_frame())$.id)

  len <- data.frame(LengthCode = "1", LengthClass = 10L)
  lifecycle::expect_deprecated(y <- dr_add_length_cm(d = len))
  expect_equal(y, dr_add_length_cm(len))

  lifecycle::expect_deprecated(z <- dr_add_length_mid(d = dr_add_length_cm(len)))
  expect_equal(z, dr_add_length_mid(dr_add_length_cm(len)))
})

test_that("`type` still names the table in dr_con() and dr_get()", {
  skip_on_cran()
  skip_if_offline()
  lifecycle::expect_deprecated(a <- dr_con(type = "species"))
  expect_equal(colnames(a), colnames(dr_con("species")))
  lifecycle::expect_deprecated(g <- dr_get(type = "hl_flag_code"))
  expect_equal(g, dr_get("hl_flag_code"))
})

test_that("dr_get_datras() still takes `aphia`, and `species` takes names or codes", {
  skip_on_cran()
  skip_if_offline()
  lifecycle::expect_deprecated(
    a <- dr_get_datras("NS-IBTS", years = 2019L, quarters = 1L, aphia = 127139L, ca = FALSE))
  b <- dr_get_datras("NS-IBTS", years = 2019L, quarters = 1L, species = 127139L, ca = FALSE)
  expect_equal(nrow(a[["HL"]]), nrow(b[["HL"]]))
  name <- dplyr::pull(dplyr::filter(dr_con("species"), Valid_Aphia == 127139L), latin)
  c <- dr_get_datras("NS-IBTS", years = 2019L, quarters = 1L, species = name, ca = FALSE)
  expect_equal(nrow(c[["HL"]]), nrow(b[["HL"]]))
})

test_that("the upper-case table functions are the lower-case ones, with a warning", {
  hh <- data.frame(.id = "h1", Survey = "S", Year = 2000L, Quarter = 1L,
                   DataType = "R", HaulDuration = 60L, HaulValidity = "V",
                   stringsAsFactors = FALSE)
  hl <- data.frame(.id = "h1", Valid_Aphia = 1L, SpeciesCategory = "1", SpeciesSex = "F",
                   SpeciesCodeType = "W", LengthCode = "1", LengthClass = 10L, LengthType = "1",
                   DevelopmentStage = NA_character_, SpeciesValidity = "1", NumberAtLength = 3,
                   SubsamplingFactor = 1, TotalNumber = 3, SpeciesCategoryWeight = 100,
                   stringsAsFactors = FALSE)
  sp <- data.frame(Valid_Aphia = 1L, latin = "Alpha alpha", species = "alpha", rank = "Species",
                   stringsAsFactors = FALSE)
  lifecycle::expect_deprecated(old <- dr_HL_length(hh, hl, species = sp))
  expect_equal(old, dr_hl_length(hh, hl, species = sp))
  lifecycle::expect_deprecated(old2 <- dr_HL_summary(hh, hl, species = sp))
  expect_equal(old2, dr_hl_summary(hh, hl, species = sp))
})

test_that("demoted helpers warn and delegate to their internal copies", {
  len <- data.frame(LengthCode = c("1", "."), LengthClass = c(10L, 105L))
  lifecycle::expect_deprecated(m <- dr_add_length_mm(len))
  expect_equal(m, .dr_add_length_mm(len))
  expect_equal(m$length_mm, c(100L, 105L))

  lifecycle::expect_deprecated(j <- dr_join_species(data.frame(Valid_Aphia = 1L),
                                                    species = data.frame(Valid_Aphia = 1L, latin = "A a")))
  expect_equal(j$latin, "A a")
})
