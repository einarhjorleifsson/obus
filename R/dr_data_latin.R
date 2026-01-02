#' Get DATRAS tables with latin names
#'
#' @param recordtype Any of HH, HL, CA or all
#' @param survey Name of the survey, e.g. "ROCKALL"
#' @param year A text string, like "1999:2009"
#' @param quarter A text string, like "1:4"
#' @param quiet A boolean (default TRUE) - suppress messages
#' '
#' @return A tibble
#' @export
#'
dr_get_data_latin <- function(recordtype, survey, year, quarter, quiet = TRUE) {

  # Store original timeout setting
  original_timeout <- getOption("timeout")
  # Temporarily increase timeout just for this function's scope
  options(timeout = 600)
  # This gives a 10-minute timeout - if you have a slow internet connection you might need to increase this
  # Use on.exit to ensure the original timeout value is restored even if the function errors
  on.exit(options(timeout = original_timeout))

  base_url <- "https://datras.ices.dk/Data_products/Download/GetDATRAS.aspx"
  full_url <- paste0(
    base_url,
    "?recordtype=", recordtype,
    "&survey=", survey,
    "&year=", year,
    "&quarter=", quarter
  )

  temp_zip <- tempfile(fileext = ".zip")
  temp_dir <- tempdir()


  if(!quiet) message("Downloading from: ", full_url)
  utils::download.file(full_url, destfile = temp_zip, mode = "wb", quiet = TRUE)

  # ---- Unzip ----
  if(!quiet) message("Unzipping...")
  # Gives warning message, "error 1 in extracting from zip file"
  suppressWarnings(utils::unzip(temp_zip, exdir = temp_dir))

  # Find CSV file
  csv_file <- list.files(temp_dir, pattern = "Table\\.csv$", full.names = TRUE)

  if (length(csv_file) == 0) {
    stop("No table.csv found inside the ZIP file.")
  }

  if (length(csv_file) > 1) {
    stop("More than one table.csv found inside the ZIP file.")
  }

  # ---- Read CSV ----
  if(!quiet) message("Reading table.csv into dataframe...")
  df <- utils::read.csv(csv_file[1], stringsAsFactors = FALSE)

  # ---- Clean up ----
  unlink(temp_zip)

  if(!quiet) message("Done! Returning dataframe.")
  return(df)
}


#' Download DATRAS latin tables
#'
#' Each DATRAS latin table (HH, HL, CA) is downloaded and saved.
#'
#' @param surveys Survey to get, if none specified get all
#' @param years Years to download, if none specified attempt to download all
#' @param quarters Quarters to download, if none specified attempt to download all
#' @param outpath The path (default 'data') where saved DATRAS exchange files are stored
#' @param filetype File type (default 'parquet'). Currently inactive.
#' '
#' @return Files on disk
#' @export
#'
dr_download_data_latin <- function(surveys = NULL, years = NULL, quarters = NULL, outpath = "data", filetype = "parquet") {


  if(is.null(surveys)) {
    surveys <- c("BITS", "BTS", "BTS-GSA17", "BTS-VIII",
                 "Can-Mar",   "DWS",       "DYFS",      "EVHOE",
                 "FR-CGFS",   "FR-WCGFS",  "IE-IAMS",   "IE-IGFS",
                 "IS-IDPS",   "NIGFS",     "NL-BSAS",   "NS-IBTS",
                 "NS-IDPS",   "NSSS",      "PT-IBTS",   "ROCKALL",
                 "SCOROC",    "SCOWCGFS",  "SE-SOUND",  "SNS",
                 "SP-ARSA",   "SP-NORTH",  "SP-PORC",   "SWC-IBTS")
  }
  if(is.null(years)) years <- "1965:2030"
  if(is.null(quarters)) quarters <- "1:4"

  # Need check on years and surveys

  for(i in 1:length(surveys)) {

    hh <-
      dr_get_data_latin("HH", surveys[i], years, quarters, quiet = TRUE) |>
      dr_settypes()
    if(nrow(hh) >= 1) {
      hh |>
        dplyr::group_by(RecordType, Survey) |>
        duckdbfs::write_dataset(path = outpath)
    }

    hl <-
      dr_get_data_latin("HL", surveys[i], years, quarters, quiet = TRUE) |>
      dr_settypes()
    if(nrow(hl) >= 1) {
      hl |>
        dplyr::group_by(RecordType, Survey) |>
        duckdbfs::write_dataset(path = outpath) |>
        dr_settypes()
    }

    ca <-
      dr_get_data_latin("CA", surveys[i], years, quarters, quiet = TRUE) |>
      dr_settypes()
    if(nrow(ca) >= 1) {
      ca |>
        dplyr::group_by(RecordType, Survey) |>
        duckdbfs::write_dataset(path = outpath)
    }

  }
}
