#' Generate a unique haul id
#'
#' This function generates a haul ID by concatenating fields in
#' the DATRAS tables. The generated ID is stored in a new variable `.id`.
#' The input must contain the columns:
#' \code{Survey, Year, Quarter, Country, Platform, Gear, StationName, HaulNumber}.
#' If any of these columns are missing, an error will be raised.
#'
#' @param d A DATRAS table, one of HH, HL, or CA.
#' @param base Vector, either "new" (default) or "old"
#'
#' @return A table (\code{d}) with an additional variable `.id`
#' @export
#'
#' @examples
#' # Example with a simulated DATRAS table
#' example_data <- data.frame(
#'   Survey = "Surv1",
#'   Year = 2026,
#'   Quarter = 1,
#'   Country = "Country1",
#'   Platform = "Platform1",
#'   Gear = "Gear1",
#'   StationName = "StationA",
#'   HaulNumber = 123
#' )
#' example_data |> dr_add_id()
dr_add_id <- function(d, base = "new") {

  if(base == "new") {
    # Required columns
    required_vars <- c("Survey", "Year", "Quarter", "Country", "Platform",
                       "Gear", "StationName", "HaulNumber")

    # Check if all required variables exist in the input
    missing_vars <- setdiff(required_vars, colnames(d))
    if (length(missing_vars) > 0) {
      stop("The following required columns are missing from the input table: ",
           paste(missing_vars, collapse = ", "))
    }
    d <-
      d |>
      dplyr::mutate(.id = paste(Survey, Year, Quarter, Country, Platform, Gear,
                                StationName, HaulNumber, sep = ":"))
  } else {
    d <-
      d |>
      dplyr::mutate(.id = paste(Survey, Year, Quarter, Country, Ship, Gear,
                                StNo, HaulNo, sep = ":"))
  }

  return(d)

}

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
#' @export

