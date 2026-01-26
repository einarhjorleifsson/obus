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
#' is generated to represent combinations of haul-related fields (e.g., Survey,
#' Year, Country, Station Name).
#'
#' @param type A character string specifying the dataset type. Possible values:
#'   - `"HH"`: Haul-level data.
#'   - `"HL"`: Catch-at-length data (filterable via the `trim` option).
#'   - `"CA"`: Catch-at-age data (filterable via the `trim` option).
#'   - `"species"`: Species dataset derived from ICES SpecWoRMS.
#' @param trim Logical. For `"HL"` or `"CA"`, if `TRUE` (default), non-essential fields are excluded. Ignored for other datasets.
#' @param url URL to the Parquet file directory, defaulting to `"https://heima.hafro.is/~einarhj/data/datras"`.
#' @param quiet Logical. If `TRUE` (default), suppresses connection warnings and messages.
#' @return A DuckDB dataset object, representing the selected DATRAS dataset type.
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
dr_con <- function(type = NULL, trim = TRUE, url = "https://heima.hafro.is/~einarhj/data/datras", quiet = TRUE) {

  # Validate `type` parameter
  valid_types <- c("HH", "HL", "CA", "species", "dictionary", "haul")
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

  # Check for internet connection
  # test_internet_connection <- function() {
  #   tryCatch(
  #     {
  #       utils::download.file("http://www.google.com", destfile = tempfile(), quiet = quiet)
  #       TRUE
  #     },
  #     error = function(e) FALSE
  #   )
  # }

  # internet_available <- test_internet_connection()
  # if (!internet_available) {
  #   stop("It seems there is no internet connection. Please check your network settings and try again.")
  # }

  # Check accessibility of dataset URL
  check_url <- function(url) {
    tryCatch(
      {
        httr::HEAD(url)  # Use a HEAD request to ensure the file is accessible without downloading it
        TRUE
      },
      error = function(e) FALSE
    )
  }

  if (!check_url(dataset_path)) {
    stop(sprintf(
      "Unable to connect to the dataset at '%s'. Please verify the URL or check your internet connection.",
      dataset_path
    ))
  }

  # Connect to dataset
  q <- duckdbfs::open_dataset(dataset_path)

  # Helper function for trimming
  trim_data <- function(data, cols) {
    data |>
      dplyr::select(.id, tidyr::all_of(cols))
  }

  # Handle `type`-specific logic
  if (type == "HL" && trim) {
    q <- trim_data(q, c("latin", "length_cm", "SpeciesSex", "DevelopmentStage", "n", "cpue"))
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
