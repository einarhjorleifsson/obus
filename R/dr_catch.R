# Catch per haul, with the zeros ------------------------------------------------------
#
# A species that was not caught has NO row in HL_summary. Every frequency and
# every mean per haul therefore needs the absences put back, and that is the
# step the book hand-wrote in about eight chapters. This is that step, once.

# The catch measures HL_summary carries per haul and species, under opus's own
# names (obus invents none).
.DR_CATCH_MEASURES <- c("n_totalnumber", "n_totalnumber_hour", "n_haul",
                        "w_haul", "w_hour")

# The ones that come from a submitted species total rather than from the length
# rows. Where a haul and species has several SpeciesValidity records, DATRAS
# repeats such a total on each of them, so it is taken once, not summed.
.DR_CATCH_SUBMITTED <- c("n_totalnumber", "n_totalnumber_hour", "w_haul", "w_hour")

#' Add the catch of chosen species to hauls, zeros included
#'
#' Crosses every haul in `data` with every species in `species` and attaches
#' what `dr_con("HL_summary")` records for that haul and species. A species
#' with no record in a haul gets **zero**, not a missing value: it was not in
#' the catch. This is the table that frequencies of occurrence and means per
#' haul are computed from, and the step that goes wrong when it is done by hand
#' with `na.rm = TRUE`.
#'
#' @details
#' **Which hauls count as a zero.** By default (`zeros = "hauls"`) every haul
#' in `data` is a haul where the species could have been caught, so you decide
#' the universe by filtering `data` first: `dr_con("HH") |> dplyr::filter(Survey
#' == "NS-IBTS")`. `zeros = "reported"` follows ICES's own rule for its
#' products: a zero is added only in a survey, year and quarter in which the
#' species was reported in at least one haul. That reproduces the DATRAS
#' products, but it silently drops every year in which a species was caught
#' nowhere, which is exactly what a retreating species does, so it can hide
#' the decline it is meant to measure.
#'
#' **A zero is a claim that the species was looked for.** `HH` carries
#' `BycatchSpeciesCode` and `StandardSpeciesCode`, which say what a haul's
#' recording sheet covered; they are kept in the result so that you can drop
#' hauls where the species could not have been written down. obus does not
#' decide this for you: which field applies depends on the species and on the
#' survey's own standard list.
#'
#' **Several records per haul and species.** HL allows more than one
#' (`SpeciesValidity` is a record type, not a quality flag), and they are
#' combined in two ways. `n_haul` comes from the length rows, which are never
#' repeated across records, so it is summed. The submitted totals
#' (`n_totalnumber`, `n_totalnumber_hour`, `w_haul`, `w_hour`) almost always
#' repeat one species total on every record, so a value that is the same on
#' each record is taken once; values that differ are summed. A total reported
#' as missing in every record stays missing rather than becoming zero.
#'
#' @param data Hauls: one row per haul, with `.id` (see [dr_add_id()]); lazy
#'   or in memory. Usually `dr_con("HH")`, optionally filtered.
#' @param species Latin names (`"Gadus morhua"`) or numeric `Valid_Aphia`
#'   codes, as in `dr_con("species")`.
#' @param zeros Which hauls get a zero for a species that was not caught:
#'   `"hauls"` (every haul in `data`, the default) or `"reported"` (only
#'   within survey, year and quarter combinations where the species was
#'   reported at all). See Details.
#'
#' @return `data` with one row per haul and species, and added columns
#'   `Valid_Aphia`, `latin`, the catch measures `n_totalnumber`,
#'   `n_totalnumber_hour`, `n_haul`, `w_haul`, `w_hour` (as in
#'   [dr_hl_summary()]), and `present`: `TRUE` where the species has a record
#'   in the haul. Lazy if `data` was lazy, in memory otherwise.
#'
#' @seealso [dr_summarise_occurrence()] and [dr_summarise_cpue()], which start
#'   from this table.
#' @export
#'
#' @examples
#' \dontrun{
#' hh <- dr_con("HH") |>
#'   dplyr::filter(Survey == "NS-IBTS", Quarter == 1L)
#'
#' hh |>
#'   dr_add_catch(c("Gadus morhua", "Raja clavata")) |>
#'   dplyr::group_by(Year, latin) |>
#'   dplyr::summarise(share_of_hauls = mean(present), .groups = "drop") |>
#'   dplyr::collect()
#' }
dr_add_catch <- function(data, species, zeros = c("hauls", "reported")) {
  zeros <- rlang::arg_match(zeros)
  .dr_require_cols(data, ".id", "dr_add_catch")
  if (zeros == "reported") {
    .dr_require_cols(data, c("Survey", "Year", "Quarter"), "dr_add_catch")
  }
  if ("Valid_Aphia" %in% colnames(data)) {
    cli::cli_abort(c(
      "{.arg data} must be hauls, one row per haul.",
      "x" = "It already has a {.field Valid_Aphia} column, so it looks like a catch table.",
      "i" = "Pass the haul table, e.g. {.code dr_con(\"HH\")}."
    ))
  }

  .dr_catch(data, .dr_species(species), zeros)
}

