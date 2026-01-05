#' Get catch weights
#'
#' Calculate the total reported catch numbers and weight by species and haul.
#'
#' The functions is supposed to give the same results as icesDatras::getCatchWgt.
#' If argument "not_numbers" is set to FALSE this may though not hold true.
#'
#' @param latin Latin species name
#' @param not_numbers A boolean (default TRUE), indicating if total abundance
#' (TotalNo) should also be calculated
#'
#' @return A DuckDB view
#'
#' @export

dr_catch_weight <- function(latin, not_numbers = TRUE) {

  if(not_numbers == TRUE) {
    q <-
      dr_con("HH", trim = FALSE) |>
      dplyr::mutate(latin = local(latin)) |>
      dplyr::select(Survey, Year, Quarter, .id, latin) |>
      dplyr::left_join(dr_con("HL", trim = FALSE) |>
                         dplyr::select(.id, CatIdentifier,
                                       # TotalNo,
                                       CatCatchWgt, latin) |>
                         dplyr::distinct() |>
                         dplyr::group_by(.id, latin) |>
                         # Missing values are always removed in SQL aggregation functions
                         dplyr::summarise(
                           #n = dplyr::case_when(
                           #  n() != sum(!is.na(TotalNo), na.rm = TRUE) ~ -9,  # Return NA if any value is missing
                           # TRUE ~ sum(TotalNo, na.rm = TRUE)),              # Otherwise calculate the sum
                           b = dplyr::case_when(
                             n() != sum(!is.na(CatCatchWgt), na.rm = TRUE) ~ -9,
                             TRUE ~ sum(CatCatchWgt, na.rm = TRUE)),
                           .groups = "drop"),
                       by = dplyr::join_by(.id, latin)) |>
      dplyr::mutate(#n = dplyr::coalesce(n, 0),
        b = dplyr::coalesce(b, 0),
        #n = ifelse(n == -9, NA, n),
        b = ifelse(b == -9, NA, b))
  } else {
    q <-
      dr_con("HH", trim = FALSE) |>
      dplyr::mutate(latin = local(latin)) |>
      dplyr::select(Survey, Year, Quarter, .id, latin) |>
      dplyr::left_join(obus::dr_con("HL", trim = FALSE) |>
                         dplyr::select(.id, CatIdentifier,
                                       TotalNo,
                                       CatCatchWgt, latin) |>
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
  return(q)
}
