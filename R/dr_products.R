#' Get catch weights
#'
#' Calculate the total reported catch numbers and weight by species and haul.
#'
#' The functions is supposed to give the same results as icesDatras::getCatchWgt
#' (needs checking).
#'
#' @param latin Latin species name
#'
#' @return A DuckDB view
#'
#' @export

dr_catch_weight <- function(latin) {

  dr_con("HH", trim = FALSE) |>
    dplyr::mutate(latin = local(latin)) |>
    dplyr::select(Survey, Year, Quarter, .id, latin) |>
    dplyr::left_join(obus::dr_con("HL", trim = FALSE) |>
                       dplyr::select(.id, CatIdentifier, TotalNo, CatCatchWgt, latin) |>
                       dplyr::distinct() |>
                       dplyr::group_by(.id, latin) |>
                       # Missing values are always removed in SQL aggregation functions
                       dplyr::summarise(
                         n = dplyr::case_when(
                           n() != sum(!is.na(TotalNo), na.rm = TRUE) ~ -9,  # Return NA if any value is missing
                           TRUE ~ sum(TotalNo, na.rm = TRUE)),              # Otherwise calculate the sum
                         b = dplyr::case_when(
                           n() != sum(!is.na(CatCatchWgt), na.rm = TRUE) ~ -9,
                           TRUE ~ sum(CatCatchWgt, na.rm = TRUE)),
                         .groups = "drop"),
                     by = dplyr::join_by(.id, latin)) |>
    dplyr::mutate(n = dplyr::coalesce(n, 0),
                  b = dplyr::coalesce(b, 0),
                  n = ifelse(n == -9, NA, n),
                  b = ifelse(b == -9, NA, b))
}
