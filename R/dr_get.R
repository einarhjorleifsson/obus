# Currently there are four ways to read DATRAS data into memory:
#  1. icesDatras::getDATRAS                    - the old faithful
#  2. icesDatras::get_datras_unaggregated_data - new API, faster
#  3. read a parquet file                      - full dataset, all surveys
#  4. icesDatras::getFlexFile                  - flex file (FL record type)
#
# Internal helpers (.dr_fetch_*, .dr_settypes) handle each path.
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

# Apply column types from the dr_lookup_fields data object.
#   name_col:     "new" (new-style) or "old" (old-style names).
#   recordheader: if not NULL, restrict dr_lookup_fields to this table value.
.dr_settypes <- function(d, name_col = "new", recordheader = NULL) {
  fields <- dr_lookup_fields
  if (!is.null(recordheader))
    fields <- dplyr::filter(fields, table == recordheader)
  fields <- tidyr::drop_na(fields, dplyr::all_of(name_col))

  key_chr <- fields |> dplyr::filter(DataFormat == "char")    |> dplyr::pull(dplyr::all_of(name_col)) |> unique()
  key_int <- fields |> dplyr::filter(DataFormat == "int")     |> dplyr::pull(dplyr::all_of(name_col)) |> unique()
  key_dbl <- fields |> dplyr::filter(DataFormat == "decimal") |> dplyr::pull(dplyr::all_of(name_col)) |> unique()

  d |>
    dplyr::mutate(dplyr::across(dplyr::where(is.character), \(x) dplyr::na_if(x, "NA"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_chr), as.character)) |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_int), as.integer))   |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_dbl), as.numeric))
}

.dr_fetch_parquet <- function(recordtype) {
  url <- paste0("https://heima.hafro.is/~einarhj/datras/", recordtype, ".parquet")
  arrow::read_parquet(url)
}

.dr_fetch_old <- function(recordtype, surveys, years, quarters, quiet) {
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
    purrr::map(\(d) .dr_settypes(d, name_col = "old")) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}

.dr_fetch_new <- function(recordtype, surveys, years, quarters, quiet) {
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
    purrr::map(\(d) .dr_settypes(d, name_col = "old", recordheader = "FL")) |>
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
  data <- purrr::map(data, \(d) .dr_settypes(d, name_col = "old", recordheader = "CPUEL")) |>
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
    names(d) <- sub(' xsi:nil="true"', "", names(d), fixed = TRUE)
    d <- dplyr::mutate(d, dplyr::across(dplyr::matches("^Age_\\d+$"), as.numeric))
    .dr_settypes(d, name_col = "old", recordheader = "CPUEA")
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
  data <- purrr::map(data, \(d) .dr_settypes(d, name_col = "old")) |>
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
    names(d) <- sub(' xsi:nil="true"', "", names(d), fixed = TRUE)
    # Rename PlusGr -> PlusGrAge to distinguish from CA's AgePlusGroup char flag
    names(d)[names(d) == "PlusGr"] <- "PlusGrAge"
    d <- dplyr::mutate(d, dplyr::across(dplyr::matches("^Age_\\d+$"), as.numeric))
    .dr_settypes(d, name_col = "old", recordheader = "IDX")
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
    purrr::map(\(d) {
      names(d) <- sub(' xsi:nil="true"', "", names(d), fixed = TRUE)
      .dr_settypes(d, name_col = "old")
    }) |>
    dplyr::bind_rows()
  data[data == -9] <- NA
  data
}


# Exported functions -----------------------------------------------------------

