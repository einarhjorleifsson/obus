#' Connect to DATRAS Parquet Files
#'
#' Opens a lazy DuckDB connection to a DATRAS parquet file hosted on the
#' obus server. An HTTP HEAD request is made before opening the dataset to
#' give a clear error if the file is absent or the server is unreachable.
#'
#' @param type A character string specifying the table. One of `"HH"`, `"HL"`,
#'   `"CA"`, `"FL"`, `"LT"`, `"CPUEL"`, `"CPUEA"`, `"CW"`, `"IDX"`, `"species"`,
#'   `"by_length"` (CPUE per length class per haul, from `.dr_cpue_by_length()`),
#'   or `"by_haul"` (haul-level catch totals, from `.dr_cpue_by_haul()`).
#' @param url Base URL of the parquet directory.
#' @param quiet Logical. If `TRUE` (default), suppresses messages.
#'
#' @return A lazy `tbl_duckdb_connection`. Pipe dplyr verbs and call
#'   [dplyr::collect()] to bring data into memory.
#'
#' @examples
#' \dontrun{
#'   dr_con("HH")
#'   dr_con("HL") |> dplyr::filter(Survey == "NS-IBTS", Year == 2023) |> dplyr::collect()
#' }
#' @export
dr_con <- function(type, url = "https://heima.hafro.is/~einarhj/datras", quiet = TRUE) {

  valid_types <- c("HH", "HL", "CA", "FL", "LT", "CPUEL", "CPUEA", "CW", "IDX", "species",
                   "by_length", "by_haul")

  if (!type %in% valid_types) {
    stop(sprintf("Invalid type '%s'. Valid types are: %s",
                 type, paste(valid_types, collapse = ", ")), call. = FALSE)
  }

  url  <- sub("/$", "", url)
  path <- paste0(url, "/", type, ".parquet")

  ok <- tryCatch({
    resp <- httr2::request(path) |>
      httr2::req_method("HEAD") |>
      httr2::req_perform()
    httr2::resp_status(resp) < 400
  }, error = function(e) FALSE)

  if (!ok) stop(sprintf("'%s' not found or server unreachable.", path), call. = FALSE)

  if (!quiet) message(sprintf("Connected to '%s'", path))

  duckdbfs::open_dataset(path)
}


#' Connect to DATRAS Parquet Files
#'
#' Opens a lazy DuckDB connection to a DATRAS parquet file hosted on the
#' obus server. An HTTP HEAD request is made before opening the dataset to
#' give a clear error if the file is absent or the server is unreachable.
#'
#' @param type A character string specifying the table. One of `"HH"`, `"HL2"`,
#'   `"CA2"`.
#' @param url Base URL of the parquet directory.
#' @param trim Logical. If `TRUE` (default), returns only essential columns
#' @param quiet Logical.  If `TRUE` (default), suppresses messages.
#'
#' @return A lazy `tbl_duckdb_connection`. Pipe dplyr verbs and call
#'   [dplyr::collect()] to bring data into memory.
#'
#' @examples
#' \dontrun{
#'   dr_con2("HL2")
#'   dr_con2("HL2", trim = FALSE)
#' }
#' @export
dr_con2 <- function(type, url = "https://heima.hafro.is/~einarhj/datras", trim = TRUE, quiet = TRUE) {

  valid_types <- c("HH", "HL2", "CA2")

  if (!type %in% valid_types) {
    stop(sprintf("Invalid type '%s'. Valid types are: %s",
                 type, paste(valid_types, collapse = ", ")), call. = FALSE)
  }

  url  <- sub("/$", "", url)
  path <- paste0(url, "/", type, ".parquet")

  ok <- tryCatch({
    resp <- httr2::request(path) |>
      httr2::req_method("HEAD") |>
      httr2::req_perform()
    httr2::resp_status(resp) < 400
  }, error = function(e) FALSE)

  if (!ok) stop(sprintf("'%s' not found or server unreachable.", path), call. = FALSE)

  if (!quiet) message(sprintf("Connected to '%s'", path))

  q <- duckdbfs::open_dataset(path)

  if(trim == TRUE & type == "HL2") {
    q <- q |> dplyr::select(.id:SubsampleWeight)
  }

  if(trim == TRUE & type == "CA2") {
    q <- q |> dplyr::select(.id:AreaCode)
  }

  return(q)
}
