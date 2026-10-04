# Summaries of hauls ----------------------------------------------------------------
#
# Four questions the book and its sister projects ask over and over, each as one
# call that returns a plain tibble:
#
#   dr_summarise_hauls()       how many hauls are there?
#   dr_summarise_occurrence()  what share of hauls caught the species?
#   dr_summarise_cpue()        how much per hour, on average?
#   dr_summarise_length()      how many at each length?
#
# The haul table is the denominator in every one: `data` is the hauls you mean,
# and each statistic is "of these hauls". The grouping columns come after the
# species, as in dplyr::count(), and by convention the first is the x-axis, the
# second the y-axis or colour, and the species the panels when it is drawn.
#
# The database does only counts and sums with plain group_by()/summarise();
# intervals and ratios are computed in R on what comes back, so lazy and
# in-memory input give identical numbers by construction.

# Wrap a summary so that autoplot() knows what it is looking at.
.dr_new_summary <- function(x, statistic, by) {
  x <- dplyr::as_tibble(x)
  structure(x,
            class = c(paste0("dr_summary_", statistic), "dr_summary", class(x)),
            statistic = statistic, by = by)
}

# The group columns a `...` produced, in the order the caller wrote them.
.dr_group_names <- function(grouped) setdiff(dplyr::group_vars(grouped), "latin")

.dr_check_conf <- function(conf) {
  if (!is.numeric(conf) || length(conf) != 1L || is.na(conf) || conf <= 0 || conf >= 1) {
    cli::cli_abort(c("{.arg conf} must be a single number between 0 and 1.",
                     "x" = "Got {.val {conf}}."), call = rlang::caller_env())
  }
  invisible(conf)
}

#' Count the hauls
#'
#' How many hauls are there, by whatever you group by? With two grouping
#' columns, `Year` and `Survey`, it is the picture of what data exist.
#'
#' @param data Hauls: one row per haul, with `.id` (see [dr_add_id()]); lazy or
#'   in memory. Usually `dr_con("HH")`, optionally filtered.
#' @param ... Columns (or expressions of columns, as in [dplyr::count()]) to
#'   group by. By convention the first is the x-axis when the result is drawn
#'   with [ggplot2::autoplot()] and the second the y-axis.
#'
#' @return A tibble with the grouping columns and `n_hauls`.
#' @seealso [dr_summarise_occurrence()], [dr_summarise_cpue()]
#' @export
#'
#' @examples
#' \dontrun{
#' dr_con("HH") |> dr_summarise_hauls(Year, Survey)
#' }
dr_summarise_hauls <- function(data, ...) {
  .dr_require_cols(data, ".id", "dr_summarise_hauls")
  grouped <- dplyr::group_by(data, ...)
  by <- .dr_group_names(grouped)

  out <- grouped |>
    dplyr::summarise(n_hauls = dplyr::n_distinct(.id), .groups = "drop") |>
    dplyr::collect() |>
    dplyr::arrange(dplyr::across(dplyr::all_of(by)))

  .dr_new_summary(out, "hauls", by)
}

#' Probability of capture: the share of hauls that caught a species
#'
#' For each group, the number of hauls, the number that caught the species, and
#' the share, `p`, with a confidence interval. Zeros are included: a haul that
#' did not catch the species counts in the denominator (see
#' [dr_add_catch()]).
#'
#' @details
#' The interval is Wilson's, which behaves at shares near 0 and 1 and at small
#' numbers of hauls where the usual normal interval does not.
#'
#' @inheritParams dr_summarise_hauls
#' @param species Latin names or numeric `Valid_Aphia` codes, as in
#'   `dr_con("species")`. One or several; each is a panel when drawn.
#' @param ... Columns to group by, as in [dr_summarise_hauls()].
#' @param conf Confidence level of the interval.
#'
#' @return A tibble with the grouping columns, `latin`, `n_hauls`,
#'   `n_present`, `p`, `lower` and `upper`.
#' @seealso [dr_add_catch()] for the table underneath, [dr_summarise_cpue()].
#' @export
#'
#' @examples
#' \dontrun{
#' hh <- dr_con("HH")
#' dr_summarise_occurrence(hh, "Raja clavata", Year, Survey)
#'
#' # drawn
#' dr_summarise_occurrence(hh, "Raja clavata", Year, Survey) |>
#'   ggplot2::autoplot()
#' }
dr_summarise_occurrence <- function(data, species, ..., conf = 0.95) {
  .dr_check_conf(conf)
  .dr_require_cols(data, ".id", "dr_summarise_occurrence")
  .dr_occurrence(.dr_catch(data, .dr_species(species)), ..., conf = conf)
}

