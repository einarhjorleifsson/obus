#' Standardised length-frequency catch table from HH and HL exchange data
#'
#' Processes raw DATRAS HH and HL tables into a clean catch-only table with
#' standardised length units, corrected CPUE arithmetic, and species names.
#' Contains only observed catches — no zero rows. Use \code{\link{dr_catch_by_haul}}
#' or \code{\link{dr_expand_length}} downstream to add zero-fill.
#'
#' @param hh DATRAS haul header table (HH). Must carry \code{.id}. Required
#'   columns: \code{.id}, \code{Survey}, \code{Year}, \code{Quarter},
#'   \code{HaulValidity}, \code{DataType}, \code{HaulDuration}.
#' @param hl DATRAS length table (HL). Must carry \code{.id}. Required
#'   columns: \code{.id}, \code{NumberAtLength}, \code{LengthClass},
#'   \code{LengthCode}, \code{SubsamplingFactor}, \code{aphia},
#'   \code{SpeciesValidity}.
#' @param species Species lookup with columns \code{aphia}, \code{latin},
#'   \code{species}. Defaults to \code{dr_con("species")}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   \code{NULL} keeps all hauls.
#'
#' @return A lazy DuckDB table with one row per
#'   \code{.id} \eqn{\times} \code{aphia} \eqn{\times} \code{length_mm}:
#'   \describe{
#'     \item{\code{.id}}{8-field haul identifier.}
#'     \item{\code{Survey}}{Survey code.}
#'     \item{\code{Year}}{Survey year.}
#'     \item{\code{Quarter}}{Survey quarter.}
#'     \item{\code{aphia}}{WoRMS valid AphiaID.}
#'     \item{\code{latin}}{WoRMS-accepted Latin name.}
#'     \item{\code{species}}{Common name.}
#'     \item{\code{length_mm}}{Length in millimetres.}
#'     \item{\code{length_cm}}{Length in centimetres.}
#'     \item{\code{accuracy}}{Measurement resolution in centimetres.}
#'     \item{\code{n_haul}}{Estimated numbers per haul.}
#'     \item{\code{n_hour}}{Estimated numbers per hour (CPUE).}
#'     \item{\code{SpeciesValidity}}{Validity code from HL.}
#'   }
#'
#' @seealso \code{\link{dr_catch_by_haul}}, \code{\link{dr_expand_length}},
#'   \code{\link{dr_add_length_cm}}, \code{\link{dr_add_n_and_cpue}},
#'   \code{\link{dr_add_species}}, \code{\link{dr_con}}
#'
#' @export

dr_catch_by_length <- function(hh, hl, species = NULL, haulval = NULL) {
  .Deprecated("dr_standardize_hl",
              msg = paste0("'dr_catch_by_length()' is deprecated. ",
                           "Use dr_standardize_hl() and filter(type == 'length') instead."))
  if (is.null(species)) {
    species <- if (inherits(hl, "tbl_lazy")) dr_con("species") else dr_lookup_species
  }
  if (!is.null(haulval)) hh <- dplyr::filter(hh, HaulValidity %in% haulval)

  hl |>
    dplyr::filter(NumberAtLength != 0) |>
    dplyr::select(-dplyr::any_of(c("Survey", "Year", "Quarter"))) |>
    dplyr::inner_join(dplyr::select(hh, .id, Survey, Year, Quarter, DataType, HaulDuration), by = ".id") |>
    dplyr::filter(!is.na(LengthClass)) |>
    dr_add_length_mm() |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    dr_add_species(species) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, latin, species, length_mm,
                    length_cm, accuracy, SpeciesValidity) |>
    dplyr::summarise(n_haul = sum(n_haul, na.rm = TRUE),
                     n_hour = sum(n_hour, na.rm = TRUE),
                     .groups = "drop")
}


