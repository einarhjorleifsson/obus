# dr_add_cell(): grading positions to a grid.

test_that("positions are graded to the centre of their cell", {
  d <- data.frame(ShootLongitude = c(-5.9, 2.2, 0.01), ShootLatitude = c(55.1, 57.4, 49.99))
  x <- dr_add_cell(d)
  expect_equal(x$cell_lon, c(-5.5, 2.5, 0.5))
  expect_equal(x$cell_lat, c(55.25, 57.25, 49.75))
})

test_that("a position exactly on a cell edge goes to the cell it opens", {
  # -5.9 / 0.1 is -58.99999999999999 in floating point, and `%/%` puts it in
  # the cell to the west; the edge belongs to [-5.9, -5.8)
  d <- data.frame(ShootLongitude = c(-5.9, -5.85, -6.0, 0.3, 0.1),
                  ShootLatitude  = c(55.1, 55.2, 55.0, 55.3, 55.35))
  x <- dr_add_cell(d, size = c(0.1, 0.05))
  expect_equal(x$cell_lon, c(-5.85, -5.85, -5.95, 0.35, 0.15))
  expect_equal(x$cell_lat, c(55.125, 55.225, 55.025, 55.325, 55.375))
})

test_that("one size is used for both axes, and bad sizes are refused", {
  d <- data.frame(ShootLongitude = 0.2, ShootLatitude = 0.2)
  expect_equal(dr_add_cell(d, size = 1)$cell_lon, 0.5)
  expect_equal(dr_add_cell(d, size = 1)$cell_lat, 0.5)
  expect_error(dr_add_cell(d, size = c(1, 2, 3)), "size")
  expect_error(dr_add_cell(d, size = 0), "size")
  expect_error(dr_add_cell(d, size = "a"), "size")
  expect_error(dr_add_cell(data.frame(x = 1)), "ShootLongitude")
})

test_that("a haul with no position has no cell, it is not placed anywhere", {
  d <- data.frame(ShootLongitude = c(1.2, NA), ShootLatitude = c(50.1, 50.1))
  x <- dr_add_cell(d)
  expect_true(is.na(x$cell_lon[2]))
  expect_false(is.na(x$cell_lon[1]))
})

test_that("lazy and in-memory input agree", {
  skip_if_not_installed("duckdb")
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  d <- data.frame(ShootLongitude = c(-5.9, -5.85, 2.2, NA),
                  ShootLatitude  = c(55.1, 55.2, 57.4, 50))
  lz <- dplyr::collect(dr_add_cell(dplyr::copy_to(con, d, "d"), size = c(0.1, 0.05)))
  expect_equal(as.data.frame(lz), dr_add_cell(d, size = c(0.1, 0.05)), ignore_attr = TRUE)
})
