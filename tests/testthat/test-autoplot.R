# autoplot() on the summaries, and the guard against ggplot2 collecting a lazy
# table. Offline: the summaries are built from the synthetic catch.

catch <- function() .dr_catch(hauls(), species(), source = catch_source())
occ   <- function(...) .dr_occurrence(catch(), ..., conf = 0.95)

built <- function(p) ggplot2::ggplot_build(p)

test_that("one grouping column draws a line with an interval", {
  p <- ggplot2::autoplot(occ(Year))
  expect_s3_class(p, "ggplot")
  expect_no_error(built(p))
  # a ribbon, a line and points, panelled by species
  geoms <- vapply(p@layers, function(l) class(l$geom)[1], character(1))
  expect_true(all(c("GeomRibbon", "GeomLine", "GeomPoint") %in% geoms))
})

test_that("a category on x draws points with an interval, not a line", {
  p <- ggplot2::autoplot(occ(Survey))
  geoms <- vapply(p@layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomPointrange" %in% geoms)
  expect_false("GeomLine" %in% geoms)
})

test_that("two grouping columns draw tiles, fixed 0-1 for a share", {
  p <- ggplot2::autoplot(occ(Year, Survey))
  expect_s3_class(p, "ggplot")
  expect_no_error(built(p))
  geoms <- vapply(p@layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomTile" %in% geoms)
  fill <- p@scales$get_scales("fill")
  expect_equal(fill$get_limits(), c(0, 1))
})

test_that("a haul count is tiles on a plain scale, not 0-1", {
  p <- ggplot2::autoplot(dr_summarise_hauls(hauls(), Year, Survey))
  expect_no_error(built(p))
  expect_false(identical(p@scales$get_scales("fill")$limits, c(0, 1)))
})

test_that("numbers at length draw one line per first grouping column", {
  sp <- species()[species()$latin == "Alpha alpha", ]
  hl <- data.frame(.id = c("h1", "h4"), latin = "Alpha alpha", Valid_Aphia = 1L,
                   length_cm = c(10, 12), n_hour = c(4, 6), stringsAsFactors = FALSE)
  p <- ggplot2::autoplot(.dr_length(hauls(), sp, hl, Year))
  expect_s3_class(p, "ggplot")
  expect_no_error(built(p))
})

test_that("cell columns draw a map, with the other columns as panels", {
  skip_if_not_installed("maps")
  d <- data.frame(.id = paste0("h", 1:4), Year = c(2000L, 2000L, 2001L, 2001L),
                  ShootLongitude = c(1.2, 2.3, 1.4, 2.6), ShootLatitude = c(50.2, 51.1, 50.4, 51.3))
  cat_tbl <- .dr_catch(dr_add_cell(d), species()[1, ],
                       source = data.frame(.id = c("h1", "h3"), Valid_Aphia = 1L,
                                           n_totalnumber = 1, n_totalnumber_hour = 2, n_haul = 1,
                                           w_haul = 1, w_hour = 2))
  p <- ggplot2::autoplot(.dr_occurrence(cat_tbl, cell_lon, cell_lat, Year, conf = 0.95))
  expect_s3_class(p, "ggplot")
  expect_no_error(built(p))
  expect_s3_class(p@coordinates, "CoordQuickmap")
})

test_that("autoplot has no cosmetic arguments", {
  expect_equal(names(formals(autoplot.dr_summary)), c("object", "...", "top"))
  expect_error(ggplot2::autoplot(occ(Year), colour = "red"))
})

test_that("a summary that lost its attributes says how to rebuild it", {
  x <- occ(Year)
  attr(x, "statistic") <- NULL
  expect_error(ggplot2::autoplot(x), "dr_summarise")
})

test_that("ggplot2 will not silently collect a lazy table", {
  skip_if_not_installed("duckdb")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  lz <- dplyr::copy_to(con, data.frame(a = 1:3), "lz")
  expect_error(ggplot2::ggplot(lz, ggplot2::aes(a)), "pull every row")
  # an ordinary data frame is untouched
  expect_no_error(ggplot2::ggplot(data.frame(a = 1:3), ggplot2::aes(a)))
})

test_that("a numeric column beside the cell draws a glyph map, one point per year", {
  skip_if_not_installed("maps")
  d <- data.frame(.id = paste0("h", 1:4), Year = c(2000L, 2000L, 2001L, 2001L),
                  ShootLongitude = c(1.2, 1.3, 1.4, 1.6), ShootLatitude = c(50.2, 50.3, 50.4, 50.1))
  src <- data.frame(.id = c("h1", "h3"), Valid_Aphia = 1L, n_totalnumber = 1,
                    n_totalnumber_hour = 2, n_haul = 1, w_haul = 1, w_hour = 2)
  ct <- .dr_catch(dr_add_cell(d), species()[1, ], source = src)
  p <- ggplot2::autoplot(.dr_occurrence(ct, cell_lon, cell_lat, Year, conf = 0.95))
  b <- ggplot2::ggplot_build(p)
  geoms <- vapply(p@layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomPoint" %in% geoms)
  expect_false("GeomTile" %in% geoms)
  # the latest year is drawn apart from the earlier ones
  expect_setequal(unique(b@data[[2]]$colour), c("#377EB8", "#E41A1C"))
})

test_that("`top` sets the shared glyph scale and caps what lies above it", {
  skip_if_not_installed("maps")
  d <- data.frame(.id = paste0("h", 1:4), Year = c(2000L, 2000L, 2001L, 2001L),
                  ShootLongitude = c(1.2, 1.3, 1.4, 1.6), ShootLatitude = c(50.2, 50.3, 50.4, 50.1))
  src <- data.frame(.id = c("h1", "h3"), Valid_Aphia = 1L, n_totalnumber = 1,
                    n_totalnumber_hour = c(2, 100), n_haul = 1, w_haul = 1, w_hour = 2)
  s <- .dr_cpue(.dr_catch(dr_add_cell(d), species()[1, ], source = src), cell_lon, cell_lat, Year, conf = 0.95)
  tops <- function(f) {
    p <- ggplot2::autoplot(s, top = f)
    ggplot2::ggplot_build(p)@data[[2]]$y
  }
  # the small value sits higher on a short scale, and the large one is capped at its top
  expect_gt(min(tops(function(y) 10)), min(tops(max)))
  expect_equal(max(tops(function(y) 10)), max(tops(max)))
  expect_error(ggplot2::autoplot(s, top = 0.95), "top")
})
