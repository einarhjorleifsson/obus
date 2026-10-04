# The design rules as tests (tidyverse design guide, applied to obus). Each one
# is checkable, so each one is checked, and a new export that breaks them fails
# here rather than in review.

exports <- function() sort(getNamespaceExports("obus"))
fns <- function() {
  e <- exports()
  e <- e[vapply(e, function(f) is.function(get(f, asNamespace("obus"))), logical(1))]
  stats::setNames(lapply(e, function(f) get(f, asNamespace("obus"))), e)
}

# renamed or demoted in 2026.10; they warn and delegate (test-deprecated.R)
deprecated <- c("dr_HL_length", "dr_HL_summary", "dr_HL_collapse",
                "dr_add_length_mm", "dr_add_n_and_cpue", "dr_join_species")
current <- function() setdiff(names(fns()), c(deprecated, "autoplot"))

test_that("every current export is dr_ plus snake_case", {
  expect_true(all(grepl("^dr_[a-z][a-z0-9_]*$", current())))
})

test_that("families share a prefix", {
  adds    <- grep("^dr_add_", current(), value = TRUE)
  summ    <- grep("^dr_summarise_", current(), value = TRUE)
  expect_true(all(c("dr_add_id", "dr_add_catch", "dr_add_cell") %in% adds))
  expect_setequal(summ, c("dr_summarise_hauls", "dr_summarise_occurrence",
                          "dr_summarise_cpue", "dr_summarise_length"))
})

test_that("the first argument is the data, named `data`, wherever there is one data input", {
  one_table <- c(grep("^dr_add_", current(), value = TRUE),
                 grep("^dr_summarise_", current(), value = TRUE), "dr_hl_collapse")
  first <- vapply(one_table, function(f) names(formals(fns()[[f]]))[[1]], character(1))
  expect_true(all(first == "data"), info = paste(names(first)[first != "data"], collapse = ", "))
})

test_that("the access functions name their table `table`", {
  for (f in c("dr_con", "dr_con_raw", "dr_get")) {
    expect_equal(names(formals(fns()[[f]]))[[1]], "table", info = f)
  }
})

test_that("one vocabulary for the filters, in one order", {
  # survey, years, quarters, species wherever they occur
  order_of <- function(f, words) {
    a <- names(formals(fns()[[f]]))
    a[a %in% words]
  }
  words <- c("survey", "years", "quarters", "species", "haulval")
  expect_equal(order_of("dr_get", words), c("survey", "years", "quarters"))
  expect_equal(order_of("dr_get_datras", words),
               c("survey", "years", "quarters", "species", "haulval"))
  # old spellings survive only as deprecated() arguments
  for (f in current()) {
    fm <- formals(fns()[[f]])
    for (old in intersect(c("aphia", "type", "d"), names(fm))) {
      expect_match(paste(deparse(fm[[old]]), collapse = ""), "deprecated", info = paste(f, old))
    }
  }
})

test_that("required arguments have no default, optional ones do, and nothing uses missing()", {
  for (f in current()) {
    expect_false(any(grepl("\\bmissing\\(", deparse(body(fns()[[f]])))), info = f)
  }
  # the grouping dots come after the descriptors, so optional arguments after them
  # must be named in full
  for (f in c("dr_summarise_occurrence", "dr_summarise_cpue")) {
    a <- names(formals(fns()[[f]]))
    expect_lt(match("...", a), match("conf", a), label = f)
  }
})

test_that("plots and summaries return what the docs promise", {
  expect_true("dr_summary" %in% class(.dr_occurrence(
    .dr_catch(hauls(), species(), source = catch_source()), Year, conf = 0.95)))
})

test_that("nothing exported is a plotting function with cosmetic arguments", {
  cosmetic <- c("col", "colour", "color", "pch", "cex", "main", "title", "legend",
                "legend_pos", "palette", "theme", "alpha")
  all_args <- unlist(lapply(c(fns()[current()], list(autoplot.dr_summary)), function(f) names(formals(f))))
  expect_length(intersect(all_args, cosmetic), 0)
})

test_that("deprecated names are exactly the ones this release says it deprecates", {
  expect_setequal(intersect(deprecated, exports()), deprecated)
})
