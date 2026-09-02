# Tests for the length-weight PRODUCERS -- the internal helpers
# data-raw/DATASET_length_weight.R uses to build each tier of the cascade.
# Synthetic and offline: no rfishbase call, no dr_con().

# ---- .dr_lw_fit_ca() --------------------------------------------------------

test_that("the CA fit recovers coefficients it was given", {
  skip_if_not_installed("broom")
  skip_if_not_installed("purrr")
  skip_if_not_installed("tidyr")

  a_true <- 0.0085; b_true <- 3.05
  L  <- rep(seq(10, 60, by = 2), each = 5)
  ca <- data.frame(Valid_Aphia = 1L, length_cm = L,
                   IndividualWeight = a_true * L ^ b_true)

  # An exact power law makes lm() warn 'essentially perfect fit'. That is
  # the point of the fixture -- it is what lets us assert exact recovery.
  fit <- suppressWarnings(.dr_lw_fit_ca(ca))

  expect_equal(nrow(fit), 1L)
  expect_equal(fit$a, a_true, tolerance = 1e-6)
  expect_equal(fit$b, b_true, tolerance = 1e-6)
  expect_equal(fit$n_ca, nrow(ca))
  expect_lt(fit$sigma, 1e-6)          # exact power law -> no residual scatter
})

test_that("species below the sample-size or length-class gates are dropped", {
  skip_if_not_installed("broom")

  L <- seq(10, 60, by = 2)
  ok <- data.frame(Valid_Aphia = 1L, length_cm = rep(L, each = 5),
                   IndividualWeight = 0.01 * rep(L, each = 5) ^ 3)
  few_fish    <- data.frame(Valid_Aphia = 2L, length_cm = L[1:10],
                            IndividualWeight = 0.01 * L[1:10] ^ 3)   # 10 < 30
  few_classes <- data.frame(Valid_Aphia = 3L, length_cm = rep(c(10, 12), 40),
                            IndividualWeight = 0.01 * rep(c(10, 12), 40) ^ 3)  # 2 < 5

  fit <- suppressWarnings(.dr_lw_fit_ca(rbind(ok, few_fish, few_classes)))

  expect_equal(fit$Valid_Aphia, 1L)
})

test_that("an implausible exponent is rejected by the b_range gate", {
  skip_if_not_installed("broom")

  L  <- rep(seq(10, 60, by = 2), each = 5)
  ca <- data.frame(Valid_Aphia = 1L, length_cm = L,
                   IndividualWeight = 0.01 * L ^ 6)   # b = 6, far outside (2, 4)

  expect_equal(nrow(suppressWarnings(.dr_lw_fit_ca(ca))), 0L)
})

test_that("non-positive lengths and weights are dropped before fitting", {
  skip_if_not_installed("broom")

  L  <- rep(seq(10, 60, by = 2), each = 5)
  ca <- rbind(
    data.frame(Valid_Aphia = 1L, length_cm = L, IndividualWeight = 0.01 * L ^ 3),
    data.frame(Valid_Aphia = 1L, length_cm = c(0, -5, 10),
               IndividualWeight = c(100, 100, 0))
  )

  fit <- suppressWarnings(.dr_lw_fit_ca(ca))

  expect_equal(fit$n_ca, length(L))    # the three bad rows never reach lm()
  expect_equal(fit$b, 3, tolerance = 1e-6)
})

# ---- .dr_lw_from_estimate() -------------------------------------------------

test_that("FishBase estimates map back to Valid_Aphia by queried name", {
  est <- data.frame(Species = c("Gadus morhua", "Clupea harengus"),
                    a = c(0.0089, 0.0055), b = c(3.04, 3.12))
  map <- data.frame(name = c("Gadus morhua", "Clupea harengus"),
                    Valid_Aphia = c(126436L, 126417L))

  out <- .dr_lw_from_estimate(est, map)

  expect_equal(out$Valid_Aphia, c(126417L, 126436L))       # sorted by key
  expect_equal(out$a[out$Valid_Aphia == 126436L], 0.0089)
  expect_identical(names(out), c("Valid_Aphia", "a", "b"))
})

test_that("implausible or missing FishBase coefficients are filtered out", {
  est <- data.frame(Species = c("A a", "B b", "C c", "D d"),
                    a = c(0.01, NA, -1, 0.01), b = c(3, 3, 3, 9))
  map <- data.frame(name = c("A a", "B b", "C c", "D d"),
                    Valid_Aphia = 1:4)

  expect_equal(.dr_lw_from_estimate(est, map)$Valid_Aphia, 1L)
})

# ---- .dr_lw_consensus() -----------------------------------------------------

