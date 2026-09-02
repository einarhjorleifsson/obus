# Tests for dr_compare_length_weight(): the cross-check of modelled catch weight
# against the independently measured one. Synthetic and offline -- hand-built
# HL_length / HL_summary shaped frames, `lw` always supplied.

.cmp_lw <- function() {
  data.frame(Valid_Aphia = c(1L, 2L), a = c(0.01, 0.01), b = c(3, 3),
             lw_source = c("ca_fit", "default_constant"))
}

# One haul, one species, two length classes -- 1 cm bins, so the midpoints the
# prediction actually uses are 10.5 and 20.5.
.cmp_len <- function(Valid_Aphia = 1L, n_haul = c(2, 1)) {
  data.frame(.id = "H1", Valid_Aphia = Valid_Aphia,
             length_cm = c(10, 20), accuracy = 1, n_haul = n_haul)
}

.modelled <- function(n_haul = c(2, 1)) {
  sum(n_haul * 0.01 * c(10.5, 20.5) ^ 3)
}

test_that("ratio is modelled / measured, on bin midpoints", {
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = .modelled())
  out  <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw(), flag = TRUE)

  expect_equal(nrow(out), 1L)
  expect_equal(out$w_modelled, .modelled())
  expect_equal(out$ratio, 1)
  expect_true(out$.within_tol)
  expect_equal(out$lw_source, "ca_fit")
})

test_that("a group outside the tolerance band is reported, not corrected", {
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = .modelled() / 2)
  out  <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw(), flag = TRUE)

  expect_equal(out$ratio, 2)
  expect_false(out$.within_tol)
  expect_equal(out$w_measured, .modelled() / 2)   # untouched
})

test_that("tol widens and narrows the band", {
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = .modelled() / 1.2)
  narrow <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw(), tol = 0.1, flag = TRUE)
  wide   <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw(), tol = 0.5, flag = TRUE)

  expect_false(narrow$.within_tol)
  expect_true(wide$.within_tol)
})

test_that("a SpeciesValidity-split group is excluded, not summed", {
  # HL_summary is grained by .id x Valid_Aphia x SpeciesValidity, and a split
  # group often repeats one species-level total rather than partitioning it.
  # Summing would double-count; SpeciesCategoryWeight has no arithmetic check
  # that can tell a repeat from a real split, so the group is set aside.
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L,
                     SpeciesValidity = c("1", "4"),
                     w_haul = c(.modelled(), .modelled()))

  flagged <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw(), flag = TRUE)
  summary <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw())

  expect_equal(nrow(flagged), 0L)
  expect_equal(summary$n_compared, 0L)
  expect_equal(summary$n_ambiguous_excluded, 1L)
})

test_that("unsplit groups survive alongside an excluded split one", {
  len <- rbind(.cmp_len(1L), .cmp_len(2L))
  smry <- data.frame(
    .id = "H1", Valid_Aphia = c(1L, 1L, 2L),
    SpeciesValidity = c("1", "4", "1"),
    w_haul = c(.modelled(), .modelled(), .modelled()))

  out <- dr_compare_length_weight(len, smry, .cmp_lw())

  expect_equal(out$n_compared, 1L)              # species 2 only
  expect_equal(out$n_ambiguous_excluded, 1L)    # species 1 set aside
  expect_equal(out$n_outside, 0L)
})

test_that("the summary reports the median ratio and the failure count", {
  len <- rbind(.cmp_len(1L), .cmp_len(2L))
  smry <- data.frame(.id = "H1", Valid_Aphia = c(1L, 2L),
                     w_haul = c(.modelled(), .modelled() / 4))

  out <- dr_compare_length_weight(len, smry, .cmp_lw())

  expect_equal(out$n_compared, 2L)
  expect_equal(out$n_outside, 1L)               # the 4x one
  expect_equal(out$pct_outside, 50)
  expect_equal(out$median_ratio, stats::median(c(1, 4)))
  expect_equal(out$tol, 0.25)
})

test_that("species with no coefficient drop out rather than compare as zero", {
  lw   <- data.frame(Valid_Aphia = 1L, a = NA_real_, b = NA_real_,
                     lw_source = "unresolved")
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = 500)

  out <- dr_compare_length_weight(.cmp_len(), smry, lw)
  expect_equal(out$n_compared, 0L)
  expect_true(is.na(out$median_ratio))
})

test_that("no overlap between the tables gives an empty comparison, not an error", {
  smry <- data.frame(.id = "H2", Valid_Aphia = 9L, w_haul = 500)
  out  <- dr_compare_length_weight(.cmp_len(), smry, .cmp_lw())

  expect_equal(out$n_compared, 0L)
  expect_true(is.na(out$pct_outside))
})

test_that("missing required columns raise an informative error", {
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = 100)
  expect_error(
    dr_compare_length_weight(dplyr::select(.cmp_len(), -accuracy), smry, .cmp_lw()),
    "accuracy")
  expect_error(
    dr_compare_length_weight(.cmp_len(), dplyr::select(smry, -w_haul), .cmp_lw()),
    "w_haul")
})

test_that("DuckDB lazy inputs give the same answer as eager ones", {
  skip_if_not_installed("duckdbfs")

  con  <- duckdbfs::cached_connection()
  len  <- .cmp_len()
  smry <- data.frame(.id = "H1", Valid_Aphia = 1L, w_haul = .modelled())

  lazy_len  <- dplyr::copy_to(con, len,  "test_cmp_len",  overwrite = TRUE)
  lazy_smry <- dplyr::copy_to(con, smry, "test_cmp_smry", overwrite = TRUE)

  eager <- dr_compare_length_weight(len, smry, .cmp_lw())
  lazy  <- dr_compare_length_weight(lazy_len, lazy_smry, .cmp_lw())

  expect_equal(lazy$n_compared, eager$n_compared)
  expect_equal(lazy$median_ratio, eager$median_ratio, tolerance = 1e-8)
})
