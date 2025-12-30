#' Calculate date based on `Year`, `Month`, and `Day`.
#'
#' This function adds a new column `date` to the input table (DuckDB table or dataframe),
#' computed from the `Year`, `Month`, and `Day` columns. If the provided input is neither
#' a DuckDB table nor a dataframe, the function returns `NULL` and informs the user.
#'
#' The function checks if the required columns `Year`, `Month`, and `Day` exist,
#' and throws an error if they are missing.
#'
#' @param d A DuckDB connection table or a dataframe containing at least the columns:
#' `Year` (numeric or integer), `Month` (numeric or integer), and `Day` (numeric or integer).
#'
#' @return The input table (DuckDB table or dataframe) with an additional `date` column,
#' or `NULL` if the input is neither a DuckDB table nor a dataframe.
#'
.dr_calc_date <- function(d) {

  # Check whether required columns exist
  required_vars <- c("Year", "Month", "Day")
  if (!all(required_vars %in% colnames(d))) {
    stop(paste("The following required columns are missing:",
               paste(setdiff(required_vars, colnames(d)), collapse = ", ")))
  }

  # Handle DuckDB tables or dataframes
  if ("tbl_duckdb_connection" %in% class(d)) {
    # For DuckDB table
    d <-
      d |>
      # Here "make_date" is a build in DuckDB function
      dplyr::mutate(date = make_date(Year, Month, Day))

  } else {
    if ("data.frame" %in% class(d)) {
      # For dataframes
      d <-
        d |>
        dplyr::mutate(date = lubridate::make_date(Year, Month, Day))
    } else {
      message("Object is neither a DuckDB table nor a dataframe")
      return(NULL)
    }
  }

  return(d)
}

#' Calculate timestamp based on `Year`, `Month`, `Day`, and `TimeShot`.
#'
#' This function calculates a precise timestamp using the `Year`, `Month`, `Day`, and `TimeShot` columns
#' from the input table (DuckDB table or dataframe). The `TimeShot` column is expected to be a numeric
#' or character string representing time in 24-hour `HHMM` format. It ensures all required columns are present
#' in the input and adjusts behavior based on whether the input is a DuckDB table or a standard dataframe.
#'
#' The function performs the following:
#' - Pads `TimeShot` to ensure it is 4 digits (e.g., `800` becomes `0800`).
#' - Extracts hours and minutes from the padded `TimeShot`.
#' - Combines the values from `Year`, `Month`, `Day`, `Hour`, and `Minute` to generate a complete timestamp.
#' - Adds a `timestamp` column (calculated) and removes intermediate columns used in processing.
#'
#' @param d A DuckDB connection table or a dataframe containing at least the columns:
#' `Year` (numeric or integer), `Month` (numeric or integer), `Day` (numeric or integer),
#' and `TimeShot` (numeric or character in `HHMM` format).
#'
#' @return The input table (DuckDB table or dataframe) with an additional `timestamp` column,
#' calculated as a POSIXct timestamp, or `NULL` if the input is neither a DuckDB table nor a dataframe.
#'
.dr_calc_time <- function(d) {

  # Check whether required columns exist
  required_vars <- c("Year", "Month", "Day", "TimeShot")
  if (!all(required_vars %in% colnames(d))) {
    stop(paste("The following required columns are missing:",
               paste(setdiff(required_vars, colnames(d)), collapse = ", ")))
  }

  if ("tbl_duckdb_connection" %in% class(d)) {
    d <-
      d |>
      dplyr::mutate(.timeshot = stringr::str_pad(as.character(TimeShot), width = 4, pad = "0"),
                    .hour = as.integer(stringr::str_sub(.timeshot, 1, 2)),
                    .minute = as.integer(stringr::str_sub(.timeshot, 3, 4)),
                    time = make_timestamp(Year, Month, Day, .hour, .minute, 0)) |>
      dplyr::select(-c(.timeshot, .hour, .minute))

  } else {
    if ("data.frame" %in% class(d)) {
      d <-
        d |>
        dplyr::mutate(
          time = lubridate::make_datetime(Year, Month, Day, TimeShot%/%100, TimeShot%%100, 0))

    } else {
      message("Object is neither a DuckDB table nor a dataframe")
      return(NULL)
    }
  }

  return(d)
}


