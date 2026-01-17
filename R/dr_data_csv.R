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
#'
#' @return A data frame containing the requested DATRAS data for the specified year and quarter ranges.
#' @export
#'
dr_read_datras <- function(recordtype, survey, year, quarter, quiet = TRUE) {

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
  data <- .dr_read_datras_csv(recordtype, extracted_dir, quiet = quiet)

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
  download.file(full_url, destfile, mode = "wb", quiet = quiet)

  destfile
}

# Internal function to unzip the downloaded file
.dr_unzip_datras_file <- function(zipfile, destdir = tempfile(), quiet = TRUE) {
  if (!quiet) message("Extracting files...")
  dir.create(destdir, showWarnings = FALSE)
  unzip(zipfile, exdir = destdir)

  destdir
}

# Internal function to read the CSV file
.dr_read_datras_csv <- function(recordtype, datadir, quiet = TRUE) {

  # Column classes definition
  col_classes <- list(
    HH =
      list(
        character = c("RecordHeader", "Country", "Platform", "Gear", "GearExceptions", "DoorType",
                      "StationName", "Year", "StartTime", "DepthStratum", "StatisticalRectangle",
                      "HydrographicStationID", "StandardSpeciesCode", "BycatchSpeciesCode", "Rigging",
                      "DayNight", "ThermoCline", "PelagicSamplingType", "Survey", "DateofCalculation",
                      "HaulValidity", "DataType", "ReasonHaulDisruption", "SurveyIndexArea"),
        integer = c("Quarter", "SweepLength", "HaulNumber", "Month", "Day", "HaulDuration", "WarpLength",
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
        character = c("RecordHeader","Country","Platform","Gear","GearExceptions","DoorType","StationName","Year","SpeciesCodeType","SpeciesCode","SpeciesValidity",
                      "SpeciesSex","LengthCode","DevelopmentStage","LengthType","Survey","ScientificName_WoRMS","DateofCalculation"),
        integer = c("Quarter","SweepLength","HaulNumber","SpeciesCategory","SubsampledNumber","SubsampleWeight","SpeciesCategoryWeight","LengthClass","ValidAphiaID"),
        numeric = c("TotalNumber","SubsamplingFactor","NumberAtLength")
      ),
    CA =
      list(
        character = c("RecordHeader","Country","Platform","Gear","GearExceptions","DoorType","StationName","Year","SpeciesCodeType","SpeciesCode","AreaType","AreaCode",
                      "LengthCode","IndividualSex","IndividualMaturity","AgePlusGroup","MaturityScale","FishID","GeneticSamplingFlag","StomachSamplingFlag","AgeSource",
                      "AgePreparationMethod","OtolithGrading","ParasiteSamplingFlag","Survey","DateofCalculation",
                      "Species"),
        integer = c("Quarter","SweepLength","HaulNumber","LengthClass","IndividualAge"),
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


