
#' Create a DuckDB connection to a DATRAS tables
#'
#' This function establishes a DuckDB connection to a DATRAS dataset based on the specified `type` ("HH", "HL" or "CA").
#' The dataset is accessed via a URL and opened using the `duckdbfs::open_dataset` function.
#' The function operates on experimental tables that include Latin names in the "HL" and "CA" files.
#'
#' # Datapath Explanation
#' The function constructs a URL for the dataset based on the following pattern:
#' "https://heima.hafro.is/~einarhj/datras/`{type}`.parquet".
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
#' @param add_species A boolean flag (default `TRUE`). If `TRUE` and the `type` is `"HL"` or `"CA"`,
#'             variable latin and species is added to the output table.
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
dr_con <- function(type = NULL, add_species = TRUE, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras/") {

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

  if(type == "HL") {

    if(add_species == TRUE) {
      q <-
        q |>
        dplyr::left_join(dr_con_latin(),
                       by = dplyr::join_by(Valid_Aphia))
    }

    if(trim == TRUE & add_species == TRUE) {
      q <-
        q |>
        dplyr::left_join(dr_con_latin()) |>
        dplyr::select(.id, latin, length, Sex, DevStage, n, cpue, species)
    }

    if(trim == TRUE & add_species == FALSE) {
      q <-
        q |>
        dplyr::select(.id, Valid_Aphia, length, Sex, DevStage, n, cpue)
    }
  }

  if(type == "CA") {
    if(add_species == TRUE) {
      q <-
        q |>
        dplyr::left_join(dr_con_latin(),
                         by = dplyr::join_by(Valid_Aphia))
    }
    if(trim == TRUE & add_species == TRUE) {
      q <-
        q |>
        dplyr::left_join(dr_con_latin()) |>
        dplyr::select(.id, latin, length, Sex:MaturityScale, species)
    }

    if(trim == TRUE & add_species == FALSE) {
      q <-
        q |>
        dplyr::left_join(dr_con_latin()) |>
        dplyr::select(.id, Valid_Aphia, length, Sex:MaturityScale)
    }
  }

  return(q)
}

#' Connect to the Species WoRMS Dataset
#'
#' This function provides a connection to the 'species_worms' dataset stored in a Parquet file.
#' The dataset was created based on the ICES vocabulary code list 'SpecWoRMS'.
#'
#' @details
#' The parquet file was generated from the ICES vocabulary code list "SpecWoRMS" with the following steps:
#' - The code list is obtained using `icesVocab::getCodeList("SpecWoRMS")`.
#' - It is processed to contain two columns: `Valid_Aphia` (integer) and `latin` (scientific name).
#' - The resulting data is written as a Parquet file
#'
#' Path to the Parquet file: [https://heima.hafro.is/~einarhj/datras/species_worms.parquet](https://heima.hafro.is/~einarhj/datras/species_worms.parquet)
#'
#' @return
#' A `duckdbfs` dataset object pointing to the Parquet file.
#'
#' @examples
#' # Example of connecting to the species dataset
#' latin <- dr_con_latin()
#' dplyr::glimpse(latin)  # Peek at the dataset
#'
#' @export
dr_con_latin <- function() {
  url = "https://heima.hafro.is/~einarhj/datras/"
  paste0(url, "species_worms.parquet") |>
    duckdbfs::open_dataset()
}

