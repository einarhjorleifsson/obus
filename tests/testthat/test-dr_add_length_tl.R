# Tests for dr_add_length_tl(): the non-Total-Length landmark conversion.
# Synthetic and offline -- `conv` is always supplied, so nothing reaches
# dr_con(), and the tests do not depend on the exact published factors.

.tl_conv <- function() {
  data.frame(Valid_Aphia = 1L, from_type = "4", intercept = 5, slope = 2)
}

test_that("converts where a factor matches both Valid_Aphia and LengthType", {
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "4", length_cm_mid = 10)
  out <- dr_add_length_tl(catch, .tl_conv())

  expect_equal(out$length_cm_tl, 5 + 2 * 10)
  expect_equal(out$length_type_source, "converted")
})

test_that("LengthType \"1\" is already Total Length and is left alone", {
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "1", length_cm_mid = 10)
  out <- dr_add_length_tl(catch, .tl_conv())

  expect_equal(out$length_cm_tl, 10)
  expect_equal(out$length_type_source, "measured_tl")
})

test_that("NA LengthType takes the assume-TL default", {
  # LengthType is 72% NA in HL. Total Length is both the dominant reported value
  # and the FishBase convention, so absence is read as TL rather than as unknown.
  catch <- data.frame(Valid_Aphia = 1L, LengthType = NA_character_,
                      length_cm_mid = 10)
  out <- dr_add_length_tl(catch, .tl_conv())

  expect_equal(out$length_cm_tl, 10)
  expect_equal(out$length_type_source, "measured_tl")
})

test_that("a non-TL landmark with no traced factor is surfaced, not imputed", {
  catch <- data.frame(Valid_Aphia = 2L, LengthType = "4", length_cm_mid = 10)
  out <- dr_add_length_tl(catch, .tl_conv())

  expect_equal(out$length_cm_tl, 10)
  expect_equal(out$length_type_source, "unconverted")
})

test_that("the input length column is never overwritten", {
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "4", length_cm_mid = 10)
  out <- dr_add_length_tl(catch, .tl_conv())

  expect_equal(out$length_cm_mid, 10)
})

test_that("it converts the midpoint by default, not the bin's lower bound", {
  # The conversion is affine, so it rescales the bin width by `slope` too.
  # Converting first and taking the midpoint afterwards would add half a
  # MEASURED bin to an already-converted length: 5 + 2*10 = 25, then +0.5 = 25.5,
  # where the right answer is 5 + 2*10.5 = 26.
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "4",
                      length_cm = 10, accuracy = 1) |>
    dr_add_length_mid()

  expect_equal(dr_add_length_tl(catch, .tl_conv())$length_cm_tl, 5 + 2 * 10.5)
})

test_that("length_col can be pointed at another length column", {
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "4", length_cm = 10)
  out <- dr_add_length_tl(catch, .tl_conv(), length_col = "length_cm")

  expect_equal(out$length_cm_tl, 5 + 2 * 10)
})

test_that("missing required columns raise an informative error", {
  expect_error(
    dr_add_length_tl(data.frame(Valid_Aphia = 1L, length_cm_mid = 10), .tl_conv()),
    "LengthType"
  )
  expect_error(
    dr_add_length_tl(data.frame(Valid_Aphia = 1L, LengthType = "4"), .tl_conv()),
    "length_cm_mid"
  )
})

test_that("the converted length feeds dr_add_predicted_weight()", {
  # The composition the two functions exist for: midpoint, then landmark, then
  # weight. Documented as a pipeline, so it is tested as one.
  catch <- data.frame(Valid_Aphia = 1L, LengthType = "4",
                      length_cm = 10, accuracy = 1) |>
    dr_add_length_mid() |>
    dr_add_length_tl(.tl_conv())
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")

  out <- dr_add_predicted_weight(catch, lw, length_col = "length_cm_tl")

  expect_equal(out$w_ind, 0.01 * (5 + 2 * 10.5) ^ 3)
})

test_that("DuckDB lazy path matches the eager result", {
  skip_if_not_installed("duckdbfs")

  catch <- data.frame(Valid_Aphia = c(1L, 2L), LengthType = c("4", "4"),
                      length_cm_mid = c(10, 10))
  lazy <- dplyr::copy_to(duckdbfs::cached_connection(), catch,
                         "test_add_length_tl_catch", overwrite = TRUE)

  out <- dr_add_length_tl(lazy, .tl_conv()) |> dplyr::collect()
  out <- out[order(out$Valid_Aphia), ]

  expect_equal(out$length_cm_tl, c(5 + 2 * 10, 10))
  expect_equal(out$length_type_source, c("converted", "unconverted"))
})
