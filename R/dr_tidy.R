#' Tidy DATRAS data
#'
#' Cleans and formats a DATRAS data table by dispatching to table-specific tidying functions.
#' For station tables (HH), optionally returns only valid hauls (\code{haulval == "V"}).
#'
#' @param d A duckdb-table connection or a tibble containing DATRAS data.
#' @param valid_hauls Logical; if \code{TRUE} (default), only records with \code{haulval == "V"} are retained in station tables (HH).
#'
#' @return A duckdb-table connection or a tibble with tidied DATRAS data.
#' @export
dr_tidy <- function(d, valid_hauls = TRUE) {

  d <-
    d |>
    dplyr::rename_all(tolower)

  type <- d |> dplyr::filter(dplyr::row_number() == 1) |> dplyr::pull(recordtype)

  if(type == "HH") d <- d |> dr_tidyhh(valid_hauls)
  if(type == "HL") d <- d |> dr_tidyhl()
  if(type == "CA") d <- d |> dr_tidyca()
  if(type == "FL") d <- d |> dr_tidyfl()

  return(d)

}

#' Tidy DATRAS station (HH) data
#'
#' Filters and formats station (HH) data, optionally retaining only valid hauls (\code{haulval == "V"}).
#'
#' @param d A duckdb-table connection or a tibble containing HH data.
#' @param valid_hauls Logical; if \code{TRUE} (default), only valid hauls are retained.
#'
#' @return A duckdb-table connection or a tibble with tidied HH data.
#' @export
dr_tidyhh <- function(d, valid_hauls = TRUE) {

  if(valid_hauls) {
    d <-
      d |>
      dplyr::filter(haulval == "V")
  }

  return(d)

}

#' Tidy DATRAS length (HL) data
#'
#' Cleans and formats length (HL) data, removing records with missing length class or numbers, converting length units, applying subfactors, and finalizing aphia codes.
#'
#' @param d A duckdb-table connection or a tibble containing HL data.
#'
#' @return A duckdb-table connection or a tibble with tidied HL data.
#' @export
dr_tidyhl <- function(d) {

  d <-
    d |>

    # Remove records without lengthclass or without numbers at length
    dplyr::filter(!is.na(lngtclass), !is.na(hlnoatlngt) ) |>

    # Length class to cm
    dplyr::mutate(length     = ifelse(lngtcode %in% c(".", "0"), lngtclass / 10, lngtclass)) |>

    # Apply subfactor
    dplyr::mutate(subfactor = ifelse(is.na(subfactor),1, subfactor)) |>
    dplyr::mutate(hlnoatlngt = hlnoatlngt * subfactor) |>

    # Finalize aphia
    dplyr::mutate(
      aphia =
        dplyr::case_when(
          !is.na(valid_aphia) & valid_aphia != "0" ~ valid_aphia,
          speccodetype                      == "W" ~ speccode,
          TRUE                                     ~ NA_character_),
      aphia = as.integer(aphia),
      year = as.integer(year))

  return(d)

}

#' Tidy DATRAS age (CA) data
#'
#' Cleans and formats age (CA) data, converting length units, setting weights, and finalizing aphia codes.
#'
#' @param d A duckdb-table connection or a tibble containing CA data.
#'
#' @return A duckdb-table connection or a tibble with tidied CA data.
#' @export
dr_tidyca <- function(d) {

  d <-
    d |>
    # Turn everything to cm, adjust weights, finalize aphia
    dplyr::mutate(
      length = ifelse(lngtcode %in% c(".", "0"), lngtclass / 10, lngtclass),
      indwgt = ifelse(indwgt <= 0, NA, indwgt),
      aphia = dplyr::case_when(!is.na(valid_aphia) & valid_aphia != "0" ~ valid_aphia,
                               speccodetype == "W" ~ speccode,
                               TRUE ~ NA_character_),
      aphia = as.integer(aphia),
      year = as.integer(year))

  return(d)

}

#' Tidy DATRAS flex (FL) data
#'
#' Returns flex (FL) data unchanged. Placeholder for future flex table tidying logic.
#'
#' @param d A duckdb-table connection or a tibble containing FL data.
#'
#' @return A duckdb-table connection or a tibble with (unchanged) FL data.
#' @export
dr_tidyfl <- function(d) {

  return(d)

}
