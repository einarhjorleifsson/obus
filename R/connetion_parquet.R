#' Create a DuckDB connection to a DATRAS dataset (latin names included)
#'
#' This function creates a URL for a DATRAS dataset based on the input `type` and opens the dataset
#' using the `duckdbfs::open_dataset` function. The type must be one of "HH", "HL", or "CA".
#'
#' The connection is to an experimental table setup that includes latin name in the HL and CA files
#'
#' @param type A character string specifying the type of the dataset. Must be one of "HH", "HL", or "CA".
#' @param trim A boolean (default TRUE) which removes station variables from the HL and CA data, the join
#' be made via the ".id" variable.
#' @return A DuckDB dataset object.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con("HH")
#' }
dr_con <- function(type = NULL, trim = TRUE) {
  if (!type %in% c("HH", "HL", "CA")) {
    stop('Invalid type. Please provide one of the following: "HH", "HL", "CA".')
  }

  q <-
    paste0("https://heima.hafro.is/~einarhj/datras_latin/",
         type,
         ".parquet") |>
    duckdbfs::open_dataset()

  if(trim == TRUE & type %in% c("HL", "CA")) {
    q <-
      q |>
      dplyr::select(.id, SpecCodeType:DateofCalculation)
  }

  return(q)

}

#' Create a DuckDB connection to a DATRAS dataset (exchange format)
#'
#' This function creates a URL for a DATRAS eschange dataset based on the input `type` and opens the dataset
#' using the `duckdbfs::open_dataset` function. The type must be one of "HH", "HL", or "CA".
#'
#'
#' @param type A character string specifying the type of the dataset. Must be one of "HH", "HL", or "CA".
#' @return A DuckDB dataset object.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con_exchange("HH")
#' }
dr_con_exchange <- function(type = NULL) {
  if (!type %in% c("HH", "HL", "CA")) {
    stop('Invalid type. Please provide one of the following: "HH", "HL", "CA".')
  }

  paste0("https://heima.hafro.is/~einarhj/datras/RecordType=",
         type,
         "/Year=",
         1965:2025,
         "/part-0.parquet") |>
    duckdbfs::open_dataset()
}
