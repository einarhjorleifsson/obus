# Deprecated names ----------------------------------------------------------------
#
# Renamed or demoted in 2026.10. Each keeps working for one release, warns
# once per session, and delegates to its replacement. See ?lifecycle.

#' Deprecated functions
#'
#' `r lifecycle::badge("deprecated")`
#'
#' These were renamed to follow the tidyverse naming rules (`snake_case`) or
#' removed from the exported surface because the book and its sister projects
#' barely used them.
#'
#' * `dr_HL_length()`, `dr_HL_summary()`, `dr_HL_collapse()` are now
#'   [dr_hl_length()], [dr_hl_summary()] and [dr_hl_collapse()].
#' * `dr_add_length_mm()`: use `dr_add_length_cm()` and multiply by 10, or
#'   take `length_mm` from [dr_hl_length()].
#' * `dr_add_n_and_cpue()`: [dr_hl_length()] and [dr_hl_summary()] return
#'   `n_haul` and `n_hour`.
#' * `dr_join_species()`: [dr_hl_length()] and [dr_hl_summary()] attach the
#'   names; otherwise `dplyr::left_join()` on `dr_con("species")`.
#'
#' @param hh,hl,species,haulval,data,collapse,check,d,x See the replacement.
#' @name obus-deprecated
#' @keywords internal
NULL

#' @rdname obus-deprecated
#' @export
dr_HL_length <- function(hh, hl, species = NULL, haulval = NULL) {
  lifecycle::deprecate_warn("2026.10", "dr_HL_length()", "dr_hl_length()")
  dr_hl_length(hh, hl, species, haulval)
}

#' @rdname obus-deprecated
#' @export
dr_HL_summary <- function(hh, hl, species = NULL, haulval = NULL) {
  lifecycle::deprecate_warn("2026.10", "dr_HL_summary()", "dr_hl_summary()")
  dr_hl_summary(hh, hl, species, haulval)
}

#' @rdname obus-deprecated
#' @export
dr_HL_collapse <- function(data, collapse, check = TRUE) {
  lifecycle::deprecate_warn("2026.10", "dr_HL_collapse()", "dr_hl_collapse()")
  dr_hl_collapse(data, collapse, check)
}

#' @rdname obus-deprecated
#' @export
dr_add_length_mm <- function(d) {
  lifecycle::deprecate_warn(
    "2026.10", "dr_add_length_mm()", "dr_hl_length()",
    details = "`length_mm` is a column of `dr_hl_length()`; or multiply `dr_add_length_cm()`'s `length_cm` by 10.")
  .dr_add_length_mm(d)
}

#' @rdname obus-deprecated
#' @export
dr_add_n_and_cpue <- function(d) {
  lifecycle::deprecate_warn("2026.10", "dr_add_n_and_cpue()", "dr_hl_length()")
  .dr_add_n_and_cpue(d)
}

#' @rdname obus-deprecated
#' @export
dr_join_species <- function(x, species = NULL) {
  lifecycle::deprecate_warn(
    "2026.10", "dr_join_species()", "dr_hl_summary()",
    details = "Or `dplyr::left_join()` on `dr_con(\"species\")`.")
  .dr_join_species(x, species)
}
