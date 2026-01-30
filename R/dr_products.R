#' Get numbers and weights summary of species by haul
#'
#' This function calculates and summarizes the total numbers and weights of species reported in a survey.
#' By processing fishing haul-level (HH) and catch-level (HL) data, it generates the aggregate number (`n_haul`) and
#' weight (`w_haul`) of species caught per haul, alongside estimates standardized to a 1-hour haul duration (`n_hour`, `w_hour`).
#'
#' The final output is a summary by haul identifiers and species, enabling an overview of catch numbers
#' and weights. Additionally, the function aims to provide similar weight calculations as `icesDatras::getCatchWgt`,
#' making its results comparable to external references.
#'
#' @param trim Boolean (default TRUE), controls if additional non-essential variables are returned or not.
#' @return
#' A summarized `data.frame` with the following columns:
#' - `.id`: Unique haul identifier.
#' - `latin`: Latin species name, identifying the species.
#' - `n_haul`: Actual number of individuals per haul.
#' - `w_haul`: Actual weight (kg) per haul.
#' - `n_hour`: Number of individuals raised to a 1-hour haul.
#' - `w_hour`: Weight (kg) raised to a 1-hour haul.
#'
#' If trim is FALSE then additional variables return
#' - `TotalNumber`: Total number of individuals of the species caught - nonstandardized.
#' - `SpeciesCategoryWeight`: Total weight (kg) of the species caught - nonstandardized.
#' - `DataType`: Type of data recording, if value is "C", SpeciesCategoryWeight is in unit per 60 minute hauling, otherwise unit is in reported haul ducation.
#' - `HaulDuration`: Type of data collected, e.g., raised to 1 hour or raw.
#'
#' @note
#'
#' ".id" are variables Survey, Year, Quarter, Country, Platform, Gear, StationName and HaulNumber catenated, separated by ":".
#'
#' @seealso
#' \code{icesDatras::getCatchWgt} for an alternative approach to computing total catch weight by species and haul.
#'
#' \code{\link{dr_con}} for information about connecting to DuckDB tables.
#'
#' @export

dr_con_by_haul <- function(trim = TRUE) {

  q <-
    dr_con("HH", trim = FALSE) |>
    dplyr::select(.id, Survey, Year, Quarter, DataType, HaulDuration) |>
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

  if(trim == TRUE) {
    q <-
      q |>
      dplyr::select(.id, latin, n_haul, w_haul, n_hour, w_hour)
  } else {
    q <-
      q |>
      dplyr::select(.id, latin, n_haul, w_haul, n_hour, w_hour, SpeciesCategoryWeight,
                    DataType, HaulDuration)
  }

  # q <-
  #   q |>
  #   dplyr::compute()

  return(q)
}