# The engine shared by dr_add_catch() and the dr_summarise_*() verbs: one dplyr
# pipeline that runs unchanged on lazy and on in-memory hauls. The only thing
# that differs is where the catch lives. It is aggregated in DuckDB either way;
# when the hauls are in memory the (small, species-filtered) result is collected
# so the joins below happen between like and like.
.dr_catch <- function(hauls, species, zeros = "hauls", source = dr_con("HL_summary")) {
  lazy <- inherits(hauls, "tbl_lazy")

  catch <- source |>
    dplyr::semi_join(species, by = "Valid_Aphia", copy = TRUE) |>
    dplyr::group_by(.id, Valid_Aphia) |>
    dplyr::summarise(
      # A total missing in every record of the group is unknown, not zero:
      # sum(x, na.rm = TRUE) over all-NA is 0 in R but NULL in SQL, and the two
      # backends must agree.
      dplyr::across(
        dplyr::all_of(.DR_CATCH_SUBMITTED),
        # A submitted total repeated on every record is taken once. "The same"
        # allows for float noise: HL_summary adds category totals in no fixed
        # order, so one total can arrive as 212.4 on one record and a bit off
        # it on the next. sd() is used rather than max() - min(), which warns
        # in R on an all-NA group.
        ~ dplyr::case_when(
          sum(as.integer(!is.na(.x)), na.rm = TRUE) == 0L ~ NA_real_,
          dplyr::coalesce(stats::sd(.x, na.rm = TRUE), 0) <=
            1e-9 * abs(mean(.x, na.rm = TRUE)) ~ mean(.x, na.rm = TRUE),
          .default = sum(.x, na.rm = TRUE))),
      n_haul = dplyr::if_else(sum(as.integer(!is.na(n_haul)), na.rm = TRUE) == 0L,
                              NA_real_, sum(n_haul, na.rm = TRUE)),
      .seen = 1L,
      .groups = "drop") |>
    dplyr::select(".id", "Valid_Aphia", dplyr::all_of(.DR_CATCH_MEASURES), ".seen")

  if (!lazy) {
    catch   <- dplyr::collect(catch)
    species <- dplyr::collect(species)
  }

  out <- hauls |>
    dplyr::cross_join(species) |>
    dplyr::left_join(catch, by = c(".id", "Valid_Aphia")) |>
    dplyr::mutate(present = !is.na(.seen)) |>
    # A species with no record is a zero; one with a record but no value stays
    # missing, because that is what the submission says.
    dplyr::mutate(dplyr::across(
      dplyr::all_of(.DR_CATCH_MEASURES),
      ~ dplyr::if_else(present, .x, 0))) |>
    dplyr::select(-.seen)

  if (zeros == "reported") {
    out <- out |>
      dplyr::group_by(Survey, Year, Quarter, Valid_Aphia) |>
      dplyr::mutate(.reported = max(as.integer(present), na.rm = TRUE)) |>
      dplyr::ungroup() |>
      dplyr::filter(.reported == 1L) |>
      dplyr::select(-.reported)
  }
  out
}
