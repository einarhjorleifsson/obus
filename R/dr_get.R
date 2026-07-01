# Two sources for HH/HL/CA data (source argument in dr_get):
#  "parquet" - URL-hosted parquet files; full dataset, standard names
#  "xml"     - icesDatras::getDATRAS; legacy names, translated to standard on return
#
# Derived products (FL, LT, CPUEL, CPUEA, CW, IDX) always use their own
# ICES API functions; legacy names are translated to standard on return via dr_translate().
#
# Internal helpers (.dr_fetch_*) handle each path.
# dr_get() is a thin dispatcher.


# Internal helpers -------------------------------------------------------------

# All surveys from ICES, excluding test surveys.
.dr_default_surveys <- function() {
  surveys <- icesDatras::getSurveyList()
  surveys[!grepl("^Test", surveys, ignore.case = TRUE)]
}

# Default species: Gadus morhua (cod), Melanogrammus aeglefinus (haddock),
# Clupea harengus (herring).
.dr_default_aphia <- function() c(126436L, 126437L, 126417L)

# Strip the xsi:nil="true" XML attribute that the icesDatras XML parser leaks
# into column names (e.g. 'Age_6 xsi:nil="true"' -> 'Age_6').  Applied per
# data frame BEFORE bind_rows in all XML-backed fetchers; a no-op when absent.
.strip_xsi_nil <- function(d) {
  names(d) <- sub(' xsi:nil="true"', "", names(d), fixed = TRUE)
  d
}


.dr_fetch_parquet <- function(recordtype, surveys, years, quarters) {
  url <- paste0("https://heima.hafro.is/~einarhj/datras/", recordtype, ".parquet")
  duckdbfs::open_dataset(url) |>
    dplyr::filter(Survey %in% surveys, Year %in% years, Quarter %in% quarters) |>
    dplyr::collect()
}

