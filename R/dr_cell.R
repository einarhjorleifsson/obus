# Grid cells ------------------------------------------------------------------------

#' Add the map cell a haul falls in
#'
#' Grades each haul's shoot position to a regular grid and adds the cell's
#' centre as `cell_lon` and `cell_lat`. Any summary can then be grouped by the
#' two columns, which is all a map of it is; [ggplot2::autoplot()] draws one
#' when it sees them.
#'
#' @details
#' The default `size = c(1, 0.5)` degrees is one ICES statistical rectangle.
#' The cell is `floor(position / size) * size + size / 2`, with the quotient
#' rounded first: a position that sits exactly on a cell edge (`-5.9` with
#' 0.1 degree cells) must not drop into the neighbouring cell through
#' floating-point error, which `x %/% size` does. Hauls with no position get
#' `NA` cells; obus does not impute one.
#'
#' @param data Hauls with `ShootLongitude` and `ShootLatitude`; lazy or in
#'   memory.
#' @param size Cell width in longitude and in latitude, in degrees: one number
#'   (used for both) or two.
#'
#' @return `data` with added `cell_lon` and `cell_lat` columns.
#' @seealso [dr_summarise_occurrence()], [dr_summarise_cpue()]
#' @export
#'
#' @examples
#' data.frame(ShootLongitude = c(-5.9, -5.85, 2.2), ShootLatitude = c(55.1, 55.2, 57.4)) |>
#'   dr_add_cell()
dr_add_cell <- function(data, size = c(1, 0.5)) {
  .dr_require_cols(data, c("ShootLongitude", "ShootLatitude"), "dr_add_cell")
  if (!is.numeric(size) || !length(size) %in% 1:2 || anyNA(size) || any(size <= 0)) {
    cli::cli_abort(c(
      "{.arg size} must be one or two positive numbers, in degrees.",
      "x" = "Got {.val {size}}."))
  }
  dx <- size[[1]]
  dy <- size[[length(size)]]

  dplyr::mutate(
    data,
    cell_lon = floor(round(ShootLongitude / !!dx, 10)) * !!dx + !!dx / 2,
    cell_lat = floor(round(ShootLatitude  / !!dy, 10)) * !!dy + !!dy / 2
  )
}