#' Download and Import DATRAS Data
#'
#' Retrieves DATRAS trawl survey data from various sources:
#' - `"parquet"`: Reads the full dataset from URL-hosted Parquet files (no
#'   survey/year/quarter filtering).
#' - `"old"`: Retrieves data via the legacy `icesDatras::getDATRAS` function.
#' - `"new"`: Retrieves data via `icesDatras::get_datras_unaggregated_data`.
#'
#' For `recordtype = "FL"` (flex file), `icesDatras::getFlexFile` is called for
#' every combination of survey, year, and quarter; the `from` argument is ignored.
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
#' @param from String specifying the data source for HH/HL/CA: `"parquet"`
#'   (default), `"old"`, or `"new"`. Ignored when `recordtype = "FL"`.
#' @param quiet Logical; suppresses progress messages if `TRUE` (default).
#'
#' @return A data frame.
#'
#' @examples
#' \dontrun{
#'   dr_get("HH")                                                      # full parquet
#'   dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, from = "new")
#'   dr_get("FL", surveys = "NS-IBTS", years = 2020:2023, quarters = 1)
#' }
#' @export
dr_get <- function(recordtype, surveys = NULL, years = 1965:2030, quarters = 1:4,
                   aphia = NULL, from = "parquet", quiet = TRUE) {

  if (is.null(surveys)) surveys <- .dr_default_surveys()

  if (recordtype == "FL")
    return(.dr_fetch_flex(surveys, years, quarters, quiet))

  if (recordtype == "LT")
    return(.dr_fetch_lt(surveys, years, quarters, quiet))

  if (recordtype == "CPUEL")
    return(.dr_fetch_cpue_length(surveys, years, quarters, quiet))

  if (recordtype == "CPUEA")
    return(.dr_fetch_cpue_age(surveys, years, quarters, quiet))

  if (recordtype %in% c("CW", "IDX")) {
    if (is.null(aphia)) aphia <- .dr_default_aphia()
    if (recordtype == "CW")
      return(.dr_fetch_catch_wgt(surveys, years, quarters, aphia, quiet))
    if (recordtype == "IDX")
      return(.dr_fetch_indices(surveys, years, quarters, aphia, quiet))
  }

  if (from == "parquet") return(.dr_fetch_parquet(recordtype))
  if (from == "old")     return(.dr_fetch_old(recordtype, surveys, years, quarters, quiet))
  if (from == "new")     return(.dr_fetch_new(recordtype, surveys, years, quarters, quiet))

  stop("Unknown 'from' value: '", from, "'. Use 'parquet', 'old', or 'new'.")
}


