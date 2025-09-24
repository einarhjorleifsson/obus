#' Summarize Data Availability
#'
#' Retrieve a table of available DATRAS survey-year-quarter combinations.
#' This function is a wrapper around \code{icesDatras::getDatrasDataOverview}, returning a tibble rather than a list of matrices.
#'
#' @param surveys A character vector of survey names to process, or \code{NULL} to process all surveys.
#'
#' @return A tibble with columns \code{survey}, \code{year}, and \code{quarter} for available data.
#' @export
dr_getoverview <- function(surveys = NULL) {

  if(is.null(surveys)) {
    o <- icesDatras::getDatrasDataOverview()
  } else {
    o <- icesDatras::getDatrasDataOverview(surveys)
  }

  o |>
    purrr::map(tibble::as_tibble, rownames = "year") |>
    dplyr::bind_rows(.id = "survey") |>
    tidyr::gather(quarter, val, Q1:Q4) |>
    dplyr::filter(val == 1) |>
    dplyr::select(-val) |>
    dplyr::mutate(year = as.integer(year),
                  quarter = stringr::str_remove(quarter, "Q"),
                  quarter = as.integer(quarter)) |>
    dplyr::filter(!survey %in% c("NS-IBTS_UNIFtest", "Test-DATRAS"))
}