# The statistics, on the zero-filled catch table: counts from the data source,
# shares and intervals in R.
.dr_occurrence <- function(catch, ..., conf) {
  grouped <- dplyr::group_by(catch, ..., latin)
  by      <- .dr_group_names(grouped)

  out <- grouped |>
    dplyr::summarise(n_hauls   = dplyr::n_distinct(.id),
                     n_present = sum(as.integer(present), na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::collect() |>
    dplyr::mutate(
      n_hauls   = as.numeric(n_hauls),
      n_present = as.numeric(n_present),
      p         = n_present / n_hauls,
      .wilson   = .dr_wilson(n_present, n_hauls, conf),
      lower     = .wilson$lower,
      upper     = .wilson$upper,
      .wilson   = NULL
    ) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(by, "latin"))))

  .dr_new_summary(out, "occurrence", by)
}

# Wilson score interval for k successes in n trials.
.dr_wilson <- function(k, n, conf) {
  z   <- stats::qnorm(1 - (1 - conf) / 2)
  p   <- k / n
  den <- 1 + z^2 / n
  mid <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  data.frame(lower = pmax(mid - hw, 0), upper = pmin(mid + hw, 1))
}

#' Catch per hour: the mean number of fish per haul, zeros included
#'
#' For each group, the number of hauls and the mean number caught per hour,
#' `cpue`, with an interval. Hauls that did not catch the species count as zero.
#'
#' @details
#' The interval is the normal approximation, `cpue +- z * se`, floored at
#' zero. Catch per haul is skewed, so it is a rough guide at few hauls and for
#' a rare species, where it is wide and its lower end is often zero; it is
#' computed from counts and sums so that lazy and in-memory input agree
#' exactly. A haul whose hourly rate is unknown (a missing or non-positive
#' haul duration) is left out of the mean, not counted as zero.
#'
#' @inheritParams dr_summarise_occurrence
#'
#' @return A tibble with the grouping columns, `latin`, `n_hauls`, `cpue`
#'   (numbers per hour), `lower` and `upper`.
#' @seealso [dr_summarise_occurrence()], [dr_add_catch()].
#' @export
#'
#' @examples
#' \dontrun{
#' dr_con("HH") |>
#'   dplyr::filter(Survey == "NS-IBTS", Quarter == 1L) |>
#'   dr_summarise_cpue("Gadus morhua", Year)
#' }
dr_summarise_cpue <- function(data, species, ..., conf = 0.95) {
  .dr_check_conf(conf)
  .dr_require_cols(data, ".id", "dr_summarise_cpue")
  .dr_cpue(.dr_catch(data, .dr_species(species)), ..., conf = conf)
}

