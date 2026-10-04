# The four summaries. Offline: the statistics are tested on the synthetic catch
# of helper-catch.R; an online block compares them with a hand-built route
# through the published tables.

catch <- function() .dr_catch(hauls(), species(), source = catch_source())

# Alpha: 2000 -> h1, h2 caught of 3 hauls; 2001 -> h4 of 3.
# Beta : 2000 -> none of 3;                2001 -> h5 of 3.

test_that("occurrence counts hauls and hauls with the species, per group", {
  x <- .dr_occurrence(catch(), Year, conf = 0.95)
  a <- x[x$latin == "Alpha alpha", ]
  expect_equal(a$n_hauls, c(3, 3))
  expect_equal(a$n_present, c(2, 1))
  expect_equal(a$p, c(2 / 3, 1 / 3))
  b <- x[x$latin == "Beta beta", ]
  expect_equal(b$n_present, c(0, 1))
  expect_equal(b$p, c(0, 1 / 3))
})

test_that("a share of zero keeps a sensible interval", {
  x <- .dr_occurrence(catch(), Year, conf = 0.95)
  b <- x[x$latin == "Beta beta" & x$Year == 2000, ]
  expect_equal(b$lower, 0)
  expect_gt(b$upper, 0)
  expect_true(all(x$lower <= x$p & x$p <= x$upper))
})

test_that("the Wilson interval matches its textbook values", {
  w <- .dr_wilson(c(0, 5), c(10, 10), 0.95)
  expect_equal(w$lower, c(0, 0.2366), tolerance = 1e-3)
  expect_equal(w$upper, c(0.2775, 0.7634), tolerance = 1e-3)
  # a wider level gives a wider interval
  expect_gt(.dr_wilson(5, 10, 0.99)$upper, .dr_wilson(5, 10, 0.90)$upper)
})

test_that("cpue is the mean per haul, zeros included, over hauls with a known rate", {
  x <- .dr_cpue(catch(), Year, conf = 0.95)
  a <- x[x$latin == "Alpha alpha", ]
  # 2000: rates 10, NA, 0 -> the unknown haul is left out, not counted as zero
  expect_equal(a$cpue[a$Year == 2000], 5)
  expect_equal(a$n_hauls[a$Year == 2000], 3)
  # 2001: 8, 0, 0
  expect_equal(a$cpue[a$Year == 2001], 8 / 3)
  expect_true(all(x$lower >= 0))
  expect_true(all(x$lower <= x$cpue & x$cpue <= x$upper, na.rm = TRUE))
})

test_that("a species never caught has cpue 0 and no spread", {
  x <- .dr_cpue(catch(), Year, conf = 0.95)
  b <- x[x$latin == "Beta beta" & x$Year == 2000, ]
  expect_equal(b$cpue, 0)
  expect_equal(c(b$lower, b$upper), c(0, 0))
})

test_that("the grouping columns come back in the order they were written", {
  x <- .dr_occurrence(catch(), Survey, Year, conf = 0.95)
  expect_equal(attr(x, "by"), c("Survey", "Year"))
  expect_equal(names(x)[1:2], c("Survey", "Year"))
  expect_equal(names(x), c("Survey", "Year", "latin", "n_hauls", "n_present", "p",
                           "lower", "upper"))
})

test_that("a grouping expression works, as in dplyr::count()", {
  x <- .dr_occurrence(catch(), period = Year >= 2001, conf = 0.95)
  expect_equal(attr(x, "by"), "period")
  expect_equal(sort(unique(x$period)), c(FALSE, TRUE))
})

test_that("no grouping column gives one row per species", {
  x <- .dr_occurrence(catch(), conf = 0.95)
  expect_equal(nrow(x), 2)
  expect_equal(attr(x, "by"), character())
})

test_that("a summary carries its class, statistic and grouping", {
  x <- .dr_occurrence(catch(), Year, conf = 0.95)
  expect_s3_class(x, c("dr_summary_occurrence", "dr_summary", "tbl_df"))
  expect_equal(attr(x, "statistic"), "occurrence")
  expect_equal(attr(.dr_cpue(catch(), Year, conf = 0.95), "statistic"), "cpue")
})

test_that("hauls are counted once each, whatever the table has rows for", {
  x <- dr_summarise_hauls(hauls(), Year)
  expect_equal(x$n_hauls, c(3, 3))
  # a hauls x species table must not double the count
  y <- dr_summarise_hauls(catch(), Year)
  expect_equal(y$n_hauls, c(3, 3))
  expect_equal(attr(x, "statistic"), "hauls")
})

