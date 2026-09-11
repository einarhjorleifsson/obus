# dr_get() is dr_con() + collect(), so it cannot be tested without reaching the
# published archive. Same skip convention as test-published-schema.R's online
# half. Kept deliberately small: the filters are pushed down by dbplyr, which
# has its own tests, so what is checked here is dr_get()'s own behaviour --
# that it collects, that each filter reaches the right column, and that asking
# for a filter a table cannot honour is an error rather than a silent no-op.

test_that("dr_get() collects, and each filter is applied", {
  skip_if_offline()
  hh <- tryCatch(dr_get("HH", survey = "NS-IBTS", years = 2022, quarters = 1),
                 error = function(e) NULL)
  skip_if(is.null(hh), "could not reach the published HH")

  expect_s3_class(hh, "data.frame")
  expect_false(inherits(hh, "tbl_lazy"))
  expect_identical(unique(as.character(hh$Survey)), "NS-IBTS")
  expect_identical(unique(as.integer(hh$Year)), 2022L)
  expect_identical(unique(as.integer(hh$Quarter)), 1L)
})

test_that("a filter takes a vector, not just one value", {
  skip_if_offline()
  hh <- tryCatch(dr_get("HH", survey = "NS-IBTS", years = 2022,
                        quarters = c(1L, 3L)),
                 error = function(e) NULL)
  skip_if(is.null(hh), "could not reach the published HH")
  expect_setequal(as.integer(hh$Quarter), c(1L, 3L))
})

test_that("a table with no Survey/Year/Quarter needs no filter", {
  skip_if_offline()
  sp <- tryCatch(dr_get("species"), error = function(e) NULL)
  skip_if(is.null(sp), "could not reach the published species")
  expect_s3_class(sp, "data.frame")
  expect_true("Valid_Aphia" %in% names(sp))
})

test_that("asking a table for a filter it cannot honour is an error", {
  # Silently ignoring it would hand back the whole table looking filtered.
  skip_if_offline()
  reachable <- tryCatch({ colnames(dr_con("species")); TRUE },
                        error = function(e) FALSE)
  skip_if(!reachable, "could not reach the published species")

  expect_error(dr_get("species", years = 2022), "has no Year column")
  expect_error(dr_get("length_weight", survey = "NS-IBTS"), "has no Survey column")
  expect_error(dr_get("hl_flag", years = 2022, quarters = 1),
               "has no Year/Quarter columns")
})

test_that("an invalid table name is dr_con()'s error, not a new one", {
  expect_error(dr_get("NoSuchTable"), "Invalid table")
})
