# dr_add_catch() and its engine, .dr_catch(). Offline: the catch source and the
# species lookup are injected as synthetic tables, the way dr_hl_length() is
# tested, so nothing here needs the server.

out <- function(zeros = "hauls") {
  .dr_catch(hauls(), species(), zeros, source = catch_source()) |>
    dplyr::arrange(.id, latin)
}

test_that("every haul is crossed with every species", {
  x <- out()
  expect_equal(nrow(x), 6 * 2)
  expect_setequal(x$latin, c("Alpha alpha", "Beta beta"))
  expect_true(all(c("Valid_Aphia", "latin", "present", .DR_CATCH_MEASURES) %in% names(x)))
  expect_true(all(names(hauls()) %in% names(x)))
})

test_that("a species with no record is a zero, and says so in `present`", {
  x <- out()
  a <- x[x$.id == "h3" & x$latin == "Alpha alpha", ]
  expect_false(a$present)
  expect_equal(a$n_totalnumber, 0)
  expect_equal(a$n_totalnumber_hour, 0)
  expect_equal(a$w_haul, 0)

  hit <- x[x$.id == "h4" & x$latin == "Alpha alpha", ]
  expect_true(hit$present)
  expect_equal(hit$n_totalnumber, 4)
})

test_that("several records in a haul are summed, not dropped", {
  x <- out()
  h1 <- x[x$.id == "h1" & x$latin == "Alpha alpha", ]
  expect_equal(h1$n_totalnumber, 5)
  expect_equal(h1$w_haul, 50)
})

test_that("a record whose value is missing stays missing, it is not a zero", {
  x <- out()
  h2 <- x[x$.id == "h2" & x$latin == "Alpha alpha", ]
  expect_true(h2$present)
  expect_true(is.na(h2$n_totalnumber))
  expect_true(is.na(h2$w_hour))
})

test_that("zeros = 'reported' adds a zero only where the species was reported", {
  all <- out("hauls")
  rep <- out("reported")
  # Beta was reported only in 2001, so its 2000 hauls disappear
  expect_equal(sum(rep$latin == "Beta beta"), 3)
  expect_true(all(rep$Year[rep$latin == "Beta beta"] == 2001L))
  # Alpha was reported in both years, so it keeps every haul
  expect_equal(sum(rep$latin == "Alpha alpha"), 6)
  expect_lt(nrow(rep), nrow(all))
})

test_that("lazy and in-memory hauls give the same table", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))

  lz <- .dr_catch(dplyr::copy_to(con, hauls(), "hauls"),
                  dplyr::copy_to(con, species(), "species"), "hauls",
                  source = dplyr::copy_to(con, catch_source(), "catch"))
  expect_s3_class(lz, "tbl_lazy")

  key <- function(d) dplyr::arrange(as.data.frame(d), .id, latin)
  expect_equal(key(dplyr::collect(lz)), key(out()), ignore_attr = TRUE)

  lz_rep <- .dr_catch(dplyr::copy_to(con, hauls(), "hauls2"),
                      dplyr::copy_to(con, species(), "species2"), "reported",
                      source = dplyr::copy_to(con, catch_source(), "catch2"))
  expect_equal(key(dplyr::collect(lz_rep)), key(out("reported")), ignore_attr = TRUE)
})

test_that("dr_add_catch refuses a catch table and a bad `zeros`", {
  expect_error(dr_add_catch(hauls(), "Alpha alpha", zeros = "everything"))
  expect_error(dr_add_catch(data.frame(x = 1), "Alpha alpha"), "\\.id")
  expect_error(dr_add_catch(dplyr::mutate(hauls(), Valid_Aphia = 1L), "Alpha alpha"),
               "one row per haul")
  expect_error(dr_add_catch(hauls()[, ".id", drop = FALSE], "Alpha alpha",
                            zeros = "reported"), "Survey")
})

test_that("an unknown species is named, and numeric Aphia codes are accepted", {
  skip_on_cran()
  skip_if_offline()
  expect_error(.dr_species("Raja clavatta"), "Raja clavatta")
  lookup <- dplyr::collect(.dr_species(c("Raja clavata", "Gadus morhua")))
  expect_setequal(lookup$latin, c("Raja clavata", "Gadus morhua"))
  by_code <- dplyr::collect(.dr_species(lookup$Valid_Aphia))
  expect_setequal(by_code$latin, lookup$latin)
})