#' Haul-level CPUE with zero-fill across species
#'
#' Collapses the length structure of \code{\link{dr_catch_by_length}} output to
#' total CPUE per haul per species, then zero-fills: every species observed
#' anywhere in a Survey/Year/Quarter gets an explicit zero row for each haul
#' in that SQY where it was absent. Works with one or more species.
#'
#' @param catch A length-frequency catch table — typically
#'   \code{dr_standardize_hl(...) |> dplyr::filter(type == "length")}, or the
#'   deprecated \code{\link{dr_catch_by_length}} output. Must carry columns
#'   \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}, \code{aphia},
#'   \code{latin}, \code{species}, \code{n_haul}, \code{n_hour}.
#' @param hh DATRAS haul header table providing the full haul list. Required
#'   columns: \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}.
#'
#' @return A lazy DuckDB table with one row per \code{.id} \eqn{\times}
#'   \code{aphia}: \code{.id}, \code{Survey}, \code{Year}, \code{Quarter},
#'   \code{aphia}, \code{latin}, \code{species}, \code{n_haul}, \code{n_hour}.
#'   \code{n_haul} and \code{n_hour} are \code{0} for zero rows.
#'
#' @seealso \code{\link{dr_standardize_hl}}, \code{\link{dr_expand_length}}
#' @export

dr_catch_by_haul <- function(catch, hh) {
  hauls <- dplyr::distinct(hh, .id, Survey, Year, Quarter)

  cpue <- catch |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, latin, species) |>
    dplyr::summarise(n_haul = sum(n_haul, na.rm = TRUE),
                     n_hour = sum(n_hour, na.rm = TRUE),
                     .groups = "drop")

  spp_per_syq <- dplyr::distinct(catch, aphia, latin, species, Survey, Year, Quarter)

  full_grid <- hauls |>
    dplyr::inner_join(spp_per_syq, by = c("Survey", "Year", "Quarter"))

  zero_rows <- full_grid |>
    dplyr::anti_join(dplyr::distinct(cpue, .id, aphia), by = c(".id", "aphia")) |>
    dplyr::mutate(n_haul = 0, n_hour = 0)

  dplyr::union_all(
    dplyr::select(cpue,      .id, Survey, Year, Quarter, aphia, latin, species, n_haul, n_hour),
    dplyr::select(zero_rows, .id, Survey, Year, Quarter, aphia, latin, species, n_haul, n_hour)
  )
}


#' Full length-bin expansion with zero-fill across hauls
#'
#' Expands \code{\link{dr_catch_by_length}} output to a complete
#' haul \eqn{\times} length-bin grid: every length class observed for a
#' species anywhere in a Survey/Year/Quarter is propagated to all hauls in
#' that SQY, with zeros where absent. Works with one or more species; filter
#' to a single species before calling to keep the result manageable.
#'
#' @param catch A length-frequency catch table — typically
#'   \code{dr_standardize_hl(...) |> dplyr::filter(type == "length")}, or the
#'   deprecated \code{\link{dr_catch_by_length}} output. Must carry columns
#'   \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}, \code{aphia},
#'   \code{latin}, \code{species}, \code{length_mm}, \code{length_cm},
#'   \code{accuracy}, \code{n_haul}, \code{n_hour}, \code{SpeciesValidity}.
#' @param hh DATRAS haul header table providing the full haul list. Required
#'   columns: \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}.
#'
#' @return A lazy DuckDB table with one row per \code{.id} \eqn{\times}
#'   \code{aphia} \eqn{\times} \code{length_mm}. \code{n_haul} and
#'   \code{n_hour} are \code{0} and \code{SpeciesValidity} is \code{NA} for
#'   zero rows.
#'
#' @seealso \code{\link{dr_standardize_hl}}, \code{\link{dr_catch_by_haul}}
#' @export

dr_expand_length <- function(catch, hh) {
  hauls <- dplyr::distinct(hh, .id, Survey, Year, Quarter)

  lengths_per_syq <- dplyr::distinct(catch, aphia, latin, species, Survey, Year, Quarter,
                                     length_mm, length_cm, accuracy)

  full_grid <- hauls |>
    dplyr::inner_join(lengths_per_syq, by = c("Survey", "Year", "Quarter"))

  zero_rows <- full_grid |>
    dplyr::anti_join(
      dplyr::distinct(catch, .id, aphia, length_mm),
      by = c(".id", "aphia", "length_mm")
    ) |>
    dplyr::mutate(n_haul = 0, n_hour = 0, SpeciesValidity = NA_character_)

  dplyr::union_all(
    dplyr::select(catch,     .id, Survey, Year, Quarter, aphia, latin, species,
                  length_mm, length_cm, accuracy, n_haul, n_hour, SpeciesValidity),
    dplyr::select(zero_rows, .id, Survey, Year, Quarter, aphia, latin, species,
                  length_mm, length_cm, accuracy, n_haul, n_hour, SpeciesValidity)
  )
}


