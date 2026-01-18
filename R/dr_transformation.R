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
.dr_add_date <- function(d) {

  # Check whether required columns exist
  required_vars <- c("Year", "Month", "Day")
  if (!all(required_vars %in% colnames(d))) {
    stop(paste("The following required columns are missing:",
               paste(setdiff(required_vars, colnames(d)), collapse = ", ")))
  }

  # Handle DuckDB tables or dataframes
  if (inherits(d, "tbl_duckdb_connection")) {
    # For DuckDB table
    d <-
      d |>
      # Here "make_date" is a build in DuckDB function
      dplyr::mutate(date = make_date(Year, Month, Day))

  } else {
    if (inherits(d, "data.frame")) {
      # For dataframes
      d <-
        d |>
        dplyr::mutate(date = lubridate::make_date(Year, Month, Day))
    } else {
      message("Object is neither a DuckDB table nor a dataframe")
      return(dplyr::tibble())
    }
  }

  return(d)
}

#' Calculate timestamp based on `Year`, `Month`, `Day`, and `StartTime`/`TimeShot`.
#'
#' This function calculates a precise timestamp using the `Year`, `Month`, `Day`, and `StartTime` or `TimeShot` columns
#' from the input table (DuckDB table or dataframe). The time column is expected to be a numeric
#' or character string representing time in 24-hour `HHMM` format. It ensures all required columns are present
#' in the input and adjusts behavior based on whether the input is a DuckDB table or a standard dataframe.
#'
#' @param d A DuckDB connection table or a dataframe containing at least the columns:
#' `Year` (numeric or integer), `Month` (numeric or integer), `Day` (numeric or integer),
#' and `StartTime`/`TimeShot` (numeric or character in `HHMM` format).
#'
#' @return The input table (DuckDB table or dataframe) with an additional `timestamp` column,
#' calculated as a POSIXct timestamp, or `NULL` if the input is neither a DuckDB table nor a dataframe.
#'
.dr_add_starttime <- function(d) {

  # Determine which column represents time
  time_col <- if ("StartTime" %in% colnames(d)) "StartTime" else if ("TimeShot" %in% colnames(d)) "TimeShot" else NULL

  # Check whether required columns exist
  required_vars <- c("Year", "Month", "Day", time_col)
  if (is.null(time_col) || !all(sapply(required_vars, function(x) x %in% colnames(d)))) {
    stop(paste("The following required columns are missing:",
               paste(setdiff(required_vars, colnames(d)), collapse = ", ")))
  }

  if (inherits(d, "tbl_duckdb_connection")) {
    d <-
      d |>
      dplyr::mutate(time = make_timestamp(
        Year, Month, Day,
        as.integer(as.integer(!!rlang::sym(time_col)) %/% 100),
        as.integer(as.integer(!!rlang::sym(time_col)) %% 100),
        0L))

  } else {
    if (inherits(d, "data.frame")) {
      d <-
        d |>
        dplyr::mutate(
          time = lubridate::make_datetime(Year, Month, Day,
                                          as.integer(!!rlang::sym(time_col)) %/% 100,
                                          as.integer(!!rlang::sym(time_col)) %% 100,
                                          0))

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


#' Add a standardized `length_cm` column to the input table
#'
#' This function adds a new column `length_cm` to the input table (`d`),
#' computed based on `LengthCode` and `LengthClass` (or their alternative names).
#'
#' @param d A dataframe or DuckDB table containing at least two columns:
#'          a column for `LengthCode` and a column for `LengthClass`.
#' @param LengthCode The column specifying the length code (unquoted).
#'        Defaults to `LengthCode`.
#' @param LengthClass The column specifying the length class (unquoted).
#'        Defaults to `LengthClass`.
#'
#' @return The input table with an additional column `length_cm`.
.dr_add_length_cm <- function(d, LengthCode = LengthCode, LengthClass = LengthClass) {

  # Validate that required columns exist
  required_vars <- c(rlang::as_name(rlang::enquo(LengthCode)), rlang::as_name(rlang::enquo(LengthClass)))
  missing_vars <- setdiff(required_vars, colnames(d))
  if (length(missing_vars) > 0) {
    stop(paste("The required variables are missing from the table:",
               paste(missing_vars, collapse = ", ")))
  }

  # Add `length_cm` column
  d <- d |>
    dplyr::mutate(
      length_cm =
        dplyr::case_when(
          {{ LengthCode }} == "-9" ~ NA_real_,          # Invalid length codes marked as NA
          {{ LengthCode }} %in% c(".", "0") ~ {{ LengthClass }} / 10,  # Divide by 10
          {{ LengthCode }} %in% c("1", "2", "5") ~ {{ LengthClass }},  # Direct mapping
          TRUE ~ NA_real_                              # Any other case is NA
        )
    )

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
#' This function generates two new columns: `n` (numbers caught) and
#' `cpue` (numbers caught per one hour towing) for the length table (HL).
#'
#' @param d DATRAS length table (HL) containing columns `.id`,
#'          a column for `NumberAtLength`, a column for `HaulDuration`, and a column for `SubsamplingFactor`.
#' @param NumberAtLength The column specifying the number of individuals (unquoted).
#'        Defaults to `NumberAtLength`.
#' @param HaulDuration The column specifying haul duration (unquoted).
#'        Defaults to `HaulDuration`.
#' @param SubsamplingFactor The column specifying the subsampling factor (unquoted).
#'        Defaults to `SubsamplingFactor`.
#'
#' @return The input table with additional columns `n` and `cpue`.
.dr_n_and_cpue <- function(d, NumberAtLength = NumberAtLength, HaulDuration = HaulDuration, SubsamplingFactor = SubsamplingFactor) {

  # Check whether the required columns exist
  required_vars <- c(".id", "DataType", rlang::as_name(rlang::enquo(NumberAtLength)),
                     rlang::as_name(rlang::enquo(HaulDuration)), rlang::as_name(rlang::enquo(SubsamplingFactor)))
  missing_vars <- setdiff(required_vars, colnames(d))

  if (length(missing_vars) > 0) {
    stop(paste("The following required columns are missing from input table:",
               paste(missing_vars, collapse = ", ")))
  }

  # Add `n` and `cpue` columns
  d <-
    d |>
    dplyr::mutate(
      n = dplyr::case_when(
        DataType == "R" ~ {{ NumberAtLength }} * {{ SubsamplingFactor }},                # Data by haul
        DataType == "C" ~ {{ NumberAtLength }} * {{ HaulDuration }} / 60 * {{ SubsamplingFactor }}, # Data as CPUE
        DataType == "P" ~ NA,                                          # Pseudocategory sampling
        DataType == "S" ~ NA,                                          # Subsampled data
        DataType == "-9" ~ NA,                                         # Invalid hauls
        is.na(DataType) ~ NA,                                          # Same as -9
        TRUE ~ NA                                                      # Unexpected DataType
      )
    ) |>
    dplyr::mutate(
      cpue = n / {{ HaulDuration }} * 60
    )

  return(d)
}