# Below is not really in use ---------------------------------------------------
#datadir <- extracted_dir
# Internal function to read the CSV file using arrow::read_csv_arrow
.dr_read_datras_csv_arrow <- function(recordtype, datadir, quiet = TRUE) {

  col_classes <-
    list(
      HH = arrow::schema(
        arrow::field("RecordHeader", arrow::utf8()),            # character
        arrow::field("Survey", arrow::utf8()),                  # character
        arrow::field("Quarter", arrow::int32()),                # integer
        arrow::field("Country", arrow::utf8()),                 # character
        arrow::field("Platform", arrow::utf8()),                # character
        arrow::field("Gear", arrow::utf8()),                    # character
        arrow::field("SweepLength", arrow::int32()),            # integer
        arrow::field("GearExceptions", arrow::utf8()),          # character
        arrow::field("DoorType", arrow::utf8()),                # character
        arrow::field("StationName", arrow::utf8()),             # character
        arrow::field("HaulNumber", arrow::int32()),             # integer
        arrow::field("Year", arrow::int32()),                   # integer
        arrow::field("Month", arrow::int32()),                  # integer
        arrow::field("Day", arrow::int32()),                    # integer
        arrow::field("StartTime", arrow::utf8()),               # character
        arrow::field("DepthStratum", arrow::utf8()),            # character
        arrow::field("HaulDuration", arrow::int32()),           # integer
        arrow::field("DayNight", arrow::utf8()),                # character
        arrow::field("ShootLatitude", arrow::float64()),        # numeric
        arrow::field("ShootLongitude", arrow::float64()),       # numeric
        arrow::field("HaulLatitude", arrow::float64()),         # numeric
        arrow::field("HaulLongitude", arrow::float64()),        # numeric
        arrow::field("StatisticalRectangle", arrow::utf8()),    # character
        arrow::field("BottomDepth", arrow::int32()),            # integer
        arrow::field("HaulValidity", arrow::utf8()),            # character
        arrow::field("HydrographicStationID", arrow::utf8()),   # character
        arrow::field("StandardSpeciesCode", arrow::utf8()),     # character
        arrow::field("BycatchSpeciesCode", arrow::utf8()),      # character
        arrow::field("DataType", arrow::utf8()),                # character
        arrow::field("NetOpening", arrow::float64()),           # numeric
        arrow::field("Rigging", arrow::utf8()),                 # character
        arrow::field("Tickler", arrow::utf8()),                 # character
        arrow::field("Distance", arrow::float64()),             # numeric
        arrow::field("WarpLength", arrow::int32()),             # integer
        arrow::field("WarpDiameter", arrow::int32()),           # integer
        arrow::field("WarpDensity", arrow::int32()),            # integer
        arrow::field("DoorSurface", arrow::float64()),          # numeric
        arrow::field("DoorWeight", arrow::int32()),             # integer
        arrow::field("DoorSpread", arrow::float64()),           # numeric
        arrow::field("WingSpread", arrow::float64()),           # numeric
        arrow::field("Buoyancy", arrow::int32()),               # integer
        arrow::field("KiteArea", arrow::float64()),             # numeric
        arrow::field("GroundRopeWeight", arrow::float64()),     # numeric
        arrow::field("TowDirection", arrow::int32()),           # integer
        arrow::field("SpeedGround", arrow::float64()),          # numeric
        arrow::field("SpeedWater", arrow::float64()),           # numeric
        arrow::field("SurfaceCurrentDirection", arrow::int32()),# integer
        arrow::field("SurfaceCurrentSpeed", arrow::float64()),  # numeric
        arrow::field("BottomCurrentDirection", arrow::int32()), # integer
        arrow::field("BottomCurrentSpeed", arrow::float64()),   # numeric
        arrow::field("WindDirection", arrow::int32()),          # integer
        arrow::field("WindSpeed", arrow::int32()),              # integer
        arrow::field("SwellDirection", arrow::int32()),         # integer
        arrow::field("SwellHeight", arrow::float64()),          # numeric
        arrow::field("SurfaceTemperature", arrow::float64()),   # numeric
        arrow::field("BottomTemperature", arrow::float64()),    # numeric
        arrow::field("SurfaceSalinity", arrow::float64()),      # numeric
        arrow::field("BottomSalinity", arrow::float64()),       # numeric
        arrow::field("ThermoCline", arrow::utf8()),             # character
        arrow::field("ThermoClineDepth", arrow::int32()),       # integer
        arrow::field("CodendMesh", arrow::int32()),             # integer
        arrow::field("SecchiDepth", arrow::float64()),          # numeric
        arrow::field("Turbidity", arrow::float64()),            # numeric
        arrow::field("TidePhase", arrow::int32()),              # integer
        arrow::field("TideSpeed", arrow::float64()),            # numeric
        arrow::field("PelagicSamplingType", arrow::utf8()),     # character
        arrow::field("MinTrawlDepth", arrow::int32()),          # integer
        arrow::field("MaxTrawlDepth", arrow::int32()),          # integer
        arrow::field("SurveyIndexArea", arrow::utf8()),         # character
        arrow::field("EDOM", arrow::int32()),                   # integer
        arrow::field("ReasonHaulDisruption", arrow::utf8()),    # character
        arrow::field("DateofCalculation", arrow::utf8())        # character
      ),
      HL = arrow::schema(
        arrow::field("RecordHeader", arrow::utf8()),           # character
        arrow::field("Survey", arrow::utf8()),                 # character
        arrow::field("Quarter", arrow::int32()),               # integer
        arrow::field("Country", arrow::utf8()),                # character
        arrow::field("Platform", arrow::utf8()),               # character
        arrow::field("Gear", arrow::utf8()),                   # character
        arrow::field("SweepLength", arrow::int32()),           # integer
        arrow::field("GearExceptions", arrow::utf8()),         # character
        arrow::field("DoorType", arrow::utf8()),               # character
        arrow::field("StationName", arrow::utf8()),            # character
        arrow::field("HaulNumber", arrow::int32()),            # integer
        arrow::field("Year", arrow::int32()),                  # integer
        arrow::field("SpeciesCodeType", arrow::utf8()),        # character
        arrow::field("SpeciesCode", arrow::utf8()),            # character
        arrow::field("SpeciesValidity", arrow::utf8()),        # character
        arrow::field("SpeciesSex", arrow::utf8()),             # character
        arrow::field("TotalNumber", arrow::float64()),         # numeric
        arrow::field("SpeciesCategory", arrow::int32()),       # integer
        arrow::field("SubsampledNumber", arrow::int32()),      # integer
        arrow::field("SubsamplingFactor", arrow::float64()),   # numeric
        arrow::field("SubsampleWeight", arrow::int32()),       # integer
        arrow::field("SpeciesCategoryWeight", arrow::int32()), # integer
        arrow::field("LengthCode", arrow::utf8()),             # character
        arrow::field("LengthClass", arrow::int32()),           # integer
        arrow::field("NumberAtLength", arrow::float64()),      # numeric
        arrow::field("DevelopmentStage", arrow::utf8()),       # character
        arrow::field("LengthType", arrow::utf8()),             # character
        arrow::field("ValidAphiaID", arrow::int32()),          # integer
        arrow::field("ScientificName_WoRMS", arrow::utf8()),   # character
        arrow::field("DateofCalculation", arrow::utf8())       # character
      ),
      CA =
        arrow::schema(
          arrow::field("RecordHeader", arrow::utf8()),          # character
          arrow::field("Survey", arrow::utf8()),                # character
          arrow::field("Quarter", arrow::int32()),              # integer
          arrow::field("Country", arrow::utf8()),               # character
          arrow::field("Platform", arrow::utf8()),              # character
          arrow::field("Gear", arrow::utf8()),                  # character
          arrow::field("SweepLength", arrow::int32()),          # integer
          arrow::field("GearExceptions", arrow::utf8()),        # character
          arrow::field("DoorType", arrow::utf8()),              # character
          arrow::field("StationName", arrow::utf8()),           # character
          arrow::field("HaulNumber", arrow::int32()),           # integer
          arrow::field("Year", arrow::int32()),                 # integer
          arrow::field("SpeciesCodeType", arrow::utf8()),       # character
          arrow::field("SpeciesCode", arrow::utf8()),           # character
          arrow::field("AreaType", arrow::utf8()),              # character
          arrow::field("AreaCode", arrow::utf8()),              # character
          arrow::field("LengthCode", arrow::utf8()),            # character
          arrow::field("LengthClass", arrow::int32()),          # integer
          arrow::field("IndividualSex", arrow::utf8()),         # character
          arrow::field("IndividualMaturity", arrow::utf8()),    # character
          arrow::field("AgePlusGroup", arrow::utf8()),          # character
          arrow::field("IndividualAge", arrow::int32()),        # integer
          arrow::field("CANoAtLngt", arrow::float64()),         # numeric
          arrow::field("IndividualWeight", arrow::float64()),   # numeric
          arrow::field("FishID", arrow::utf8()),                # character
          arrow::field("GeneticSamplingFlag", arrow::utf8()),   # character
          arrow::field("StomachSamplingFlag", arrow::utf8()),   # character
          arrow::field("AgeSource", arrow::utf8()),             # character
          arrow::field("AgePreparationMethod", arrow::utf8()),  # character
          arrow::field("OtolithGrading", arrow::utf8()),        # character
          arrow::field("ParasiteSamplingFlag", arrow::utf8()),  # character
          arrow::field("MaturityScale", arrow::utf8()),         # character
          arrow::field("LiverWeight", arrow::float64()),        # numeric
          arrow::field("AphiaID", arrow::int32()),              # integer
          arrow::field("Species", arrow::utf8()),               # character
          arrow::field("DateofCalculation", arrow::utf8())      # character
        )
    )

  # Ensure the provided recordtype exists in the col_classes definition
  if (!recordtype %in% names(col_classes)) {
    stop("Unknown recordtype: ", recordtype)
  }

  # File search: Ensure the CSV file exists in the specified directory
  csv_file <- list.files(datadir, pattern = "DATRASDataTable\\.csv$", full.names = TRUE)
  if (length(csv_file) == 0) stop("CSV file not found in the specified directory.")

  if (!quiet) message("Reading CSV data...")
  # Read data
  data <- arrow::read_csv_arrow(
    file = csv_file,
    skip = 1L,         # if you have schema then need this
    schema = col_classes[[recordtype]]
  ) |>
    as.data.frame()

  # Replace -9 values with NA
  data[data == -9] <- NA

  # Conduct variable consistency checks

  # Variables in the CSV but not in col_classes

  # Variables in col_classes but not in the CSV

  return(data)
}


