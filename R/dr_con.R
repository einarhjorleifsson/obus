#' Establish a DuckDB Connection to DATRAS Datasets
#'
#' This function creates a DuckDB connection to a specified DATRAS dataset type,
#' facilitating access to trawl survey data stored in Parquet format. The
#' dataset type determines which data is loaded from the remote source.
#'
#' @section Dataset Types:
#' This function operates on the following dataset types:
#' - **"HH" (Haul-Level Data)**: Contains information related to individual haul events.
#' - **"HL" (Catch-at-Length Data)**: Records catches categorized by length class.
#' - **"CA" (Catch-at-Age Data)**: Includes age-based biological data (e.g., liver weight, length).
#' - **"species" (Species List)**: Derived from the ICES vocabulary 'SpecWoRMS' and includes species names and related metadata.
#'
#' @section Dataset Paths:
#' The dataset is accessed via HTTP/HTTPS paths at a user-defined or default URL
#' location. The file names are inferred from the provided `type` parameter
#' (e.g., a Parquet file named `"HH.parquet"` for `"HH"` type data).
#'
#' @section Unique Identifier (.id):
#' For dataset types `"HH"`, `"HL"`, and `"CA"`, a unique identifier column (`.id`)
#' represent catenation of fields Survey, Year, Quarter, Country,
#' Platform, Gear, StationName and HaulNumber seperated by ":" (see \code{\link{dr_add_id}}).
#'
#' @param type A character string specifying the dataset type. Available values (tables):
#'   - `"HH"`: Haul-level data.
#'   - `"HL"`: Catch-at-length data (filterable via the `trim` option).
#'   - `"CA"`: Catch-at-age data (filterable via the `trim` option).
#'   - `"species"`: Species dataset derived from ICES SpecWoRMS.
#' @param trim Logical. For `"HL"` or `"CA"`, if `TRUE` (default), non-essential fields are excluded. Ignored for other datasets.
#' @param url URL to the Parquet file directory, currently defaulting to `"https://heima.hafro.is/~einarhj/datras"`.
#' @param quiet Logical. If `TRUE` (default), suppresses connection warnings and messages.
#'
#' @return A DuckDB dataset table.
#'
#' @examples
#' \dontrun{
#'   # Establish connections
#'   dr_con("HH")                   # Connect to haul-level data.
#'   dr_con("HL", trim = FALSE)     # Include all fields for catch-at-length data.
#'   species_data <- dr_con("species")
#'
#'   # Inspect species data
#'   dplyr::glimpse(species_data)
#' }
#' @export
dr_con <- function(type = NULL, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras", quiet = TRUE) {

  # Validate `type` parameter
  valid_types <- c("HH", "HL", "CA", "species", "haul", "dictionary", "vocabulary", "cpuelength")
  if (!type %in% valid_types) {
    stop(sprintf(
      "Invalid type '%s'. Valid types are: %s",
      type, paste(valid_types, collapse = ", ")
    ))
  }

  # Validate and format `url`
  if (!nzchar(url) || !startsWith(url, "http")) {
    stop("Invalid URL. Please provide a valid URL starting with 'http' or 'https'.")
  }
  if (!grepl("/$", url)) {
    url <- paste0(url, "/")
  }
  # Initialize dataset path
  dataset_path <- paste0(url, type, ".parquet")

  # Connect to dataset; let DuckDB surface the error if the URL is unreachable
  q <- tryCatch(
    duckdbfs::open_dataset(dataset_path),
    error = function(e) {
      stop(sprintf(
        "Unable to connect to '%s'. Check the URL or your internet connection.\n  (%s)",
        dataset_path, conditionMessage(e)
      ), call. = FALSE)
    }
  )

  # Helper function for trimming
  trim_data <- function(data, cols) {
    data |>
      dplyr::select(.id, tidyr::all_of(cols))
  }

  # Handle `type`-specific logic
  if (type == "HL" && trim) {
    q <- trim_data(q, c("latin", "length_cm", "SpeciesSex", "DevelopmentStage", "n_haul", "n_hour"))
  }

  if (type == "CA" && trim) {
    q <- trim_data(q, c("latin", "length_cm", "IndividualSex", "LiverWeight"))
  }

  # Warn for ignored `trim` parameter
  if(!quiet) {
    if (type %in% c("HH", "species") && !missing(trim)) {
      warning("'trim' parameter is ignored for 'HH' and 'species' types.")
    }
  }
  # Log connection details (optional debugging)
  if(!quiet) {
    message(sprintf("Successfully connected to the '%s' dataset at: %s", type, dataset_path))
  }

  return(q)
}



#' Connect to Raw ICES DATRAS Tables
#'
#' Opens a lazy DuckDB connection to "as-is" DATRAS parquet files — the raw
#' tables as downloaded from the ICES datacenter, with original old-style column
#' names (e.g. `Ship`, `HaulNo`, `ShootLat`). Use this when you need unmodified
#' ICES output rather than the tidied versions provided by [dr_con()].
#'
#' @param table A character string specifying the table. One of `"HH"` (default),
#'   `"HL"`, `"CA"`, `"FL"`, `"LT"`, `"CPUEL"`, `"CPUEA"`, `"CW"`, or `"IDX"`.
#'
#' @return A lazy `duckdbfs` tibble. Pipe dplyr verbs and call [dplyr::collect()]
#'   to bring data into memory.
#'
#' @examples
#' \dontrun{
#'   dr_con_raw("FL") |> dplyr::glimpse()
#'
#'   dr_con_raw("FL") |>
#'     dplyr::filter(Survey == "NS-IBTS", Year == 2020) |>
#'     dplyr::collect()
#' }
#' @export
dr_con_raw <- function(table = "HH") {

  valid_tables <- c("CA", "CPUEA", "CPUEL", "CW", "FL", "HH", "HL", "IDX", "LT")
  if (!table %in% valid_tables) {
    stop(sprintf(
      "Invalid table '%s'. Valid tables are: %s",
      table, paste(valid_tables, collapse = ", ")
    ))
  }

  url <- paste0("https://heima.hafro.is/~einarhj/datras/old/", table, ".parquet")
  duckdbfs::open_dataset(url)
}