test_that("conf is checked", {
  expect_error(dr_summarise_occurrence(hauls(), "Alpha alpha", conf = 1.5), "conf")
  expect_error(dr_summarise_cpue(hauls(), "Alpha alpha", conf = 0), "conf")
  expect_error(dr_summarise_hauls(data.frame(x = 1)), "\\.id")
})

hl_length <- function() {
  data.frame(
    .id = c("h1", "h1", "h4", "h5"), latin = c("Alpha alpha", "Alpha alpha", "Alpha alpha", "Beta beta"),
    Valid_Aphia = c(1L, 1L, 1L, 2L),
    length_cm = c(10.0, 10.5, 10.0, 20.0), n_hour = c(4, 2, 6, 9),
    stringsAsFactors = FALSE
  )
}

test_that("numbers at length merge fine classes to whole centimetres and divide by hauls", {
  sp <- species()[species()$latin == "Alpha alpha", ]
  x <- .dr_length(hauls(), sp, hl_length(), Year)
  # 2000: 10.0 and 10.5 both fall in the 10 cm class: (4 + 2) / 3 hauls
  expect_equal(x$length_cm, c(10, 10))
  expect_equal(x$n_hour, c(2, 2))
  expect_equal(x$n_hauls, c(3, 3))
  expect_equal(attr(x, "statistic"), "length")
})

test_that("lazy and in-memory hauls give the same numbers at length", {
  skip_if_not_installed("duckdb")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  sp <- species()[species()$latin == "Alpha alpha", ]
  lz <- .dr_length(dplyr::copy_to(con, hauls(), "hauls"), sp,
                   dplyr::copy_to(con, hl_length(), "hl"), Year)
  eg <- .dr_length(hauls(), sp, hl_length(), Year)
  expect_equal(as.data.frame(lz), as.data.frame(eg), ignore_attr = TRUE)
})

test_that("lazy and in-memory catch give the same occurrence and cpue", {
  skip_if_not_installed("duckdb")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  lz_catch <- .dr_catch(dplyr::copy_to(con, hauls(), "hauls"),
                        dplyr::copy_to(con, species(), "species"),
                        source = dplyr::copy_to(con, catch_source(), "catch"))
  expect_equal(as.data.frame(.dr_occurrence(lz_catch, Year, conf = 0.95)),
               as.data.frame(.dr_occurrence(catch(), Year, conf = 0.95)),
               ignore_attr = TRUE)
  expect_equal(as.data.frame(.dr_cpue(lz_catch, Year, conf = 0.95)),
               as.data.frame(.dr_cpue(catch(), Year, conf = 0.95)),
               ignore_attr = TRUE)
})

# ---- against the published tables ------------------------------------------------------
test_that("occurrence and cpue agree with a hand-built route through HL_summary", {
  skip_on_cran()
  skip_if_offline()

  hh <- dr_con("HH") |>
    dplyr::filter(Survey == "NS-IBTS", Quarter == 1L, Year %in% 2018:2020,
                  HaulValidity != "I")
  aphia <- dplyr::pull(dplyr::filter(dr_con("species"), latin == "Raja clavata"), Valid_Aphia)

  # by hand: hauls with a record, and the hourly rate summed over a haul's records
  per_haul <- dr_con("HL_summary") |>
    dplyr::filter(Valid_Aphia == !!aphia) |>
    dplyr::group_by(.id) |>
    dplyr::summarise(rate = sum(n_totalnumber_hour, na.rm = TRUE), .groups = "drop")
  by_hand <- hh |>
    dplyr::left_join(per_haul, by = ".id") |>
    dplyr::group_by(Year) |>
    dplyr::summarise(n_hauls = dplyr::n(),
                     n_present = sum(as.integer(!is.na(rate)), na.rm = TRUE),
                     mean_rate = mean(dplyr::coalesce(rate, 0), na.rm = TRUE)) |>
    dplyr::collect() |>
    dplyr::arrange(Year)

  occ <- dr_summarise_occurrence(hh, "Raja clavata", Year)
  expect_equal(occ$n_hauls, by_hand$n_hauls)
  expect_equal(occ$n_present, by_hand$n_present)

  cpue <- dr_summarise_cpue(hh, "Raja clavata", Year)
  expect_equal(cpue$cpue, by_hand$mean_rate, tolerance = 1e-8)

  # the same call on hauls already in memory gives the same numbers
  occ_e <- dr_summarise_occurrence(dplyr::collect(hh), "Raja clavata", Year)
  expect_equal(as.data.frame(occ_e), as.data.frame(occ), ignore_attr = TRUE)
})