dr_add_date <- function(d) {

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
#' @export
dr_add_starttime <- function(d) {

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
#'
#' @export
dr_add_length_cm <- function(d, LengthCode = LengthCode, LengthClass = LengthClass) {

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

#' Add a standardized `length_mm` column to the input table
#'
#' This function adds a new column `length_mm` to the input table (`d`),
#' computed based on `LengthCode` and `LengthClass` (or their alternative names).
#'
#' @param d A dataframe or DuckDB table containing at least two columns:
#'          a column for `LengthCode` and a column for `LengthClass`.
#' @param LengthCode The column specifying the length code (unquoted).
#'        Defaults to `LengthCode`.
#' @param LengthClass The column specifying the length class (unquoted).
#'        Defaults to `LengthClass`.
#'
#' @return The input table with an additional column `length_mm`.
#'
#' @export
dr_add_length_mm <- function(d, LengthCode = LengthCode, LengthClass = LengthClass) {

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
      length_mm =
        dplyr::case_when(
          {{ LengthCode }} == "-9" ~ NA_real_,          # Invalid length codes marked as NA
          {{ LengthCode }} %in% c(".", "0") ~ {{ LengthClass }},            # Direct mapping
          {{ LengthCode }} %in% c("1", "2", "5") ~ {{ LengthClass }} * 10,  # Multiply by 10
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

#' Lookup table for HL record types
#'
#' A tibble describing the integer codes assigned by \code{\link{dr_add_record_type}}.
#' Each row defines one record type with a short label and a description of
#' the variable pattern that defines it.
#'
#' @format A tibble with columns:
#' \describe{
#'   \item{record_type}{Integer code.}
#'   \item{lc_present}{Logical; whether \code{LengthClass} is present for this type.}
#'   \item{label}{Short human-readable label.}
#'   \item{description}{Full description of the variable pattern.}
#' }
#' @export
hl_record_type_lookup <- tibble::tribble(
  ~record_type, ~lc_present, ~label,                              ~description,
  # --- Records WITH LengthClass ---
  1L,  TRUE,  "Length-frequency, standard",
    "LengthClass and n_haul present; no SpeciesSex or DevelopmentStage annotation",
  2L,  TRUE,  "Length-frequency, sex-disaggregated",
    "LengthClass and n_haul present, SpeciesSex present, no DevelopmentStage",
  3L,  TRUE,  "Length-frequency, with development stage",
    "LengthClass and n_haul present, DevelopmentStage present; ~99% also carry SpeciesSex. Seen mainly in cephalopod/maturity protocols (e.g. Sepia officinalis in BTS)",
  4L,  TRUE,  "Length-frequency, invalid haul",
    "LengthClass present but n_haul is NA: DataType = -9 or NA in the haul header (HH table)",
  # --- Records WITHOUT LengthClass ---
  10L, FALSE, "Explicit zero catch",
    "All measurement vars absent (TotalNumber, SpeciesCategoryWeight, SubsamplingFactor, SpeciesSex all NA). SpeciesValidity = 5 ('not found') in ~94% of cases. These are standard-species-list absences recorded for hauls where the species was looked for but not caught; distinct from implicit zeros (hauls that simply omit the species). Concentrated in BTS and NS-IBTS.",
  11L, FALSE, "Bulk bycatch weight",
    "LengthClass absent; SpeciesCategoryWeight present, TotalNumber absent; no type-3 record for the same .id + ValidAphiaID. Represents organisms weighed as bulk material without individual counting or length measurement: sponges, hydroids, algae, tunicates, etc. Primarily BTS.",
  12L, FALSE, "Counted catch, no subsampling",
    "LengthClass absent; TotalNumber present, SubsamplingFactor absent. Species was counted (and possibly weighed) but no length measurements were taken and no subsampling structure was recorded.",
  13L, FALSE, "Subsampled catch summary, no sex",
    "LengthClass absent; SubsamplingFactor present, SpeciesSex absent. In ~99.8% of cases standalone: species was counted with a subsampling factor but not individually measured. In the rare remaining cases (~0.2%) acts as a companion header row that duplicates the totals from co-occurring type-1 length-frequency records for the same .id + ValidAphiaID + SpeciesCategory.",
  14L, FALSE, "Subsampled catch summary, sex-disaggregated",
    "LengthClass absent; SubsamplingFactor and SpeciesSex present. Analogous to type 13 but with sex annotation. Standalone in ~99.4% of cases; in ~0.6% acts as a companion header to co-occurring type-2 length-frequency records.",
  15L, FALSE, "Sex-coded null record",
    "LengthClass absent; SpeciesSex present but TotalNumber, SpeciesCategoryWeight, and SubsamplingFactor all absent. Functionally equivalent to type 10 (explicit zero) with a sex code attached. Only ~100 records in the full dataset.",
  16L, FALSE, "Companion weight to length-frequency record",
    "LengthClass absent; SpeciesCategoryWeight present, TotalNumber absent; a length-frequency record (type 1, 2, or 3) exists for the same .id + ValidAphiaID. The weight duplicates the SpeciesCategoryWeight already carried by the co-occurring length records and should be excluded to avoid double-counting. Seen for Sepia officinalis (BTS, alongside type-3 development-stage records) and Mnemiopsis leidyi (DYFS, alongside type-2 sex-disaggregated records).",
  99L, FALSE, "Other / unclassified",
    "LengthClass absent; does not fit any of types 10-16"
)

#' Classify HL records by measurement type
#'
#' Adds a \code{record_type} integer column to the HL table classifying each
#' row by the combination of variables that are present or absent.
#' See \code{\link{hl_record_type_lookup}} for the full definition of each code.
#'
#' The function requires that \code{\link{dr_add_n_and_cpue}} has already been
#' run so that \code{n_haul} is present; it uses \code{n_haul} as a proxy for
#' haul validity (types 1–3 vs type 4) rather than reading \code{DataType}
#' directly.
#'
#' Classification uses two passes. The first pass assigns types row-by-row
#' using variable presence/absence. The second pass requires haul-level
#' context: weight-only records (initially type 11) are reclassified as
#' type 16 when a development-stage length-frequency record (type 3) exists
#' for the same \code{.id} and \code{ValidAphiaID}, identifying them as
#' companion weight entries rather than standalone bulk bycatch.
#'
#' @param d DATRAS length table (HL) containing at least the columns
#'   \code{.id}, \code{ValidAphiaID}, \code{LengthClass}, \code{n_haul},
#'   \code{SpeciesSex}, \code{DevelopmentStage}, \code{TotalNumber},
#'   \code{SpeciesCategoryWeight}, and \code{SubsamplingFactor}.
#'
#' @return \code{d} with an additional integer column \code{record_type}.
#' @seealso \code{\link{hl_record_type_lookup}}
#' @export
dr_add_record_type <- function(d) {

  required_vars <- c(".id", "ValidAphiaID", "LengthClass", "n_haul",
                     "SpeciesSex", "DevelopmentStage",
                     "TotalNumber", "SpeciesCategoryWeight", "SubsamplingFactor")
  missing_vars <- setdiff(required_vars, colnames(d))
  if (length(missing_vars) > 0) {
    stop("The following required columns are missing: ",
         paste(missing_vars, collapse = ", "))
  }

  # --- Pass 1: row-wise classification by variable presence/absence ----------
  d <- d |>
    dplyr::mutate(
      record_type = dplyr::case_when(
        # Records WITH LengthClass (types 1-4)
        # DevelopmentStage takes priority over sex-only within valid records
        !is.na(LengthClass) & !is.na(n_haul) & !is.na(DevelopmentStage) ~ 3L,
        !is.na(LengthClass) & !is.na(n_haul) & !is.na(SpeciesSex)       ~ 2L,
        !is.na(LengthClass) & !is.na(n_haul)                             ~ 1L,
        !is.na(LengthClass) &  is.na(n_haul)                             ~ 4L,

        # Records WITHOUT LengthClass (types 10-15, 99)
        is.na(LengthClass) &
          is.na(TotalNumber) & is.na(SpeciesCategoryWeight) &
          is.na(SubsamplingFactor) & is.na(SpeciesSex)                   ~ 10L,
        is.na(LengthClass) &
          is.na(TotalNumber) & !is.na(SpeciesCategoryWeight)             ~ 11L,  # provisional; see pass 2
        is.na(LengthClass) &
          !is.na(TotalNumber) & is.na(SubsamplingFactor)                 ~ 12L,
        is.na(LengthClass) &
          !is.na(SubsamplingFactor) & !is.na(SpeciesSex)                 ~ 14L,
        is.na(LengthClass) &
          !is.na(SubsamplingFactor) & is.na(SpeciesSex)                  ~ 13L,
        is.na(LengthClass) & !is.na(SpeciesSex)                         ~ 15L,

        TRUE ~ 99L
      )
    )

  # --- Pass 2: reclassify weight-only records that accompany length records ---
  # A type-11 record sharing .id + ValidAphiaID with any length-frequency record
  # (types 1-3) is a companion weight entry (type 16), not standalone bulk bycatch.
  hauls_with_ds <- d |>
    dplyr::filter(record_type %in% 1L:3L) |>
    dplyr::distinct(.id, ValidAphiaID) |>
    dplyr::mutate(.has_ds = TRUE)

  d |>
    dplyr::left_join(hauls_with_ds, by = c(".id", "ValidAphiaID")) |>
    dplyr::mutate(
      record_type = dplyr::if_else(
        record_type == 11L & !is.na(.has_ds),
        16L,
        record_type
      )
    ) |>
    dplyr::select(-.has_ds)
}

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
#' @return The input table with additional columns `n_haul` and `n_hour`.
#'
#' @export
dr_add_n_and_cpue <- function(d, NumberAtLength = NumberAtLength, HaulDuration = HaulDuration, SubsamplingFactor = SubsamplingFactor) {

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
      n_haul = dplyr::case_when(
        DataType == "C"  ~ {{ NumberAtLength }} * {{ SubsamplingFactor }} * {{ HaulDuration }} / 60, # Data as CPUE
        # Could lump stuff below:
        DataType == "R"  ~ {{ NumberAtLength }} * {{ SubsamplingFactor }},                           # Data by haul
        DataType == "P"  ~ {{ NumberAtLength }} * {{ SubsamplingFactor }},                           # Pseudocategory sampling
        DataType == "S"  ~ {{ NumberAtLength }} * {{ SubsamplingFactor }},                           # Subsampled data
        DataType == "-9" ~ NA,                                             # Invalid hauls
        is.na(DataType)  ~ NA,                                             # Same as -9
        TRUE ~ NA                                                          # Unexpected DataType
      )
    ) |>
    dplyr::mutate(
      n_hour = n_haul / {{ HaulDuration }} * 60
    )

  return(d)
}
