# Currently there are three ways to read DATRAS data into memory
#  1. icesDatras::getDATRAS - the old faithful
#  2. icesDatras::get_datras_unaggregated_data - new API, faster
#  3. read a parquet file, all data


#' Download and Import DATRAS Data
#'
#' This function streamlines the retrieval of DATRAS trawl survey data from
#' various sources, offering distinct methods for fetching and loading the data:
#' - `"old"`: Retrieves data using the legacy `icesDatras::getDATRAS` function.
#' - `"new"`: Uses the `icesDatras::get_datras_unaggregated_data` function.
#' - `"parquet"`: Reads directly from Parquet files via URL. survey, year, and
#' quarter filter not applied.
#'
#' Year and quarter ranges must be specified, and datasets are filtered accordingly.
#' Surveys supported by ICES can be automatically retrieved if unspecified.
#'
#' @param recordtype A string specifying the record type ("HH", "HL", or "CA"), indicating the data structure to retrieve.
#' @param surveys A character vector of survey IDs. Defaults to all ICES-recognized surveys, excluding "Test-DATRAS".
#' @param years An integer vector of years (e.g., `1965:2030`). Values outside the range `[1965, current year]` are invalid.
#' @param quarters An integer vector (e.g., `1:4`) representing quarter ranges.
#' @param quiet Logical; suppresses progress messages if `TRUE` (default).
#' @param from String (default 'parquet') specifying the data source: `"old"`, `"new"`, or `"parquet"`.
#' @return A data frame containing DATRAS data filtered by the specified parameters
#' if from is 'old' or 'new'.
#'
#' @examples
#' \dontrun{
#'   # Download haul-level data (new API)
#'   dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, quarters = c(1, 3), from = "new")
#'
#'   # Read full dataset
#'   dr_get("HL")
#' }
#' @export
dr_get <- function(recordtype, surveys = NULL, years = 1965:2030, quarters = 1:4, from = "parquet", quiet = TRUE) {

  # input checks
  # add years checks - just check that it is at minimum any values (year) between 1965 and current year
  #  only warning/stop if it outside the range 1965 and current year
  # add quarter checks - check that it is any of 1, 2, 3, 4

  if(is.null(surveys)) {
    surveys <- icesDatras::getSurveyList()
    surveys <- surveys[surveys != "Test-DATRAS"]
  }

  if(from == "parquet") {
    url <- paste0("https://heima.hafro.is/~einarhj/datras_latin/", recordtype, ".parquet")
    data <- arrow::read_parquet(url)
    return(data)
  }

  if(from == "old") {
    if(quiet == TRUE) {
      data <- purrr::map2(recordtype,
                          surveys,
                          # this does not work
                          suppressMessages(icesDatras::getDATRAS),
                          years,
                          quarters)
    } else {
      data <- purrr::map2(recordtype,
                          surveys,
                          icesDatras::getDATRAS,
                          years,
                          quarters)
    }
    i <- purrr::map_chr(data, class) == "data.frame"
    data <- data[i]
    data <- purrr::map(data, dr_settypes)
    data <- data |> dplyr::bind_rows()
    return(data)
  }

  if(from == "new") {

    years_c <- paste0(min(years), ":", max(years))
    quarters_c <- paste0(min(quarters), ":", max(quarters))

    data <- purrr::map2(recordtype,
                        surveys,
                        icesDatras::get_datras_unaggregated_data,
                        years_c,
                        quarters_c)
    i <- purrr::map_int(data, nrow) > 0
    data <- dplyr::bind_rows(data[i]) |> as.data.frame()
    # data[data == -9] <- NA
    data <- data |> dplyr::filter(RecordHeader != "")

    if(recordtype == "CA") {
      data <-
        data |>
        dplyr::rename(ScientificName_WoRMS = Species,
                      ValidAphiaID = AphiaID)
    }

    # Return the data frame
    return(data)
  }

}

# Below is not really in use ---------------------------------------------------
# Internal function to download the zip file
.dr_download_datras_zip <- function(recordtype, survey, year, quarter, destfile = tempfile(fileext = ".zip"), quiet = TRUE) {
  base_url <- "https://datras.ices.dk/Data_products/Download/DATRASDownloadAPI.aspx"
  full_url <- paste0(
    base_url, "?recordtype=", recordtype,
    "&survey=", survey, "&year=", year, "&quarter=", quarter
  )

  if (!quiet) message("Downloading data...")
  utils::download.file(full_url, destfile, mode = "wb", quiet = quiet)

  destfile
}

# Internal function to unzip the downloaded file
.dr_unzip_datras_file <- function(zipfile, destdir = tempfile(), quiet = TRUE) {
  if (!quiet) message("Extracting files...")
  dir.create(destdir, showWarnings = FALSE)
  utils::unzip(zipfile, exdir = destdir)

  destdir
}


# Create a mapping of conversion functions for each type
.conversion_funcs <- list(
  character = as.character,
  integer = as.integer,
  numeric = as.numeric
)

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


