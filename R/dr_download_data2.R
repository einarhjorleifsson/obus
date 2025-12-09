#' Download and read DATRAS data, single-year or contiguous year-range only
#'
#' Accepts either a single year (e.g. 1988) or a contiguous range of years specified as:
#' - a single integer (e.g. 1988)
#' - a single "start:end" style string (e.g. "1988:2025")
#' - or a numeric vector that is contiguous (e.g. 1988:2025)
#'
#' Non-contiguous year lists (e.g. c(1988, 1990) or c("1988","1990")) are not allowed
#' and will produce an error.
#'
#' Quarter accepts the same forms (single or contiguous range), but values must be in 1:4.
#'
#' The recordtype argument must be one of "HH", "HL", or "CA" (case-insensitive).
#'
#' This version always performs a single API request (using the DATRAS range syntax
#' when ranges are provided). The function supports simple file-based caching across R sessions.
#'
#' @param recordtype character Record type (one of "HH", "HL", "CA"; case-insensitive).
#' @param survey character Survey short code (e.g. "NS-IBTS").
#' @param year integer|numeric|character Single year (e.g. 1988), or a contiguous range specified as "1988:2025" or 1988:2025.
#' @param quarter integer|numeric|character Single quarter (1-4), or a contiguous range specified as "1:4" or 1:4.
#' @param timeout numeric Timeout in seconds for downloads via options(timeout). Default 300.
#' @param verbose logical Whether to print progress messages. Default TRUE.
#' @param cache logical Whether to cache results on disk. Default TRUE.
#' @param cache_dir character Optional directory for cache files. If NULL the default is ~/.datras_cache (or tempdir() if HOME not set).
#' @param overwrite_cache logical If TRUE, ignore an existing cache file and re-download (then update cache). Default FALSE.
#'
#' @return A data.frame
#'
#' @export
get_datras_table_base <- function(recordtype, survey, year, quarter,
                                  timeout = 300, verbose = TRUE,
                                  cache = TRUE, cache_dir = NULL, overwrite_cache = FALSE) {
  base_url <- "https://datras.ices.dk/Data_products/Download/GetDATRAS.aspx"

  # --- Input validation ---
  if (missing(recordtype) || !nzchar(as.character(recordtype))) {
    stop("recordtype must be provided and non-empty")
  }
  # allowed record types
  allowed_recordtypes <- c("HH", "HL", "CA")
  recordtype_chr <- toupper(as.character(recordtype))
  if (!recordtype_chr %in% allowed_recordtypes) {
    stop("recordtype must be one of: ", paste(allowed_recordtypes, collapse = ", "),
         " (case-insensitive). Got: '", as.character(recordtype), "'.", call. = FALSE)
  }
  # normalize to uppercase for internal use
  recordtype <- recordtype_chr

  if (missing(survey) || !nzchar(as.character(survey))) {
    stop("survey must be provided and non-empty")
  }

  timeout <- as.numeric(timeout)
  if (is.na(timeout) || timeout <= 0) stop("timeout must be a positive number")

  verbose <- as.logical(verbose)
  cache <- as.logical(cache)
  overwrite_cache <- as.logical(overwrite_cache)

  # Normalize input: accept single value or contiguous range only
  normalize_contiguous <- function(x, name, allowed_min = -Inf, allowed_max = Inf) {
    if (is.character(x) && length(x) == 1 && grepl("^\\s*\\d+\\s*:\\s*\\d+\\s*$", x)) {
      cleaned <- gsub("\\s", "", x)
      parts <- strsplit(cleaned, ":")[[1]]
      a <- as.integer(parts[1]); b <- as.integer(parts[2])
      if (is.na(a) || is.na(b) || a > b) stop(sprintf("Invalid %s range: '%s'", name, x))
      if (a < allowed_min || b > allowed_max) stop(sprintf("%s values must be between %s and %s", name, allowed_min, allowed_max))
      return(list(range = paste0(a, ":", b), vec = seq.int(a, b)))
    }

    if (is.numeric(x) || is.integer(x)) {
      vec <- as.integer(x)
      if (any(is.na(vec))) stop(sprintf("Invalid numeric values for %s", name))
      if (length(vec) == 0) stop(sprintf("No valid values provided for %s", name))
      vec <- sort(unique(vec))
      if (length(vec) == 1) {
        if (vec < allowed_min || vec > allowed_max) stop(sprintf("%s must be between %s and %s", name, allowed_min, allowed_max))
        return(list(range = as.character(vec), vec = vec))
      }
      # require contiguous
      if (all(diff(vec) == 1)) {
        if (min(vec) < allowed_min || max(vec) > allowed_max) stop(sprintf("%s values must be between %s and %s", name, allowed_min, allowed_max))
        return(list(range = paste0(min(vec), ":", max(vec)), vec = vec))
      }
      stop(sprintf("%s must be either a single value or a contiguous range (e.g. 1988:2025); non-contiguous lists are not allowed.", name))
    }

    if (is.character(x)) {
      num <- suppressWarnings(as.integer(x))
      if (any(is.na(num))) stop(sprintf("Cannot interpret character vector for %s as integers: %s", name, paste(x, collapse = ",")))
      return(normalize_contiguous(num, name, allowed_min, allowed_max))
    }

    stop(sprintf("Unsupported type for %s: %s", name, class(x)[1]))
  }

  yr_info <- normalize_contiguous(year, "year")
  qtr_info <- normalize_contiguous(quarter, "quarter", allowed_min = 1L, allowed_max = 4L)

  # Build single request year/quarter params (range or single)
  year_param <- yr_info$range
  quarter_param <- qtr_info$range

  # --- caching setup ---
  if (cache) {
    if (is.null(cache_dir)) {
      home <- Sys.getenv("HOME", "")
      if (nzchar(home)) {
        cache_dir <- file.path(home, ".datras_cache")
      } else {
        cache_dir <- file.path(tempdir(), "datras_cache")
      }
    }
    # ensure cache_dir exists
    if (!dir.exists(cache_dir)) {
      ok <- tryCatch(dir.create(cache_dir, recursive = TRUE), error = function(e) FALSE)
      if (!ok) warning("Could not create cache directory: ", cache_dir)
    }

    # simple safe key -> filename (use normalized recordtype)
    key_raw <- paste(recordtype, survey, year_param, quarter_param, sep = "_")
    key <- gsub("[^A-Za-z0-9._-]", "_", key_raw)
    # limit filename length to avoid very long names
    if (nchar(key) > 180) key <- substr(key, 1, 180)
    cache_file <- file.path(cache_dir, paste0(key, ".rds"))

    if (cache && file.exists(cache_file) && !overwrite_cache) {
      if (verbose) message("Loading from cache: ", cache_file)
      res <- tryCatch(readRDS(cache_file), error = function(e) {
        warning("Cache file exists but could not be read; proceeding to download: ", conditionMessage(e))
        NULL
      })
      if (!is.null(res)) return(res)
    }
  } else {
    cache_file <- NULL
  }

  # Temporary directory and cleanup for download/unzip
  td <- tempfile("datras_")
  if (!dir.create(td)) stop("Failed to create temporary directory")
  on.exit({
    try(unlink(td, recursive = TRUE, force = TRUE), silent = TRUE)
  }, add = TRUE)

  temp_zip <- file.path(td, "datras.zip")

  # Build URL (URL-encode components)
  q_recordtype <- utils::URLencode(as.character(recordtype), reserved = TRUE)
  q_survey <- utils::URLencode(as.character(survey), reserved = TRUE)
  q_year <- utils::URLencode(as.character(year_param), reserved = TRUE)
  q_quarter <- utils::URLencode(as.character(quarter_param), reserved = TRUE)
  full_url <- paste0(base_url, "?recordtype=", q_recordtype,
                     "&survey=", q_survey,
                     "&year=", q_year,
                     "&quarter=", q_quarter)

  if (verbose) message("Downloading from: ", full_url)

  # Temporarily set timeout option for download.file
  original_timeout <- getOption("timeout")
  on.exit(options(timeout = original_timeout), add = TRUE)
  options(timeout = timeout)

  dl_res <- tryCatch(
    utils::download.file(full_url, destfile = temp_zip, mode = "wb", quiet = !verbose),
    error = function(e) e
  )
  if (inherits(dl_res, "error")) stop("download.file failed: ", conditionMessage(dl_res))
  if (!file.exists(temp_zip) || file.info(temp_zip)$size == 0) stop("Download failed or produced empty file.")

  if (verbose) message("Unzipping...")
  unzip_res <- tryCatch(utils::unzip(temp_zip, exdir = td), error = function(e) e)
  if (inherits(unzip_res, "error")) stop("Failed to unzip: ", conditionMessage(unzip_res))
  if (length(unzip_res) == 0) stop("No files extracted from ZIP archive.")

  # Find Table.csv (case-insensitive), fallback to any .csv
  csv_files <- list.files(td, pattern = "table\\.csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(csv_files) == 0) {
    csv_files <- list.files(td, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }
  if (length(csv_files) == 0) {
    files_list <- list.files(td, recursive = TRUE, full.names = FALSE)
    stop("No CSV found in ZIP. Extracted files: ", paste(utils::head(files_list, 20), collapse = ", "))
  }
  csv_file <- csv_files[1]

  if (verbose) message("Reading ", basename(csv_file), " ...")
  df <- tryCatch(
    utils::read.csv(csv_file, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8"),
    error = function(e) e
  )
  if (inherits(df, "error")) stop("Failed to read CSV: ", conditionMessage(df))

  # update cache if requested
  if (cache && !is.null(cache_file)) {
    tryCatch(saveRDS(df, cache_file), error = function(e) {
      warning("Failed to write cache file: ", conditionMessage(e))
    })
  }

  # Clean up the zip file (td will be removed by on.exit)
  try(unlink(temp_zip), silent = TRUE)

  if (verbose) message("Done. Returning data.frame with ", nrow(df), " rows and ", ncol(df), " columns.")
  df
}
