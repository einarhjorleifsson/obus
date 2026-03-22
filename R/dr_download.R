#' Download DATRAS parquet files
#'
#' Downloads HH, HL, and CA parquet files
#'
#' @param recordtype Character. Base directory where parquet files will be written.
#' @param url path, default "https://heima.hafro.is/~einarhj/datras"
#' @param dest_directory path local storage directory (default "data")
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
#' @export
dr_download <- function(recordtype = c("HH", "HL", "CA"),
                        url = "https://heima.hafro.is/~einarhj/datras",
                        dest_directory = "data") {
  fil <- paste0(recordtype, ".parquet")
  for(i in seq_along(fil)) {
    utils::download.file(file.path(url, fil[i]), destfile = file.path(dest_directory, fil[i]))
  }

  invisible(NULL)

}

#' Download and process DATRAS data to parquet files
#'
#' Downloads raw HH, HL, and CA records from the DATRAS API, applies standard
#' tidying and transformations, and writes the results as parquet files.
#' Processed data is written to `<path>/`. Optionally, unprocessed data can
#' also be saved to `<path>/raw/`.
#'
#' @param path Character. Base directory where parquet files will be written.
#' @param save_raw Logical. If `TRUE`, saves the unprocessed data to
#'   `<path>/raw/` before tidying. Default is `FALSE`.
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
.dr_download <- function(path, save_raw = FALSE) {

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # Download raw data ------------------------------------------------------------
  hh <- dr_get("HH", from = "new")
  hl <- dr_get("HL", from = "new")
  ca <- dr_get("CA", from = "new")

  if (save_raw) {
    path_raw <- file.path(path, "raw")
    dir.create(path_raw, recursive = TRUE, showWarnings = FALSE)
    duckdbfs::write_dataset(hh, file.path(path_raw, "HH.parquet"))
    duckdbfs::write_dataset(hl, file.path(path_raw, "HL.parquet"))
    duckdbfs::write_dataset(ca, file.path(path_raw, "CA.parquet"))
  }

  # Tidy and transform HH -------------------------------------------------------
  hh[hh == "-9"] <- NA
  hh <-
    hh |>
    filter_out(StationName == "999" & HaulNumber == 999) |>
    dr_add_id() |>
    dplyr::mutate(sur = paste0(Survey, "-", Quarter)) |>
    dr_add_date() |>
    dr_add_starttime()

  duckdbfs::write_dataset(hh, file.path(path, "HH.parquet"))

  # Tidy and transform HL -------------------------------------------------------
  hl[hl == "-9"] <- NA
  hl <-
    hl |>
    filter_out(StationName == "999" & HaulNumber == 999) |>
    dr_add_id() |>
    dplyr::left_join(hh |> dplyr::select(.id, DataType, HaulDuration)) |>
    dplyr::mutate(sur = paste0(Survey, "-", Quarter)) |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    dplyr::left_join(dr_latin_aphia,
                     by = dplyr::join_by(ValidAphiaID == Valid_Aphia))

  duckdbfs::write_dataset(hl, file.path(path, "HL.parquet"))

  # Tidy and transform CA -------------------------------------------------------
  ca[ca == "-9"] <- NA
  ca <-
    ca |>
    filter_out(StationName == "999" & HaulNumber == 999) |>
    dr_add_id() |>
    dplyr::mutate(sur = paste0(Survey, "-", Quarter)) |>
    dr_add_length_cm() |>
    dplyr::left_join(dr_latin_aphia,
                     by = dplyr::join_by(ValidAphiaID == Valid_Aphia))

  duckdbfs::write_dataset(ca, file.path(path, "CA.parquet"))

  invisible(NULL)

}
