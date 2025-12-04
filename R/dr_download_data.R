#' Download DATRAS tables
#'
#' Each DATRAS table (HH, HL, CA and FL) is downloaded and saved.
#'
#' @param surveys Survey to get, if none specified get all
#' @param years Years to download, if none specified get all from 1990 onwards. Not yet active.
#' @param quarters Quarters to download, if none specified get all from 1990 onwards. Not yet active.
#' @param outpath The path (default 'data') where saved DATRAS exchange files are stored
#' @param filetype File type (default 'parquet'). Currently inactive.
#' '
#' @return Files on disk
#' @export
#'
dr_download_data <- function(surveys = NULL, years = NULL, quarters = NULL, outpath = "data", filetype = "parquet") {


  if(is.null(surveys)) {
    surveys <- c("BITS", "BTS", "BTS-GSA17", "BTS-VIII",
                 "Can-Mar",   "DWS",       "DYFS",      "EVHOE",
                 "FR-CGFS",   "FR-WCGFS",  "IE-IAMS",   "IE-IGFS",
                 "IS-IDPS",   "NIGFS",     "NL-BSAS",   "NS-IBTS",
                 "NS-IDPS",   "NSSS",      "PT-IBTS",   "ROCKALL",
                 "SCOROC",    "SCOWCGFS",  "SE-SOUND",  "SNS",
                 "SP-ARSA",   "SP-NORTH",  "SP-PORC",   "SWC-IBTS")
  }
  if(is.null(years)) years <- 1965:2028
  if(is.null(quarters)) quarters <- 1:4

  for(i in 1:length(surveys)) {

    hh <-
      dr_getHH(surveys[i], years, quarters)
    if(nrow(hh) >= 1) {
      hh |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    hl <-
      dr_getHL(surveys[i], years, quarters)
    if(nrow(hl) >= 1) {
      hl |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    ca <- dr_getCA(surveys[i], years, quarters)
    if(nrow(ca) >= 1) {
      ca |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    # fl <- dr_getFL(surveys[i], years, quarters)
    # if(nrow(fl) >= 1) {
    #   fl |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    # }
  }
}



#' Get DATRAS tables with latin names
#'
#' @param recordtype Any of HH, HL or CA
#' @param survey Name of the survey, e.g. "ROCKALL"
#' @param year A text string, like "1999:2009"
#' @param quarters A text string, like "1:4"
#' '
#' @return A tibble
#' @export
#'
dr_get_data_latin <- function(recordtype, survey, year, quarter) {

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


  message("Downloading from: ", full_url)
  download.file(full_url, destfile = temp_zip, mode = "wb", quiet = TRUE)

  # ---- Unzip ----
  message("Unzipping...")
  unzip(temp_zip, exdir = temp_dir)

  # Find CSV file
  csv_file <- list.files(temp_dir, pattern = "Table\\.csv$", full.names = TRUE)

  if (length(csv_file) == 0) {
    stop("No table.csv found inside the ZIP file.")
  }

  # ---- Read CSV ----
  message("Reading table.csv into dataframe...")
  df <- read.csv(csv_file[1], stringsAsFactors = FALSE)

  # ---- Clean up ----
  unlink(temp_zip)

  message("Done! Returning dataframe.")
  return(df)
}

