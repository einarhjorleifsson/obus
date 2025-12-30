
#' Create a DuckDB connection to a DATRAS Exchange dataset with Latin names included
#'
#' This function establishes a DuckDB connection to a DATRAS dataset based on the specified `type` ("HH", "HL" or "CA").
#' The dataset is accessed via a URL and opened using the `duckdbfs::open_dataset` function.
#' The function operates on experimental tables that include Latin names in the "HL" and "CA" files.
#'
#' # Datapath Explanation
#' The function constructs a URL for the dataset based on the following pattern:
#' "https://heima.hafro.is/~einarhj/datras_latin/`{type}`.parquet".
#' The `type` parameter determines the specific file to connect to, where:
#' - `"HH"` refers to haul-level data.
#' - `"HL"` refers to catch-at-length data.
#' - `"CA"` refers to age-based biological sampling data.
#'
#' Optionally, for the "HL" and "CA" types, setting `trim = TRUE` (the default) excludes station-level variables.
#' This allows a narrower view (read: fewer variables) of these observations, station-level variables can be retrieved
#' by a join to the haul table (HH) using the `.id` column.
#'
#' @param type A character string specifying the type of dataset. Must be `"HH"`, `"HL"`, or `"CA"`.
#'             This parameter maps to specific files in the provided data source.
#' @param trim A boolean flag (default `TRUE`). If `TRUE` and the `type` is `"HL"` or `"CA"`,
#'             the dataset is trimmed to ignore station-level fields.
#' @param url The http path to the DATRAS parquet files
#' @return A DuckDB dataset object.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con("HH")              # Connect to haul-level data.
#'   dr_con("HL", trim=FALSE)  # Get all fields for catch-at-length data.
#' }
dr_con <- function(type = NULL, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras_latin/") {

  if (!type %in% c("HH", "HL", "CA")) {
    stop('Invalid type. Please provide one of the following: "HH", "HL", "CA".')
  }
  if(grepl("/$", url) == FALSE) {
    url <- paste0(url, "/")
  }

  q <-
    paste0(url,
           type,
           ".parquet") |>
    duckdbfs::open_dataset()

  if(trim == TRUE & type %in% c("HL", "CA")) {
    q <-
      q |>
      dplyr::select(.id, SpecCodeType:DateofCalculation)
  }

  if(type == "HL") {
    q <-
      q |>
      dplyr::left_join(dr_con("HH") |>
                         dplyr::select(.id, DataType, HaulDur),
                       by = dplyr::join_by(.id)) |>
      .dr_length_cm() |>
      .dr_n_and_cpue() |>
      dplyr::select(-c(DataType, HaulDur))
  }

  if(type == "CA") {
    q <-
      q |>
      .dr_length_cm()
  }

  return(q)
}

#' Create a DuckDB connection to a DATRAS dataset (exchange format)
#'
#' This function establishes a DuckDB connection to DATRAS exchange-format data based on the specified `type`.
#' The dataset is accessed via a URL and opened using the `duckdbfs::open_dataset` function.
#'
#' # Datapath Explanation
#' The function constructs a URL for the dataset as:
#' "https://heima.hafro.is/~einarhj/datras/RecordType=`{type}`/Year=`{year}`/part-0.parquet".
#' The `type` parameter determines the file category (e.g., "HH", "HL", "CA").
#' The function dynamically generates URLs for all years between 1965 and 2025.
#' The DATRAS exchange dataset includes the following:
#' - `"HH"` refers to haul-level data.
#' - `"HL"` refers to catch-at-length data.
#' - `"CA"` refers to age-based biological sampling data.
#'
#' @param type A character string specifying the type of dataset. Must be `"HH"`, `"HL"`, or `"CA"`.
#'             This parameter maps to specific file types stored in the DATRAS data source.
#' @param url The http path to the DATRAS parquet files
#'
#' @return A DuckDB dataset object representing the combined data for the specified `type`.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con_exchange("HH")  # Connect to haul-level data for all years.
#'   dr_con_exchange("CA")  # Connect to age-based biological data for all years.
#' }
dr_con_exchange <- function(type = NULL, url = "https://heima.hafro.is/~einarhj/datras/") {
  if (!type %in% c("HH", "HL", "CA")) {
    stop('Invalid type. Please provide one of the following: "HH", "HL", "CA".')
  }
  if(grepl("/$", url) == FALSE) {
    url <- paste0(url, "/")
  }

  q <-
    paste0(url,
           type,
           ".parquet") |>
    duckdbfs::open_dataset()

  return(q)
}
