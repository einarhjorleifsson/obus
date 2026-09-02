# Tests for .dr_coalesce_with_provenance(): the ranked-cascade collapse.
# Synthetic and offline; the lazy case registers a small DuckDB table.

test_that("the first tier with a value wins, and stamps its own label", {
  base <- data.frame(Valid_Aphia = 1:4)
  out <- .dr_coalesce_with_provenance(
    base,
    tiers = list(
      list(label = "fine",   data = data.frame(Valid_Aphia = 1L,   a = 10, b = 1)),
      list(label = "medium", data = data.frame(Valid_Aphia = 1:2,  a = c(20, 20), b = c(2, 2))),
      list(label = "coarse", data = data.frame(Valid_Aphia = 1:3,  a = 30, b = 3))
    ),
    value_cols = c("a", "b"), source_col = "src")

  expect_equal(out$a, c(10, 20, 30, NA))
  expect_equal(out$b, c(1, 2, 3, NA))
  expect_equal(out$src, c("fine", "medium", "coarse", "unresolved"))
})

test_that("a tier row with an NA value declines rather than answering", {
  base <- data.frame(Valid_Aphia = 1L)
  out <- .dr_coalesce_with_provenance(
    base,
    tiers = list(
      list(label = "fine",   data = data.frame(Valid_Aphia = 1L, a = NA_real_, b = NA_real_)),
      list(label = "coarse", data = data.frame(Valid_Aphia = 1L, a = 5, b = 3))
    ),
    value_cols = c("a", "b"), source_col = "src")

  expect_equal(out$a, 5)
  expect_equal(out$src, "coarse")
})

test_that("value_cols come from ONE tier -- a and b are never mixed", {
  # `a` and `b` are jointly fitted, so a partially-populated tier must be
  # skipped entirely rather than contributing its non-NA half.
  base <- data.frame(Valid_Aphia = 1L)
  out <- .dr_coalesce_with_provenance(
    base,
    tiers = list(
      list(label = "half",  data = data.frame(Valid_Aphia = 1L, a = NA_real_, b = 99)),
      list(label = "whole", data = data.frame(Valid_Aphia = 1L, a = 5, b = 3))
    ),
    value_cols = c("a", "b"), source_col = "src")

  expect_equal(out$src, "whole")
  expect_equal(out$a, 5)
  expect_equal(out$b, 3)   # NOT 99
})

test_that("an empty or absent tier is skipped without error", {
  base <- data.frame(Valid_Aphia = 1L)
  out <- .dr_coalesce_with_provenance(
    base,
    tiers = list(
      list(label = "empty", data = data.frame(Valid_Aphia = integer(0), a = numeric(0), b = numeric(0))),
      list(label = "null",  data = NULL),
      list(label = "real",  data = data.frame(Valid_Aphia = 1L, a = 5, b = 3))
    ),
    value_cols = c("a", "b"), source_col = "src")

  expect_equal(out$src, "real")
})

test_that("a tier missing a value column is an error, not a silent skip", {
  expect_error(
    .dr_coalesce_with_provenance(
      data.frame(Valid_Aphia = 1L),
      tiers = list(list(label = "bad", data = data.frame(Valid_Aphia = 1L, a = 5))),
      value_cols = c("a", "b")),
    "missing value column"
  )
})

test_that("multi-column keys do not collide across different tuples", {
  base <- data.frame(Survey = c("A", "AB"), Valid_Aphia = c(11L, 1L))
  out <- .dr_coalesce_with_provenance(
    base,
    tiers = list(list(label = "t", data = data.frame(Survey = "A", Valid_Aphia = 11L, a = 7, b = 3))),
    value_cols = c("a", "b"), keys = c("Survey", "Valid_Aphia"), source_col = "src")

  expect_equal(out$src, c("t", "unresolved"))
})

test_that("the lazy path reproduces the eager result exactly", {
  skip_if_not_installed("duckdbfs")

  base <- data.frame(Valid_Aphia = 1:4)
  tiers <- list(
    list(label = "fine",   data = data.frame(Valid_Aphia = 1L,  a = 10, b = 1)),
    list(label = "medium", data = data.frame(Valid_Aphia = 1:2, a = c(20, 20), b = c(2, 2))),
    list(label = "coarse", data = data.frame(Valid_Aphia = 1:3, a = 30, b = 3))
  )

  eager <- .dr_coalesce_with_provenance(base, tiers, c("a", "b"), source_col = "src")

  lazy_base <- dplyr::copy_to(duckdbfs::cached_connection(), base,
                              "test_resolve_base", overwrite = TRUE)
  lazy <- .dr_coalesce_with_provenance(lazy_base, tiers, c("a", "b"),
                                       keys = "Valid_Aphia", source_col = "src") |>
    dplyr::collect() |>
    dplyr::arrange(Valid_Aphia) |>
    as.data.frame()

  expect_equal(lazy$a,   eager$a)
  expect_equal(lazy$b,   eager$b)
  expect_equal(lazy$src, eager$src)
})

test_that("the lazy path also keeps a and b atomic within a tier", {
  # The eager path gates every value column on the FIRST one; the lazy path used
  # to gate each column on itself, which could take `b` from a tier that had
  # declined to supply `a`. Same fixture as the eager test above.
  skip_if_not_installed("duckdbfs")

  base <- data.frame(Valid_Aphia = 1L)
  lazy_base <- dplyr::copy_to(duckdbfs::cached_connection(), base,
                              "test_resolve_atomic", overwrite = TRUE)
  out <- .dr_coalesce_with_provenance(
    lazy_base,
    tiers = list(
      list(label = "half",  data = data.frame(Valid_Aphia = 1L, a = NA_real_, b = 99)),
      list(label = "whole", data = data.frame(Valid_Aphia = 1L, a = 5, b = 3))
    ),
    value_cols = c("a", "b"), keys = "Valid_Aphia", source_col = "src") |>
    dplyr::collect()

  expect_equal(out$src, "whole")
  expect_equal(out$a, 5)
  expect_equal(out$b, 3)
})
