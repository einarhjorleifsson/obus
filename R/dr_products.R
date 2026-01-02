# Check if need to raise by towtime - does not seem to be the case

#' Get catch weights
#'
#' Calculate the total reported catch numbers and weight by species and haul.
#'
#' The functions is supposed to give the same results as icesDatras::getCatchWgt
#' (needs checking), except gives latin (and english) name.
#'
#'
dr_catch_weight <- function() {
  obus::dr_con("HL", trim = FALSE) |>
    dplyr::select(.id, CatIdentifier, TotalNo, CatCatchWgt, latin) |>
    dplyr::distinct() |>
    dplyr::group_by(.id, latin) |>
    dplyr::summarise(n = sum(TotalNo, na.rm = TRUE),
                     b = sum(CatCatchWgt, na.rm = TRUE),
                     .groups = "drop")
}