.dr_fetch_xml <- function(recordtype, surveys, years, quarters, quiet) {
  .fetch <- function(survey) {
    tryCatch(
      icesDatras::getDATRAS(recordtype, survey, years, quarters),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::map(surveys, .fetch))
  } else {
    data <- purrr::map(surveys, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  data <- data |>
    purrr::map(\(d) .strip_xsi_nil(d) |> dr_settypes(name_col = "old")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}

# .dr_fetch_csv removed 2026-06-03 per IMBUS WP2-WP5 meeting decision:
# icesDatras::get_datras_unaggregated_data was entered prematurely and will
# not be included in the package. Use source = "parquet" (default) or "xml".

.dr_fetch_csv_REMOVED <- function(recordtype, surveys, years, quarters, quiet) {
  stop(".dr_fetch_csv is no longer available. Use source = 'parquet' or source = 'xml'.")
  years_c    <- paste0(min(years),    ":", max(years))
  quarters_c <- paste0(min(quarters), ":", max(quarters))
  .fetch <- function(survey) {
    tryCatch(
      icesDatras::get_datras_unaggregated_data(recordtype, survey, years_c, quarters_c),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::map(surveys, .fetch))
  } else {
    data <- purrr::map(surveys, .fetch)
  }
  i <- purrr::map_lgl(data, \(x) is.data.frame(x) && nrow(x) > 0)
  data <- dplyr::bind_rows(data[i]) |> as.data.frame()
  data[data == -9] <- NA
  if (nrow(data) == 0) return(data)
  data <- data |> dplyr::filter(RecordHeader != "")
  if (recordtype == "CA") {
    data <- data |>
      dplyr::rename(ScientificName_WoRMS = Species, ValidAphiaID = AphiaID)
  }
  data
}

.dr_fetch_flex <- function(surveys, years, quarters, quiet) {
  grid <- tidyr::expand_grid(survey = surveys, year = years, quarter = quarters)
  .fetch <- function(survey, year, quarter) {
    tryCatch(
      icesDatras::getFlexFile(survey, year, quarter),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::pmap(grid, .fetch))
  } else {
    data <- purrr::pmap(grid, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  data <- data |>
    purrr::map(\(d) .strip_xsi_nil(d) |> dr_settypes(name_col = "old", recordheader = "FL")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


.dr_fetch_cpue_length <- function(surveys, years, quarters, quiet) {
  grid <- tidyr::expand_grid(survey = surveys, year = years, quarter = quarters)
  .fetch <- function(survey, year, quarter) {
    tryCatch(
      icesDatras::getCPUELength(survey, year, quarter),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::pmap(grid, .fetch))
  } else {
    data <- purrr::pmap(grid, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  data <- purrr::map(data, \(d) .strip_xsi_nil(d) |> dr_settypes(name_col = "old", recordheader = "CPUEL")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


.dr_fetch_cpue_age <- function(surveys, years, quarters, quiet) {
  grid <- tidyr::expand_grid(survey = surveys, year = years, quarter = quarters)
  .fetch <- function(survey, year, quarter) {
    tryCatch(
      icesDatras::getCPUEAge(survey, year, quarter),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::pmap(grid, .fetch))
  } else {
    data <- purrr::pmap(grid, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  # Strip xsi:nil artifact, coerce Age_* to numeric, then apply full type spec —
  # all per data frame BEFORE bind_rows to avoid duplicate column name issues.
  .clean_age <- function(d) {
    d <- .strip_xsi_nil(d)
    d <- dplyr::mutate(d, dplyr::across(dplyr::matches("^Age_\\d+$"), \(x) suppressWarnings(as.numeric(x))))
    dr_settypes(d, name_col = "old", recordheader = "CPUEA")
  }
  data <- purrr::map(data, .clean_age) |> dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


.dr_fetch_catch_wgt <- function(surveys, years, quarters, aphia, quiet) {
  .fetch <- function(survey) {
    tryCatch(
      icesDatras::getCatchWgt(survey, years, quarters, aphia),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::map(surveys, .fetch))
  } else {
    data <- purrr::map(surveys, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  # Apply types per df before bind_rows — columns like StNo can arrive as
  # integer in some surveys and character in others, causing bind_rows to fail.
  data <- purrr::map(data, \(d) .strip_xsi_nil(d) |> dr_settypes(name_col = "old")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


.dr_fetch_indices <- function(surveys, years, quarters, aphia, quiet) {
  grid <- tidyr::expand_grid(survey = surveys, year = years, quarter = quarters,
                             species = aphia)
  .fetch <- function(survey, year, quarter, species) {
    tryCatch(
      icesDatras::getIndices(survey, year, quarter, species),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::pmap(grid, .fetch))
  } else {
    data <- purrr::pmap(grid, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  # Strip xsi:nil artifact, coerce Age_* to numeric, then apply full type spec —
  # all per data frame BEFORE bind_rows to avoid duplicate column name issues.
  .clean_age <- function(d) {
    d <- .strip_xsi_nil(d)
    # Rename PlusGr -> PlusGrAge to distinguish from CA's AgePlusGroup char flag
    names(d)[names(d) == "PlusGr"] <- "PlusGrAge"
    d <- dplyr::mutate(d, dplyr::across(dplyr::matches("^Age_\\d+$"), \(x) suppressWarnings(as.numeric(x))))
    dr_settypes(d, name_col = "old", recordheader = "IDX")
  }
  data <- purrr::map(data, .clean_age) |> dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


.dr_fetch_lt <- function(surveys, years, quarters, quiet) {
  grid <- tidyr::expand_grid(survey = surveys, year = years, quarter = quarters)
  .fetch <- function(survey, year, quarter) {
    tryCatch(
      icesDatras::getLTassessment(survey, year, quarter),
      error = function(e) NULL
    )
  }
  if (quiet) {
    data <- suppressMessages(purrr::pmap(grid, .fetch))
  } else {
    data <- purrr::pmap(grid, .fetch)
  }
  i <- purrr::map_lgl(data, is.data.frame)
  data <- data[i]
  if (length(data) == 0) return(data.frame())
  # Strip xsi:nil="true" artifact from any column name before settypes/bind.
  # LT has nil columns beyond Age_* (e.g. Tickler, Warpdia, DoorSurface).
  # No recordheader filter: borrow types from all RecordHeaders.
  data <- data |>
    purrr::map(\(d) .strip_xsi_nil(d) |> dr_settypes(name_col = "old")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


# Exported functions -----------------------------------------------------------

#' Download and Import DATRAS Data
#'
#' Retrieves DATRAS trawl survey data from two sources:
#' - `"parquet"`: Reads from URL-hosted Parquet files, filtered by `surveys`,
#'   `years`, and `quarters` before download. Returns standard column names
#'   directly.
#' - `"xml"`: Retrieves data via the legacy `icesDatras::getDATRAS` function.
#'   Legacy column names are translated to standard names before returning.
#'
#' All other record types (FL, LT, CPUEL, CPUEA, CW, IDX) always use their
#' dedicated ICES API functions; the `source` argument is ignored for these.
#' Their legacy column names are translated to standard names before returning.
#'
#' Translation is performed by [dr_translate()] using the `dictionary` argument.
#' Supply a custom data frame with columns `old` and `new` to override the
#' default mapping built from [dr_lookup_fields].
#'
#' @param recordtype A string specifying the record type: `"HH"`, `"HL"`, `"CA"`,
#'   `"FL"` (flex file), `"LT"` (litter assessment), `"CPUEL"` (CPUE per length
#'   per haul per hour), `"CPUEA"` (CPUE per age per haul per hour), `"CW"`
#'   (catch weight by species and haul), or `"IDX"` (age-based survey indices).
#' @param surveys A character vector of survey IDs. If `NULL` (default), all
#'   ICES surveys excluding test surveys are used (via `icesDatras::getSurveyList()`).
#' @param years An integer vector of years (e.g. `1965:2030`).
#' @param quarters An integer vector of quarters (e.g. `1:4`).
#' @param aphia An integer vector of WoRMS Aphia species codes. Used by `"CW"`
#'   and `"IDX"`. If `NULL`, defaults to cod (126436), haddock (126437), and
#'   herring (126417).
#' @param source String specifying the data source for HH/HL/CA: `"parquet"`
#'   (default) or `"xml"`. Ignored for FL, LT, CPUEL, CPUEA, CW, IDX.
#' @param dictionary A data frame with columns `old` and `new` used to translate
#'   legacy ICES column names to standard names. If `NULL` (default), built
#'   automatically from [dr_lookup_fields].
#' @param quiet Logical; suppresses progress messages if `TRUE` (default).
#'
#' @return A data frame with standard column names.
#'
#' @examples
#' \dontrun{
#'   dr_get("HH")                                                        # full parquet
#'   dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, source = "xml")
#'   dr_get("FL", surveys = "NS-IBTS", years = 2020:2023, quarters = 1)
#' }
#' @export
dr_get <- function(recordtype, surveys = NULL, years = 1965:2030, quarters = 1:4,
                   aphia = NULL, source = "parquet", dictionary = NULL, quiet = TRUE) {

  # Build default old -> new translation dictionary, scoped to this record type.
  # Pass dictionary = FALSE to skip translation entirely (raw legacy names returned).
  # Pass a custom data frame with columns `old` and `new` to override the default.
  if (is.null(dictionary)) {
    dictionary <- dr_lookup_fields |>
      dplyr::filter(table == recordtype, !is.na(old), !is.na(new)) |>
      dplyr::distinct(old, new)
  }
  .tr <- function(d) {
    if (isFALSE(dictionary)) d else dr_translate(d, dictionary, from = "old", to = "new")
  }

  if (is.null(surveys)) surveys <- .dr_default_surveys()

  if (recordtype == "FL")
    return(.tr(.dr_fetch_flex(surveys, years, quarters, quiet)))

  if (recordtype == "LT")
    return(.tr(.dr_fetch_lt(surveys, years, quarters, quiet)))

  if (recordtype == "CPUEL")
    return(.tr(.dr_fetch_cpue_length(surveys, years, quarters, quiet)))

  if (recordtype == "CPUEA")
    return(.tr(.dr_fetch_cpue_age(surveys, years, quarters, quiet)))

  if (recordtype %in% c("CW", "IDX")) {
    if (is.null(aphia)) aphia <- .dr_default_aphia()
    if (recordtype == "CW")
      return(.tr(.dr_fetch_catch_wgt(surveys, years, quarters, aphia, quiet)))
    if (recordtype == "IDX")
      return(.tr(.dr_fetch_indices(surveys, years, quarters, aphia, quiet)))
  }

  if (source == "parquet") return(.dr_fetch_parquet(recordtype, surveys, years, quarters))
  if (source == "xml")     return(.tr(.dr_fetch_xml(recordtype, surveys, years, quarters, quiet)))

  stop("Unknown 'source' value: '", source, "'. Use 'parquet' or 'xml'.")
}

