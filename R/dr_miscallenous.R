#' Generate a haul id
#'
#' @param d A DATRAS table, any of HH, HL or CA
#'
#' @return A table with an additional variable .id
#' @export
#'
dr_add_id <- function(d) {
  d |>
    dplyr::mutate(.id = paste(Survey, Year, Quarter, Country, Ship, Gear,
                              StNo, HaulNo, sep=":"))
}
