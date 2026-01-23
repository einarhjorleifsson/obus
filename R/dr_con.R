#' Create a DuckDB connection to a DATRAS tables
#'
#' This function establishes a DuckDB connection to a DATRAS dataset based on the specified `type` ("HH", "HL", "CA", or "species").
#' The dataset is accessed via a URL and opened using the `duckdbfs::open_dataset` function.
#' The function operates on experimental tables that include Latin names in the "HL" and "CA" files.
#'
#' @section Overview:
#' This function connects to one of the following dataset types:
#' - `"HH"`: Haul-level data.
#' - `"HL"`: Catch-at-length data.
#' - `"CA"`: Age-based biological sampling data.
#' - `"species"`: Species dataset derived from the ICES vocabulary code list 'SpecWoRMS'.
#'
#' Optionally, for the `"HL"` and `"CA"` types, setting `trim = TRUE` (the default) excludes station-level variables.
#' The `"species"` dataset is based on the SpecWoRMS code list and contains columns like `Valid_Aphia` and `latin`.
#'
#' @section .id Variable:
#' For `"HH"`, `"HL"`, and `"CA"` datasets, a unique haul variable (`.id`) is generated to identify hauls within the datasets.
#' The variable is constructed by concatenating fields: `Survey`, `Year`, `Quarter`, `Country`, `Platform`,
#' `Gear`, `StationName`, and `HaulNumber` using ':' as the separator.
#'
#' @section Datapath Explanation:
#' - The function constructs a URL for the dataset based on the following pattern:
#'   `"{url}/{type}.parquet"`.
#' - Users may provide a custom `url` parameter, which must include valid file paths that match the dataset type.
#'
#' @param type A character string specifying the type of dataset. Must be `"HH"`, `"HL"`, `"CA"`, or `"species"`.
#'             This parameter maps to specific files in the provided data source (`url`).
#' @param trim A boolean flag (default `TRUE`). If `TRUE` and the `type` is `"HL"` or `"CA"`,
#'             the dataset is trimmed to ignore station-level fields. Ignored for other dataset types.
#' @param url The http path to the DATRAS parquet files. Defaults to `https://heima.hafro.is/~einarhj/datras_latin`.
#' @param quiet Boolean (default TRUE)
#' @return A DuckDB dataset object.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con("HH")              # Connect to haul-level data.
#'   dr_con("HL", trim = FALSE)  # Get all fields for catch-at-length data.
#'   species <- dr_con("species")  # Connect to the species dataset.
#'   dplyr::glimpse(species)       # Peek at the species dataset.
#' }
dr_con <- function(type = NULL, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras_latin", quiet = TRUE) {

  # Validate `type` parameter
  valid_types <- c("HH", "HL", "CA", "species")
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
