# Tests for dr_add_predicted_weight(): the apply step of the length-weight
# cascade. Synthetic and offline -- `lw` is always supplied, so nothing here
# reaches dr_con(). The lazy cases register small DuckDB tables.

# A catch table already carrying the bin midpoint, which is what the function
# takes by default.
.lw_catch <- function(Valid_Aphia, length_cm_mid, ...) {
  data.frame(Valid_Aphia = Valid_Aphia, length_cm_mid = length_cm_mid, ...)
}

test_that("computes W = a * L^b and the catch-weight products (eager)", {
  lw <- data.frame(Valid_Aphia = c(1L, 2L), a = c(0.01, 0.02), b = c(3, 2.9),
                   lw_source = c("ca_fit", "default_constant"),
                   n_ca = c(100L, NA))
  catch <- .lw_catch(c(1L, 1L, 2L), c(10, 20, 30),
                     n_haul = c(5, 3, 2), n_hour = c(10, 6, 4))

  out <- dr_add_predicted_weight(catch, lw)

  expect_equal(out$w_ind, c(0.01 * 10 ^ 3, 0.01 * 20 ^ 3, 0.02 * 30 ^ 2.9))
  expect_equal(out$w_haul_pred, out$n_haul * out$w_ind)
  expect_equal(out$w_hour_pred, out$n_hour * out$w_ind)
  expect_true(all(c("a", "b", "lw_source") %in% names(out)))  # provenance carried
})

test_that("the default length column is the bin midpoint, not the lower bound", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  full <- data.frame(Valid_Aphia = 1L, length_cm = 30, accuracy = 1) |>
    dr_add_length_mid()

  expect_equal(dr_add_predicted_weight(full, lw)$w_ind, 0.01 * 30.5 ^ 3)
})

test_that("a table with only length_cm is refused, and the message says why", {
  # The likeliest mistake: piping dr_con("HL_length") straight in. Silently
  # predicting from the lower bound would under-report weight by several
  # percent with nothing to show for it.
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  catch <- data.frame(Valid_Aphia = 1L, length_cm = 30)

  expect_error(dr_add_predicted_weight(catch, lw), "dr_add_length_mid")
  expect_error(dr_add_predicted_weight(catch, lw), "LOWER BOUND")
})

test_that("length_col = \"length_cm\" opts back into the lower bound deliberately", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  catch <- data.frame(Valid_Aphia = 1L, length_cm = 30)

  out <- dr_add_predicted_weight(catch, lw, length_col = "length_cm")
  expect_equal(out$w_ind, 0.01 * 30 ^ 3)
})

test_that("unknown Valid_Aphia yields NA prediction rather than an error", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  catch <- .lw_catch(c(1L, 999L), c(10, 10), n_haul = c(1, 1))

  out <- dr_add_predicted_weight(catch, lw)

  expect_equal(out$w_ind[out$Valid_Aphia == 1L], 0.01 * 10 ^ 3)
  expect_true(is.na(out$w_ind[out$Valid_Aphia == 999L]))
  expect_true(is.na(out$lw_source[out$Valid_Aphia == 999L]))
})

test_that("w_ind is computed even without n_haul / n_hour", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  out <- dr_add_predicted_weight(.lw_catch(1L, 10), lw)

  expect_equal(out$w_ind, 0.01 * 10 ^ 3)
  expect_false("w_haul_pred" %in% names(out))
  expect_false("w_hour_pred" %in% names(out))
})

test_that("missing Valid_Aphia raises an informative error", {
  expect_error(
    dr_add_predicted_weight(data.frame(length_cm_mid = 10),
                            data.frame(Valid_Aphia = 1L, a = 1, b = 1)),
    "Valid_Aphia"
  )
})

test_that("bias_correct scales a by exp(sigma^2/2) for ca_fit rows only", {
  lw <- data.frame(Valid_Aphia = 1:3, a = 0.01, b = 3,
                   lw_source = c("ca_fit", "default_constant", "ca_fit"),
                   sigma = c(0.5, NA, NA))
  catch <- .lw_catch(1:3, c(10, 10, 10))

  base <- dr_add_predicted_weight(catch, lw)
  bc   <- dr_add_predicted_weight(catch, lw, bias_correct = TRUE)

  expect_equal(bc$w_ind[1], base$w_ind[1] * exp(0.5 ^ 2 / 2))
  expect_equal(bc$w_ind[2], base$w_ind[2])   # other tier, no sigma -> untouched
  expect_equal(bc$w_ind[3], base$w_ind[3])   # ca_fit but no sigma -> untouched
})

test_that("bias_correct = FALSE (default) is identical to the baseline", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit",
                   sigma = 0.5)
  catch <- .lw_catch(1L, 10)

  expect_identical(dr_add_predicted_weight(catch, lw),
                   dr_add_predicted_weight(catch, lw, bias_correct = FALSE))
})

test_that("exclude_tiers NAs out coefficients for the named tiers only", {
  lw <- data.frame(Valid_Aphia = c(1L, 2L), a = c(0.01, 0.02), b = c(3, 2.9),
                   lw_source = c("ca_fit", "sealifebase_genus"))
  catch <- .lw_catch(c(1L, 2L), c(10, 10))

  out <- dr_add_predicted_weight(catch, lw, exclude_tiers = "sealifebase_genus")

  expect_equal(out$w_ind[out$Valid_Aphia == 1L], 0.01 * 10 ^ 3)
  expect_true(is.na(out$w_ind[out$Valid_Aphia == 2L]))
  expect_true(is.na(out$a[out$Valid_Aphia == 2L]))
})

test_that("exclude_tiers = NULL (default) leaves every tier untouched", {
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit")
  catch <- .lw_catch(1L, 10)

  expect_identical(dr_add_predicted_weight(catch, lw),
                   dr_add_predicted_weight(catch, lw, exclude_tiers = NULL))
})

test_that("DuckDB lazy path matches the eager result and translates ^", {
  skip_if_not_installed("duckdbfs")

  catch <- .lw_catch(c(1L, 2L), c(10, 30), n_haul = c(5, 2), n_hour = c(10, 4))
  lazy  <- dplyr::copy_to(duckdbfs::cached_connection(), catch,
                          "test_predicted_weight_catch", overwrite = TRUE)
  lw <- data.frame(Valid_Aphia = c(1L, 2L), a = c(0.01, 0.02), b = c(3, 2.9),
                   lw_source = "ca_fit")

  out <- dr_add_predicted_weight(lazy, lw) |> dplyr::collect()
  out <- out[order(out$Valid_Aphia), ]

  expect_equal(out$w_ind, c(0.01 * 10 ^ 3, 0.02 * 30 ^ 2.9), tolerance = 1e-8)
  expect_equal(out$w_haul_pred, out$n_haul * out$w_ind, tolerance = 1e-8)
  expect_equal(out$w_hour_pred, out$n_hour * out$w_ind, tolerance = 1e-8)
})

test_that("bias_correct round-trips through the DuckDB lazy path", {
  skip_if_not_installed("duckdbfs")

  catch <- .lw_catch(1L, 10)
  lazy  <- dplyr::copy_to(duckdbfs::cached_connection(), catch,
                          "test_bias_correct_catch", overwrite = TRUE)
  lw <- data.frame(Valid_Aphia = 1L, a = 0.01, b = 3, lw_source = "ca_fit",
                   sigma = 0.5)

  out <- dr_add_predicted_weight(lazy, lw, bias_correct = TRUE) |> dplyr::collect()
  expect_equal(out$w_ind, 0.01 * exp(0.5 ^ 2 / 2) * 10 ^ 3, tolerance = 1e-8)
})