# icesVocab - LngtCode
# Key                            Description
# -9                           Missing Value
# .   1 mm length class, reporting units: mm
# 0 0.5 cm length class, reporting units: mm
# 1   1 cm length class, reporting units: cm
# 2   2 cm length class, reporting units: cm
# 5   5 cm length class, reporting units: cm
# 9                                  + group

#' Standardize length to cm
#'
#' Function adds a new column `length` to the input dataframe, computed based on the `LngtCode` and `LngtClass` values.
#'
#' The transformation rules for the `length` column are as follows:
#' - `LngtCode == "-9"`: The `length` is set to `NA` (assumed to have been handled upstream).
#' - `LngtCode %in% c(".", "0")`: The `length` is computed as the floor of `LngtClass` divided by 10.
#' - `LngtCode %in% c("1", "2", "5")`: The `length` is directly set as `LngtClass`.
#' - Otherwise: `length` is set to `NA`.
#'
#' @param d A dataframe containing at least two columns: `LngtCode` (character) and `LngtClass` (numeric).
#'
#' @return The input table with an additional column `length`.
#'
.dr_length_cm <- function(d) {

  # Check if the required variables exist in the table
  required_vars <- c("LngtCode", "LngtClass")
  missing_vars <- setdiff(required_vars, colnames(d))
  if (length(missing_vars) > 0) {
    stop(paste("The following required variables are missing from the table:",
               paste(missing_vars, collapse = ", ")))
  }

  d <-
    d |>
    dplyr::mutate(
      length =
        dplyr::case_when(LngtCode == "-9" ~ NA_real_,      # -9 -> NA was done upstream
                         # To floor or not to floor?
                         LngtCode %in% c(".", "0") ~ LngtClass / 10,
                         LngtCode %in% c("1", "2", "5") ~ LngtClass,
                         .default = NA_real_))

  return(d)
}


# icesVocab - DataType
#   |key |description                               |
#   |:---|:-----------------------------------------|
#   |-9  |Invalid hauls                             |
#   |C   |Data calculated as CPUE (number per hour) |
#   |P   |Pseudocategory sampling                   |
#   |R   |Data by haul                              |
#   |S   |Sub sampled data                          |

#' Numbers caught and the CPUE in each length class
#'
#' This function generates two new column `n` (numbers caught) and
#' `cpue` (numbers caught per one hour towing) for the length table (HL).
#'
#' @param d DATRAS length table (HL) containing columns `.id`, `HLNoAtLngt`, `.datatype`, and `.effort`.
#'
#' @return The input table with additional columns `n` and `cpue`.
.dr_n_and_cpue <- function(d) {

  # Check whether the required columns exist in `hh` and `hl`
  required_vars <- c(".id", "HLNoAtLngt", "DataType", "HaulDur")

  missing_vars <- setdiff(required_vars, colnames(d))

  if (length(missing_vars) > 0) {
    stop(paste("The following required columns are missing from input table:",
               paste(missing_vars, collapse = ", ")))
  }

  d <-
    d |>
    dplyr::mutate(
      n =
        dplyr::case_when(
          DataType == "R" ~ HLNoAtLngt * SubFactor,                # Data by haul
          DataType == "C" ~ HLNoAtLngt * HaulDur / 60 * SubFactor, # Data calculated as CPUE (number per hour)
          DataType == "P" ~ NA,                  # Pseudocategory sampling
          DataType == "S" ~ NA,                  # Subsampled data
          DataType == "-9" ~ NA,                 # Invalid hauls
          is.na(DataType) ~ NA,                  # Same as -9
          .default = NA                          # Unexpected DataType
        )
    ) |>
    dplyr::mutate(
      cpue = n / HaulDur * 60
    )

  return(d)
}