.dr_cpue <- function(catch, ..., conf) {
  grouped <- dplyr::group_by(catch, ..., latin)
  by      <- .dr_group_names(grouped)

  out <- grouped |>
    dplyr::summarise(n_hauls = dplyr::n_distinct(.id),
                     n_known = sum(as.integer(!is.na(n_totalnumber_hour)), na.rm = TRUE),
                     total   = sum(n_totalnumber_hour, na.rm = TRUE),
                     total2  = sum(n_totalnumber_hour^2, na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::collect() |>
    dplyr::mutate(
      n_hauls = as.numeric(n_hauls),
      n_known = as.numeric(n_known),
      total   = dplyr::coalesce(as.numeric(total), 0),
      total2  = dplyr::coalesce(as.numeric(total2), 0),
      cpue    = dplyr::if_else(n_known > 0, total / n_known, NA_real_),
      .var    = dplyr::if_else(n_known > 1,
                               pmax(total2 - n_known * cpue^2, 0) / (n_known - 1),
                               NA_real_),
      .z      = stats::qnorm(1 - (1 - conf) / 2),
      .half   = .z * sqrt(.var / n_known),
      lower   = pmax(cpue - .half, 0),
      upper   = cpue + .half,
      n_known = NULL, total = NULL, total2 = NULL,
      .var = NULL, .z = NULL, .half = NULL
    ) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(by, "latin"))))

  .dr_new_summary(out, "cpue", by)
}

#' Numbers at length: the mean number per haul in each length class
#'
#' For each group and length class, the mean number per hour among the hauls
#' in the group, with hauls that caught none at that length counted as zero.
#' This is the length-frequency figure, per haul.
#'
#' @details
#' `length_cm` is the **lower boundary** of a length class in whole
#' centimetres (10 means 10 to 11 cm), as ICES defines `LengthClass`, so a
#' bar drawn at it starts where the class starts. Surveys that record finer
#' classes (half centimetres, millimetres) are merged to whole centimetres, so
#' they can be compared. Length classes with no fish in a group have no
#' row. Numbers come from [dr_hl_length()]'s published table, `HL_length`.
#'
#' @inheritParams dr_summarise_occurrence
#'
#' @return A tibble with the grouping columns, `latin`, `length_cm`, `n_hauls`
#'   (the hauls in the group) and `n_hour` (mean number per hour per haul).
#' @seealso [dr_summarise_cpue()].
#' @export
#'
#' @examples
#' \dontrun{
#' dr_con("HH") |>
#'   dplyr::filter(Survey == "NS-IBTS", Quarter == 1L, Year > 2015) |>
#'   dr_summarise_length("Gadus morhua", Year)
#' }
dr_summarise_length <- function(data, species, ...) {
  .dr_require_cols(data, ".id", "dr_summarise_length")
  .dr_length(data, .dr_species(species), dr_con("HL_length"), ...)
}

.dr_length <- function(data, species_tbl, hl_length, ...) {
  # the grouping columns, worked out once per haul
  keys <- dplyr::transmute(data, .id, ...)
  by   <- setdiff(colnames(keys), ".id")

  hauls <- keys |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(n_hauls = dplyr::n_distinct(.id), .groups = "drop") |>
    dplyr::collect()

  lengths <- hl_length |>
    dplyr::semi_join(species_tbl, by = "Valid_Aphia", copy = TRUE) |>
    # only what is needed: HL_length has its own Year, Survey and Quarter,
    # which would collide with the grouping columns taken from the hauls
    dplyr::select(.id, latin, length_cm, n_hour) |>
    # whole centimetres: a survey that records half-centimetre or millimetre
    # classes would otherwise draw a comb next to one that records 1 cm
    dplyr::mutate(length_cm = floor(length_cm)) |>
    dplyr::inner_join(keys, by = ".id", copy = TRUE) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by)), latin, length_cm) |>
    dplyr::summarise(total = sum(n_hour, na.rm = TRUE), .groups = "drop") |>
    dplyr::collect()

  out <- lengths |>
    dplyr::inner_join(hauls, by = by) |>
    dplyr::mutate(n_hauls = as.numeric(n_hauls),
                  n_hour  = dplyr::coalesce(as.numeric(total), 0) / n_hauls,
                  total   = NULL) |>
    dplyr::relocate(n_hauls, .before = n_hour) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(by, "latin", "length_cm"))))

  .dr_new_summary(out, "length", by)
}
