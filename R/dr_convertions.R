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
      dplyr::mutate(.timeshot = stringr::str_pad(TimeShot, width = 4, pad = "0"),
                    .hour = as.integer(stringr::str_sub(.timeshot, 1, 2)),
                    .minute = as.integer(stringr::str_sub(.timeshot, 3, 4)),
                    timeshot = make_datetime(Year, Month, Day, .hour, .minute, 0)) |>
      dplyr::select(-c(.timeshot, .hour, .minute))

  } else {
    if ("data.frame" %in% class(d)) {
      d <-
        d |>
        dplyr::mutate(.timeshot = stringr::str_pad(TimeShot, width = 4, pad = "0"),
                      .hour = as.integer(stringr::str_sub(.timeshot, 1, 2)),
                      .minute = as.integer(stringr::str_sub(.timeshot, 3, 4)),
                      timeshot = lubridate::make_datetime(Year, Month, Day, .hour, .minute, 0)) |>
        dplyr::select(-c(.timeshot, .hour, .minute))

    } else {
      message("Object is neither a DuckDB table nor a dataframe")
      return(NULL)
    }
  }

  return(d)
}


#' Calculate length based on `LngtCode` and `LngtClass`.
#'
#' This function adds a new column `length` to the input dataframe,
#' computed based on the `LngtCode` and `LngtClass` values.
#' The transformation rules for the `length` column are as follows:
#' - `LngtCode == "-9"`: The `length` is set to `NA` (assumed to have been handled upstream).
#' - `LngtCode %in% c(".", "0")`: The `length` is computed as the floor of `LngtClass` divided by 10.
#' - `LngtCode %in% c("1", "2", "5")`: The `length` is directly set as `LngtClass`.
#' - Otherwise: `length` is set to `NA`.
#'
#' @param d A dataframe containing at least two columns: `LngtCode` (character) and `LngtClass` (numeric).
#'
#' @return The table `d` with an additional column `length`.
#'
.dr_calc_length2cm <- function(d) {

  # Check if the required variables exist in the table
  required_vars <- c("LngtCode", "LngtClass")
  missing_vars <- setdiff(required_vars, colnames(d))
  if (length(missing_vars) > 0) {
    stop(paste("The following required variables are missing from the table:",
               paste(missing_vars, collapse = ", ")))
  }

  # Proceed with the calculation
  d |>
    dplyr::mutate(
      length =
        dplyr::case_when(LngtCode == "-9" ~ NA_real_,      # -9 -> NA was done upstream
                         LngtCode %in% c(".", "0") ~ floor(LngtClass / 10),
                         LngtCode %in% c("1", "2", "5") ~ LngtClass,
                         .default = NA_real_))
}


#' Calculate column `n` based on `DataType` and `HaulDur`.
#'
#' This function calculates a new column `n` for a table (`hl`) by joining it with another table (`hh`).
#' The calculation of `n` depends on the values of the `DataType` column and the duration of the haul (`HaulDur`).
#' The function ensures all required columns exist in the input tables before processing.
#'
#' @param hl A table containing columns `.id` and `HLNoAtLngt`.
#' @param hh A table containing columns `.id`, `DataType`, and `HaulDur`.
#'
#' @return A table created by joining `hh` with `hl`, with an additional column `n`:
#' - If `DataType == "R"`, `n` is set to `HLNoAtLngt` (data by haul).
#' - If `DataType == "C"`, `n` is calculated as `HLNoAtLngt * HaulDur / 60` (CPUE, number per hour).
#' - If `DataType == "P"` or `"S"`, `n` is set to `-9999` (unsupported case).
#' - If `DataType == "-9"` or `is.na(DataType)`, `n` is set to `NA`.
#' - All other `DataType` values default to `-10000` (unexpected).
#'
.dr_calc_n <- function(hl, hh) {

  # Check whether the required columns exist in `hh` and `hl`
  required_vars_hh <- c(".id", "DataType", "HaulDur")
  required_vars_hl <- c(".id", "HLNoAtLngt")

  missing_vars_hh <- setdiff(required_vars_hh, colnames(hh))
  missing_vars_hl <- setdiff(required_vars_hl, colnames(hl))

  if (length(missing_vars_hh) > 0) {
    stop(paste("The following required columns are missing from `hh` table:",
               paste(missing_vars_hh, collapse = ", ")))
  }

  if (length(missing_vars_hl) > 0) {
    stop(paste("The following required columns are missing from `hl` table:",
               paste(missing_vars_hl, collapse = ", ")))
  }

  # Perform join and calculate `n`
  hl |>
    dplyr::left_join(hh |>
                       dplyr::select(.id, DataType, HaulDur), by = ".id") |>
    dplyr::mutate(
      n =
        dplyr::case_when(
          DataType == "R" ~ HLNoAtLngt * SubFactor,              # Data by haul
          DataType == "C" ~ HLNoAtLngt * HaulDur / 60 * SubFactor, # Data calculated as CPUE (number per hour)
          DataType == "P" ~ NA,                  # Pseudocategory sampling
          DataType == "S" ~ NA,                  # Subsampled data
          DataType == "-9" ~ NA,                    # Invalid hauls
          is.na(DataType) ~ NA,                     # Same as -9
          .default = NA                         # Unexpected DataType
        ),
      n_total =
        dplyr::case_when(
          DataType == "R" ~ TotalNo,              # Data by haul
          DataType == "C" ~ TotalNo * HaulDur / 60 * SubFactor, # Data calculated as CPUE (number per hour)
          DataType == "P" ~ NA,                  # Pseudocategory sampling
          DataType == "S" ~ NA,                  # Subsampled data
          DataType == "-9" ~ NA,                    # Invalid hauls
          is.na(DataType) ~ NA,                     # Same as -9
          .default = NA                         # Unexpected DataType
        )

    )
}



