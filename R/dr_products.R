#' Get numbers and weights summary of species by haul
#'
#' This function calculates and summarizes the total numbers and weights of species reported in a survey.
#' By processing fishing haul-level (HH) and catch-level (HL) data, it generates the aggregate number (`n_haul`) and
#' weight (`w_haul`) of species caught per haul, alongside estimates standardized to a 1-hour haul duration (`n_hour`, `w_hour`).
#'
#' The final output is a grouped summary by haul identifiers and species, enabling an overview of catch numbers
#' and weights. Additionally, the function aims to provide similar weight calculations as `icesDatras::getCatchWgt`,
#' making its results comparable to external references.
#'
#' @return
#' A summarized `data.frame` with the following columns:
#' - `.id`: Unique haul identifier.
#' - `DataType`: Type of data collected, e.g., raised to 1 hour or raw.
#' - `latin`: Latin species name, identifying the species.
#' - `TotalNumber`: Total number of individuals of the species caught - nonstandardized.
#' - `SpeciesCategoryWeight`: Total weight (kg) of the species caught - nonstandardized.
#' - `n_haul`: Actual number of individuals per haul.
#' - `w_haul`: Actual weight (kg) per haul.
#' - `n_hour`: Number of individuals raised to a 1-hour haul.
#' - `w_hour`: Weight (kg) raised to a 1-hour haul.
#'
#' @note
#' This function assumes the following:
#' - `HH` and `HL` are loaded as DuckDB views or data.frames in memory.
#' - `.id` is a unique haul identifier that is present in both `HH` and `HL` tables for joining.
#' - `HaulDuration` is recorded in minutes.
#'
#' If the DataType in `Hh` is "C", the total number and weight in the haul are scaled by haul duration (in minutes)
#' to enable sensible comparisons across hauls of different durations.
#'
#' @seealso
#' \code{icesDatras::getCatchWgt} for an alternative approach to computing total catch weight by species and haul.
#'
#' \code{\link{dr_con}} for information about connecting to DuckDB tables.
#'
#' @export

dr_get_by_haul <- function() {

  # make checks: hh and hl have both to be NULL or data.frames

  q <-
    dr_con("HH", trim = FALSE) |>
    dplyr::select(.id, Survey, Year, Quarter, .id, DataType, HaulDuration) |>
    dplyr::left_join(dr_con("HL", trim = FALSE) |>
                       dplyr::select(.id, latin, SpeciesSex, DevelopmentStage, TotalNumber, SpeciesCategoryWeight,
                                     SpeciesCategory),
                     by = dplyr::join_by(.id)) |>
    dplyr::distinct() |>
    dplyr::mutate(n_haul = dplyr::case_when(DataType == "C" ~ TotalNumber / 60 * HaulDuration,
                                            .default = TotalNumber),
                  w_haul = dplyr::case_when(DataType == "C" ~ SpeciesCategoryWeight / 60 * HaulDuration,
                                            .default = SpeciesCategoryWeight)) |>
    # DataType here returned as an extra information variable
    dplyr::group_by(.id, DataType, HaulDuration, latin) |>
    dplyr::summarise(TotalNumber = sum(TotalNumber, na.rm = TRUE),
                     SpeciesCategoryWeight = sum(SpeciesCategoryWeight, na.rm = TRUE),
                     n_haul = sum(n_haul, na.rm = TRUE),
                     w_haul = sum(w_haul, na.rm = TRUE),
                     n_hour = sum(n_haul / HaulDuration * 60, na.rm = TRUE),
                     w_hour = sum(w_haul / HaulDuration * 60, na.rm = TRUE),
                     .groups = "drop")
  return(q)
}


