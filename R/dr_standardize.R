#' Standardize HL into a clean catch foundation (length and haul summaries)
#'
#' Produces a unified catch table from raw HH and HL exchange tables with two
#' row types controlled by the \code{type} column:
#'
#' \describe{
#'   \item{\code{type = "length"}}{One row per \code{.id} \eqn{\times} \code{aphia}
#'     \eqn{\times} \code{length_mm}. Sex and DevelopmentStage are collapsed;
#'     sex composition is summarised as \code{p_females} (proportion female among
#'     sexed fish). Derived from \code{NumberAtLength} via
#'     \code{\link{dr_add_n_and_cpue}}. Replaces \code{dr_catch_by_length()}.}
#'   \item{\code{type = "haul"}}{One row per \code{.id} \eqn{\times} \code{aphia}.
#'     Numbers (\code{n_haul}, \code{n_hour}) come from \code{TotalNumber};
#'     weights (\code{w_haul}, \code{w_hour}) from \code{SpeciesCategoryWeight}.
#'     Sex composition summarised as \code{p_females}. Replaces
#'     \code{dr_catch_total()} (without zero-filling). Pass output to
#'     \code{\link{dr_catch_by_haul}} for zero-filling.}
#' }
#'
#' \strong{Note:} \code{n_haul} from \code{type = "haul"} may differ from the
#' sum of \code{n_haul} across \code{type = "length"} rows for the same haul
#' and species. The haul path uses \code{TotalNumber} which counts all fish
#' including those counted but not measured at length.
#'
#' @param hh DATRAS HH table (standard column names, \code{.id} present).
#'   Required columns: \code{.id}, \code{Survey}, \code{Year}, \code{Quarter},
#'   \code{DataType}, \code{HaulDuration}, \code{StandardSpeciesCode},
#'   \code{BycatchSpeciesCode}. Optional: \code{HaulValidity} (used when
#'   \code{haulval} is set).
#' @param hl DATRAS HL table (standard column names, \code{.id} present).
#'   Required for \code{type = "length"}: \code{.id}, \code{aphia},
#'   \code{NumberAtLength}, \code{LengthClass}, \code{LengthCode},
#'   \code{SubsamplingFactor}, \code{sex}, \code{SpeciesValidity}.
#'   Required for \code{type = "haul"}: additionally \code{TotalNumber},
#'   \code{SpeciesCategoryWeight}, \code{SpeciesCategory}.
#' @param species Species lookup with columns \code{aphia}, \code{latin},
#'   \code{species}. Defaults to \code{dr_con("species")}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   \code{NULL} keeps all hauls.
#'
#' @return A lazy DuckDB table with columns:
#'   \code{.id}, \code{Survey}, \code{Year}, \code{Quarter},
#'   \code{aphia}, \code{latin}, \code{species}, \code{type},
#'   \code{length_mm}, \code{length_cm}, \code{accuracy}
#'     (\code{NA} for \code{type = "haul"}),
#'   \code{n_haul}, \code{n_hour},
#'   \code{w_haul}, \code{w_hour}
#'     (\code{NA} for \code{type = "length"}),
#'   \code{p_females}, \code{SpeciesValidity},
#'   \code{StandardSpeciesCode}, \code{BycatchSpeciesCode}.
#'
#' @seealso \code{\link{dr_catch_by_haul}}, \code{\link{dr_expand_length}}
#' @export
dr_standardize_hl <- function(hh, hl, species = NULL, haulval = NULL) {
  if (is.null(species)) species <- dr_con("species")
  if (!is.null(haulval)) hh <- dplyr::filter(hh, HaulValidity %in% haulval)

  hh_cols <- dplyr::select(hh, .id, Survey, Year, Quarter, DataType, HaulDuration,
                            StandardSpeciesCode, BycatchSpeciesCode)

  # ---- type = "length": NumberAtLength path, sex collapsed to p_females ----
  hl_length <- hl |>
    dplyr::filter(NumberAtLength != 0) |>
    dplyr::select(-dplyr::any_of(c("Survey", "Year", "Quarter"))) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::filter(!is.na(LengthClass)) |>
    dr_add_length_mm() |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    dr_add_species(species) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, latin, species,
                    length_mm, length_cm, accuracy, SpeciesValidity,
                    StandardSpeciesCode, BycatchSpeciesCode) |>
    dplyr::summarise(
      n_haul = sum(n_haul, na.rm = TRUE),
      n_hour = sum(n_hour, na.rm = TRUE),
      n_f    = sum(dplyr::if_else(sex == "F", n_haul, 0), na.rm = TRUE),
      n_m    = sum(dplyr::if_else(sex == "M", n_haul, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      p_females = dplyr::if_else(n_f + n_m > 0, n_f / (n_f + n_m), NA_real_)
    ) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species,
      length_mm, length_cm, accuracy,
      n_haul, n_hour, p_females, SpeciesValidity,
      StandardSpeciesCode, BycatchSpeciesCode
    ) |>
    dplyr::mutate(type = "length",
                  w_haul = NA_real_, w_hour = NA_real_)

  # ---- type = "haul": TotalNumber / SpeciesCategoryWeight path ----
  # Deduplicate at the group level (.id × aphia × sex × SpeciesCategory) before
  # scaling — TotalNumber and SpeciesCategoryWeight repeat across all length rows
  # within each group, so summing without dedup inflates totals.
  hl_haul <- hl |>
    dplyr::distinct(.id, aphia, sex, SpeciesCategory, SpeciesValidity,
                    TotalNumber, SpeciesCategoryWeight) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::mutate(
      n_haul_raw = dplyr::case_when(
        DataType == "C" ~ TotalNumber           * HaulDuration / 60,
        TRUE            ~ TotalNumber
      ),
      n_hour_raw = dplyr::case_when(
        DataType == "C" ~ TotalNumber,
        TRUE            ~ TotalNumber           / HaulDuration * 60
      ),
      w_haul_raw = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight * HaulDuration / 60,
        TRUE            ~ SpeciesCategoryWeight
      ),
      w_hour_raw = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight,
        TRUE            ~ SpeciesCategoryWeight / HaulDuration * 60
      )
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, SpeciesValidity,
                    StandardSpeciesCode, BycatchSpeciesCode) |>
    dplyr::summarise(
      n_haul = sum(n_haul_raw, na.rm = TRUE),
      n_hour = sum(n_hour_raw, na.rm = TRUE),
      w_haul = sum(w_haul_raw, na.rm = TRUE),
      w_hour = sum(w_hour_raw, na.rm = TRUE),
      n_f    = sum(dplyr::if_else(sex == "F", n_haul_raw, 0), na.rm = TRUE),
      n_m    = sum(dplyr::if_else(sex == "M", n_haul_raw, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      p_females = dplyr::if_else(n_f + n_m > 0, n_f / (n_f + n_m), NA_real_)
    ) |>
    dplyr::select(-n_f, -n_m) |>
    dr_add_species(species) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species,
      n_haul, n_hour, w_haul, w_hour, p_females, SpeciesValidity,
      StandardSpeciesCode, BycatchSpeciesCode
    ) |>
    dplyr::mutate(type = "haul",
                  length_mm = NA_integer_, length_cm = NA_real_, accuracy = NA_real_)

  # ---- bind, align column order ----
  dplyr::union_all(
    dplyr::select(hl_length, .id, Survey, Year, Quarter, aphia, latin, species, type,
                  length_mm, length_cm, accuracy, n_haul, n_hour, w_haul, w_hour,
                  p_females, SpeciesValidity, StandardSpeciesCode, BycatchSpeciesCode),
    dplyr::select(hl_haul,   .id, Survey, Year, Quarter, aphia, latin, species, type,
                  length_mm, length_cm, accuracy, n_haul, n_hour, w_haul, w_hour,
                  p_females, SpeciesValidity, StandardSpeciesCode, BycatchSpeciesCode)
  )
}
