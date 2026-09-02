# Tests for dr_add_length_mid(). DATRAS LengthClass is the LOWER BOUNDARY of a
# length bin (ICES field descriptions, HL and CA alike), so the midpoint is the
# unbiased point estimate of a fish's length -- and the only defensible input to
# W = a * L^b, which is convex.

test_that("the midpoint is half a bin above the lower bound, per LengthCode", {
  d <- data.frame(LengthCode = c(".", "0", "1", "2", "5"),
                  LengthClass = c(101, 105, 10, 10, 30))
  out <- d |> dr_add_length_cm() |> dr_add_length_mid()

  #                       lower bound   bin width   midpoint
  #   "."  101 mm      ->  10.1          0.1         10.15
  #   "0"  105 mm      ->  10.5          0.5         10.75
  #   "1"   10 cm      ->  10.0          1.0         10.5
  #   "2"   10 cm      ->  10.0          2.0         11.0
  #   "5"   30 cm      ->  30.0          5.0         32.5
  expect_equal(out$length_cm_mid, c(10.15, 10.75, 10.5, 11.0, 32.5))
})

test_that("an unusable LengthCode gives NA rather than the lower bound", {
  # No bin width means no midpoint. Falling back to length_cm would silently
  # reinstate exactly the bias this function exists to remove.
  d <- data.frame(LengthCode = "-9", LengthClass = 100)
  out <- d |> dr_add_length_cm() |> dr_add_length_mid()

  expect_true(is.na(out$length_cm_mid))
})

test_that("missing required columns raise an informative error", {
  expect_error(dr_add_length_mid(data.frame(length_cm = 10)), "accuracy")
  expect_error(dr_add_length_mid(data.frame(accuracy = 1)), "length_cm")
})

test_that("the lower bound under-predicts weight, by the amount claimed", {
  # The reason this function exists, pinned as a number: with 1 cm bins and
  # b = 3, predicting from the bin's lower bound rather than its midpoint loses
  # 5.1% at 30 cm and 15.8% at 10 cm.
  ratio <- function(L, w = 1, b = 3) ((L + w / 2) / L) ^ b
  expect_equal(round(100 * (ratio(30) - 1), 1), 5.1)
  expect_equal(round(100 * (ratio(10) - 1), 1), 15.8)
})

test_that("DuckDB lazy path matches the eager result", {
  skip_if_not_installed("duckdbfs")

  d <- data.frame(LengthCode = c(".", "1", "5"), LengthClass = c(101, 10, 30))
  lazy <- dplyr::copy_to(duckdbfs::cached_connection(), d,
                         "test_length_mid", overwrite = TRUE)

  out <- lazy |> dr_add_length_cm() |> dr_add_length_mid() |> dplyr::collect()
  expect_equal(sort(out$length_cm_mid), c(10.15, 10.5, 32.5))
})