# Write by_length.parquet sorted for efficient HTTP byte-range queries.
# Rows are ordered by .id (which encodes Survey:Year:...) then aphia and
# length_mm so that row group min/max statistics are tight enough for DuckDB
# to skip irrelevant groups when filtering over HTTPS.
.write_catch_by_length <- function(hh, hl, path, species = NULL, haulval = NULL,
                              row_group_size = 100000L) {
  result <- dr_catch_by_length(hh, hl, species = species, haulval = haulval) |>
    dplyr::arrange(.id, aphia, length_mm)

  DBI::dbExecute(
    dbplyr::remote_con(result),
    sprintf(
      "COPY (%s) TO '%s' (FORMAT PARQUET, ROW_GROUP_SIZE %d)",
      dbplyr::sql_render(result),
      normalizePath(path, mustWork = FALSE),
      as.integer(row_group_size)
    )
  )
  invisible(path)
}


#' Haul-level catch totals (numbers and weights) from HH and HL exchange data
#'
#' Computes total catch in numbers and weight per haul per species from raw
#' DATRAS HH and HL tables, and annotates each species with its Latin and
#' common name via \code{\link{dr_add_species}}. \code{SpeciesSex} and
#' \code{SpeciesCategory} are collapsed by summation.
#'
#' \code{TotalNumber} and \code{SpeciesCategoryWeight} are haul-level summary
#' fields in HL that are repeated across every length row within a
#' species/sex/category group. The function deduplicates at the group level
#' before applying DataType-aware scaling, so each length row does not inflate
#' the totals. A zero row (all metrics \code{0}) is inserted for every
#' species that was observed somewhere in the same
#' \code{Survey} / \code{Year} / \code{Quarter} but was absent from a given
#' haul, including hauls with no catch at all.
#'
#' @param hh DATRAS haul header table (HH) with new-style column names (as
#'   returned by \code{\link{dr_get}} or \code{\link{dr_con}}). When
#'   \code{NULL} (default), falls back to \code{dr_con("HH")}. Pre-filter
#'   before passing if desired (e.g.
#'   \code{dplyr::filter(HaulValidity == "V")}).
#'   Must already carry \code{.id} (add with \code{\link{dr_add_id}}).
#'   Required columns: \code{.id}, \code{Survey}, \code{Year},
#'   \code{Quarter}, \code{DataType}, \code{HaulDuration}.
#' @param hl DATRAS length table (HL) with new-style column names. When
#'   \code{NULL} (default), falls back to \code{dr_con("HL")}. Pre-filter
#'   before passing if desired (e.g.
#'   \code{dplyr::filter(SpeciesValidity == "1")}).
#'   Must already carry \code{.id} (add with \code{\link{dr_add_id}}).
#'   Required columns: \code{.id}, \code{aphia}, \code{SpeciesValidity},
#'   \code{TotalNumber}, \code{SpeciesCategoryWeight}, \code{SpeciesSex},
#'   \code{SpeciesCategory}.
#' @param species Species lookup table with columns \code{aphia},
#'   \code{latin}, and \code{species} (common name). When \code{NULL}
#'   (default), falls back to \code{dr_con("species")}.
#'
#' @return A lazy DuckDB table or data frame (matching the input type) with
#'   one row per \code{.id} \eqn{\times} \code{latin} combination, plus one
#'   zero row per absent haul \eqn{\times} species:
#'   \describe{
#'     \item{\code{.id}}{8-field unique haul identifier:
#'       \code{Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber}.}
#'     \item{\code{latin}}{WoRMS-accepted Latin species name.}
#'     \item{\code{species}}{Common species name.}
#'     \item{\code{n_haul}}{Total estimated numbers caught per haul.
#'       \code{0} for zero rows.}
#'     \item{\code{n_hour}}{Total estimated numbers per hour of hauling.
#'       \code{0} for zero rows.}
#'     \item{\code{w_haul}}{Total catch weight per haul in grams.
#'       \code{0} for zero rows. \code{NA} within non-zero rows when
#'       \code{SpeciesCategoryWeight} was not recorded for all
#'       sex/category groups.}
#'     \item{\code{w_hour}}{Total catch weight per hour of hauling in grams.
#'       \code{0} for zero rows; \code{NA} as for \code{w_haul}.}
#'     \item{\code{SpeciesValidity}}{Species validity code from HL.
#'       \code{NA} for zero rows.}
#'   }
#'
#' @seealso \code{\link{dr_catch_by_length}} for the length-disaggregated version.
#'   \code{\link{dr_add_species}}, \code{\link{dr_add_id}},
#'   \code{\link{dr_con}}
#'
#' @export
dr_catch_total <- function(hh = NULL, hl = NULL, species = NULL) {
  .Deprecated("dr_standardize_hl",
              msg = paste0("'dr_catch_total()' is deprecated. ",
                           "Use dr_standardize_hl() and filter(type == 'haul') instead. ",
                           "Note: dr_standardize_hl() does not zero-fill; ",
                           "pipe to dr_catch_by_haul() for zero-filling."))
  if (is.null(hh))      hh      <- dr_con("HH")
  if (is.null(hl))      hl      <- dr_con("HL")
  if (is.null(species)) {
    species <- if (inherits(hl, "tbl_lazy")) dr_con("species") else dr_lookup_species
  }

  # --- deduplicate to one row per haul × species × sex × SpeciesCategory ----
  # TotalNumber and SpeciesCategoryWeight are repeated across all length rows
  # within a group; distinct() collapses them without summing.
  hl_dedup <- hl |>
    dplyr::distinct(.id, aphia, sex, SpeciesCategory, SpeciesValidity,
                    TotalNumber, SpeciesCategoryWeight) |>
    dplyr::inner_join(dplyr::select(hh, .id, DataType, HaulDuration),
                      by = ".id")

  # --- DataType-aware scaling -----------------------------------------------
  # R/S/P: TotalNumber and SpeciesCategoryWeight are already per-haul totals.
  # C:     Both are raised to 1 hour; back-convert to per-haul.
  hl_scaled <- hl_dedup |>
    dplyr::mutate(
      n_haul = dplyr::case_when(
        DataType == "C" ~ TotalNumber           * HaulDuration / 60,
        TRUE            ~ TotalNumber
      ),
      n_hour = dplyr::case_when(
        DataType == "C" ~ TotalNumber,
        TRUE            ~ TotalNumber           / HaulDuration * 60
      ),
      w_haul = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight * HaulDuration / 60,
        TRUE            ~ SpeciesCategoryWeight
      ),
      w_hour = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight,
        TRUE            ~ SpeciesCategoryWeight / HaulDuration * 60
      )
    )

  # --- aggregate across SpeciesSex and SpeciesCategory, join species names ---
  hl_agg <- hl_scaled |>
    dplyr::group_by(.id, aphia, SpeciesValidity) |>
    dplyr::summarise(
      n_haul = sum(n_haul, na.rm = TRUE),
      n_hour = sum(n_hour, na.rm = TRUE),
      w_haul = sum(w_haul, na.rm = TRUE),
      w_hour = sum(w_hour, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dr_add_species(species)

  # --- zero-fill -----------------------------------------------------------
  # Hauls sourced from HH so that hauls with no catch at all are included.
  hauls       <- dplyr::distinct(hh, .id, Survey, Year, Quarter)
  spp_per_syq <- hl_agg |>
    dplyr::inner_join(dplyr::select(hauls, .id, Survey, Year, Quarter), by = ".id") |>
    dplyr::distinct(latin, species, Survey, Year, Quarter)

  full_grid <- hauls |>
    dplyr::inner_join(spp_per_syq, by = c("Survey", "Year", "Quarter"))

  zero_rows <- full_grid |>
    dplyr::anti_join(dplyr::distinct(hl_agg, .id, latin), by = c(".id", "latin")) |>
    dplyr::mutate(
      n_haul          = 0,
      n_hour          = 0,
      w_haul          = 0,
      w_hour          = 0,
      SpeciesValidity = NA_character_
    ) |>
    dplyr::select(.id, latin, species,
                  n_haul, n_hour, w_haul, w_hour, SpeciesValidity)

  hl_agg |>
    dplyr::select(.id, latin, species,
                  n_haul, n_hour, w_haul, w_hour, SpeciesValidity) |>
    dplyr::union_all(zero_rows)
}

