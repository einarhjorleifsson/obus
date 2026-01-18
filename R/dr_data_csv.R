#' Download, extract, and import DATRAS Data
#'
#' This function automates the process of downloading, unzipping, and importing DATRAS
#' (ICES Database of Trawl Surveys) data into R. The year and quarter parameters must be
#' provided as single text strings specifying ranges (e.g., `"2020:2025"` for years and `"1:4"` for quarters).
#' Temporary files are automatically cleaned up.
#'
#' @param recordtype A character string indicating the record type ("HH", "HL", or "CA").
#' @param survey A single character string specifying the survey name.
#' @param year A single text string specifying the range of years as `"start:end"` (e.g., `"2020:2025"`).
#' @param quarter A single text string specifying the range of quarters as `"start:end"` (e.g., `"1:4"`).
#' @param quiet A logical value; if `FALSE`, progress messages are displayed.
#' @param how Text string, any of "parquet", "arrow" or "data.table"
#'
#' @return A data frame containing the requested DATRAS data for the specified year and quarter ranges.
#' @export
#'
dr_read_datras <- function(recordtype, survey, year = 1965:2030, quarter = 1:4, quiet = TRUE, how = "data.table") {

  if(how == "parquet") {
    data <-
      dr_con(type = recordtype, trim = FALSE) |>
      dplyr::filter(Year %in% year,
                    Quarter %in% quarter) |>
      dplyr::collect()
    return(data)
  }

  year <- paste0(min(year), ":", max(year))
  quarter <- paste0(min(quarter), ":", max(quarter))

  # Validate inputs
  if (!is.character(year) || length(year) != 1) {
    stop("The argument 'year' must be a single text string specifying a range, e.g., '2020:2025'.")
  }
  if (!is.character(quarter) || length(quarter) != 1) {
    stop("The argument 'quarter' must be a single text string specifying a range, e.g., '1:4'.")
  }

  if (!quiet) {
    message("Downloading DATRAS data for years: ", year, " and quarters: ", quarter)
  }

  # Temporary file paths
  temp_zip <- tempfile(fileext = ".zip")
  temp_dir <- tempfile()

  # Ensure cleanup occurs even if an error happens
  on.exit(unlink(temp_zip, recursive = TRUE), add = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Download the zip file
  zip_file <- .dr_download_datras_zip(recordtype, survey, year, quarter, destfile = temp_zip, quiet = quiet)

  # Unzip the file
  extracted_dir <- .dr_unzip_datras_file(zip_file, destdir = temp_dir, quiet = quiet)

  # Read the data
  #data <- .dr_read_datras_csv(recordtype, extracted_dir, quiet = quiet)
  if(how == "data.table") data <- .dr_read_datras_csv(recordtype, extracted_dir, quiet = quiet)
  if(how == "arrow")    data <- .dr_read_datras_csv_arrow(recordtype, extracted_dir, quiet = quiet)


  # Return the data frame
  data
}

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

# Internal function to read the CSV file
.dr_read_datras_csv <- function(recordtype, datadir, quiet = TRUE) {

  # Column classes definition
  col_classes <- list(
    HH =
      list(
        character = c("RecordHeader", "Country", "Platform", "Gear", "GearExceptions", "DoorType",
                      "StationName", "StartTime", "DepthStratum", "StatisticalRectangle",
                      "HydrographicStationID", "StandardSpeciesCode", "BycatchSpeciesCode", "Rigging",
                      "DayNight", "ThermoCline", "PelagicSamplingType", "Survey", "DateofCalculation",
                      "HaulValidity", "DataType", "ReasonHaulDisruption", "SurveyIndexArea"),
        integer = c("Quarter", "SweepLength", "HaulNumber", "Year",  "Month", "Day", "HaulDuration", "WarpLength",
                    "WarpDiameter", "WarpDensity", "DoorWeight", "Buoyancy", "TowDirection",
                    "SurfaceCurrentDirection", "BottomCurrentDirection", "WindDirection", "WindSpeed",
                    "SwellDirection", "ThermoClineDepth", "TidePhase", "MinTrawlDepth", "MaxTrawlDepth",
                    "BottomDepth", "CodendMesh", "Tickler", "EDOM"),
        numeric = c("ShootLatitude", "ShootLongitude", "HaulLatitude", "HaulLongitude", "NetOpening", "Distance",
                    "DoorSurface", "DoorSpread", "WingSpread", "KiteArea", "GroundRopeWeight",
                    "SpeedGround", "SpeedWater", "SurfaceCurrentSpeed", "BottomCurrentSpeed",
                    "SwellHeight", "SurfaceTemperature", "BottomTemperature", "SurfaceSalinity",
                    "BottomSalinity", "SecchiDepth", "Turbidity", "TideSpeed" # , "SurveyIndexArea")
        )
      ),
    HL =
      list(
        character = c("RecordHeader","Country","Platform","Gear","GearExceptions","DoorType","StationName","SpeciesCodeType","SpeciesCode","SpeciesValidity",
                      "SpeciesSex","LengthCode","DevelopmentStage","LengthType","Survey","ScientificName_WoRMS","DateofCalculation"),
        integer = c("Year", "Quarter", "SweepLength","HaulNumber","SpeciesCategory","SubsampledNumber","SubsampleWeight","SpeciesCategoryWeight","LengthClass","ValidAphiaID"),
        numeric = c("TotalNumber","SubsamplingFactor","NumberAtLength")
      ),
    CA =
      list(
        character = c("RecordHeader","Country","Platform","Gear","GearExceptions","DoorType","StationName","SpeciesCodeType","SpeciesCode","AreaType","AreaCode",
                      "LengthCode","IndividualSex","IndividualMaturity","AgePlusGroup","MaturityScale","FishID","GeneticSamplingFlag","StomachSamplingFlag","AgeSource",
                      "AgePreparationMethod","OtolithGrading","ParasiteSamplingFlag","Survey","DateofCalculation",
                      "Species"),
        integer = c("Year","Quarter","SweepLength","HaulNumber","LengthClass","IndividualAge"),
        numeric = c("IndividualWeight","LiverWeight",
                    "CANoAtLngt", "AphiaID")
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
  data <- data.table::fread(
    csv_file,
    colClasses = col_classes[[recordtype]],
    fill = TRUE,
    showProgress = !quiet
  ) |>
    as.data.frame()

  # Replace -9 values with NA
  data[data == -9] <- NA

  # Conduct variable consistency checks
  all_varnames <- colnames(data)
  defined_varnames <- unlist(col_classes[[recordtype]])

  # Variables in the CSV but not in col_classes
  extra_vars <- setdiff(all_varnames, defined_varnames)
  if (length(extra_vars) > 0) {
    warning("The following variables are present in the CSV file but not specified in col_classes for recordtype '", recordtype, "': ", paste(extra_vars, collapse = ", "))
  }

  # Variables in col_classes but not in the CSV
  missing_vars <- setdiff(defined_varnames, all_varnames)
  if (length(missing_vars) > 0) {
    warning("The following variables are specified in col_classes for recordtype '", recordtype, "' but are not present in the CSV file: ", paste(missing_vars, collapse = ", "))
  }

  return(data)
}
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