test_that("one study passes straight through", {
  out <- .dr_lw_consensus(data.frame(a = 0.01, b = 3))
  expect_equal(out$a, 0.01)
  expect_equal(out$b, 3)
  expect_equal(out$n_src, 1L)
})

test_that("identical studies collapse to their common curve", {
  out <- .dr_lw_consensus(data.frame(a = c(0.01, 0.01, 0.01), b = c(3, 3, 3)))
  expect_equal(out$a, 0.01, tolerance = 1e-8)
  expect_equal(out$b, 3, tolerance = 1e-8)
  expect_equal(out$n_src, 3L)
})

test_that("consensus follows the median CURVE, exactly when one exists", {
  # Three studies sharing an exponent: the median predicted weight at every
  # length is the middle study's own curve, so the refit must recover it
  # exactly. This is the property the function claims -- median in weight
  # space, not in coefficient space.
  ab  <- data.frame(a = c(0.005, 0.010, 0.020), b = c(3, 3, 3))
  out <- .dr_lw_consensus(ab)

  expect_equal(out$a, 0.010, tolerance = 1e-8)
  expect_equal(out$b, 3, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(out$a, mean(ab$a))))   # mean(a) would be 0.0117
})

test_that("crossing studies give a curve inside their envelope, not mean(a, b)", {
  # When a and b trade off, the studies' curves CROSS, so the pointwise median
  # is piecewise and no single power law passes through it -- the refit is a
  # summary, and the test says only what is true of a summary: it stays inside
  # the envelope of its inputs, and it is not the independent means (which,
  # a and b being jointly fitted, would describe no real animal).
  ab  <- data.frame(a = c(0.005, 0.010, 0.050), b = c(3.3, 3.0, 2.6))
  out <- .dr_lw_consensus(ab)

  L <- c(5, 20, 50)
  W <- vapply(seq_len(3), function(i) ab$a[i] * L ^ ab$b[i], numeric(3))
  pred <- out$a * L ^ out$b

  expect_true(all(pred >= apply(W, 1, min) & pred <= apply(W, 1, max)))
  expect_false(isTRUE(all.equal(pred, mean(ab$a) * L ^ mean(ab$b))))
  expect_equal(out$n_src, 3L)
})

test_that("no usable study returns NULL", {
  expect_null(.dr_lw_consensus(data.frame(a = numeric(0), b = numeric(0))))
  expect_null(.dr_lw_consensus(data.frame(a = c(NA, -1), b = c(3, 3))))
})

# ---- .dr_lw_from_sealifebase() ---------------------------------------------

test_that("only records on the target's own measured dimension are used", {
  rec <- data.frame(Species = c("Loligo forbesii", "Loligo forbesii"),
                    a = c(0.02, 9.99), b = c(3, 3),
                    Type = c("ML", "TL"))          # TL is not what DATRAS measures
  map <- data.frame(name = "Loligo forbesii", Valid_Aphia = 140271L, dim = "ML")

  out <- .dr_lw_from_sealifebase(rec, map)

  expect_equal(nrow(out), 1L)
  expect_equal(out$a, 0.02)                        # the TL record is ignored
})

test_that("a target with no dimension-matched record is left unresolved", {
  rec <- data.frame(Species = "Cancer pagurus", a = 0.02, b = 3, Type = "CL")
  map <- data.frame(name = "Cancer pagurus", Valid_Aphia = 107276L, dim = "CW")

  out <- .dr_lw_from_sealifebase(rec, map)

  expect_equal(nrow(out), 0L)
  expect_identical(names(out), c("Valid_Aphia", "a", "b"))
})

test_that("several matched studies reduce to one row per Valid_Aphia", {
  rec <- data.frame(Species = rep("Loligo forbesii", 3),
                    a = c(0.005, 0.010, 0.050), b = c(3.3, 3.0, 2.6),
                    Type = "ML")
  map <- data.frame(name = "Loligo forbesii", Valid_Aphia = 140271L, dim = "ML")

  out <- .dr_lw_from_sealifebase(rec, map)

  expect_equal(nrow(out), 1L)
  expect_equal(out$a, .dr_lw_consensus(rec[, c("a", "b")])$a, tolerance = 1e-8)
})

test_that("a name absent from the records yields a zero-row tier, not an error", {
  rec <- data.frame(Species = "Other species", a = 0.02, b = 3, Type = "ML")
  map <- data.frame(name = "Loligo forbesii", Valid_Aphia = 140271L, dim = "ML")

  expect_equal(nrow(.dr_lw_from_sealifebase(rec, map)), 0L)
})
