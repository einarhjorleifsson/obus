# Currently there are three ways to read DATRAS data into memory
#  1. icesDatras::getDATRAS - the old faithful
#  2. icesDatras:::getDatrasUnaggregated - new API, faster
#  3. read a parquet file, all data


#' Download and Import DATRAS Data
#'
#' This function streamlines the retrieval of DATRAS trawl survey data from
#' various sources, offering distinct methods for fetching and loading the data:
#' - `"old"`: Retrieves data using the legacy `icesDatras::getDATRAS` function.
#' - `"new"`: Retrieves data using `icesDatras:::getDatrasUnaggregated` function.
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
    url <- paste0("https://heima.hafro.is/~einarhj/datras/", recordtype, ".parquet")
    data <- arrow::read_parquet(url)
    return(data)
  }

  if(from == "old") {
    if(quiet == TRUE) {
      data <- suppressMessages(purrr::map2(recordtype,
                                           surveys,
                                           icesDatras::getDATRAS,
                                           years,
                                           quarters))
    } else {
      data <- purrr::map2(recordtype,
                          surveys,
                          icesDatras::getDATRAS,
                          years,
                          quarters)
    }
    i <- purrr::map_chr(data, class) == "data.frame"
    data <- data[i]

    .dr_settypes <- function(d) {

      key_chr <- dr_fields |> dplyr::filter(DataFormat == "char")    |> tidyr::drop_na() |> dplyr::pull(FieldNameOld) |> unique()
      key_int <- dr_fields |> dplyr::filter(DataFormat == "int")     |> tidyr::drop_na()     |> dplyr::pull(FieldNameOld) |> unique()
      key_dbl <- dr_fields |> dplyr::filter(DataFormat == "decimal") |> tidyr::drop_na() |> dplyr::pull(FieldNameOld) |> unique()

      d <-
        d |>
        dplyr::mutate(dplyr::across(dplyr::any_of(key_chr), as.character))  |>
        dplyr::mutate(dplyr::across(dplyr::any_of(key_int), as.integer))  |>
        dplyr::mutate(dplyr::across(dplyr::any_of(key_dbl), as.numeric))

      return(d)

    }

    data <-
      data |>
      purrr::map(.dr_settypes) |>
      dplyr::bind_rows()

    data[data == -9] <- NA

    return(data)
  }

  if(from == "new") {

    years_c <- paste0(min(years), ":", max(years))
    quarters_c <- paste0(min(quarters), ":", max(quarters))

    data <- suppressMessages(purrr::map2(recordtype,
                                         surveys,
                                         icesDatras::get_datras_unaggregated_data,
                                         years_c,
                                         quarters_c))
    i <- purrr::map_int(data, nrow) > 0
    data <- dplyr::bind_rows(data[i]) |> as.data.frame()
    data[data == -9] <- NA

    if(nrow(data) > 0) {

      data <- data |> dplyr::filter(RecordHeader != "")

      if(recordtype == "CA") {
        data <-
          data |>
          dplyr::rename(ScientificName_WoRMS = Species,
                        ValidAphiaID = AphiaID)
      }
    }

    # Return the data frame
    return(data)
  }

}



#' Get DATRAS Field Specifications
#'
#' This function fetches XML data from the DATRAS web service, parses the content,
#' and returns the field specifications as a data frame.
#'
#' @param url A character string specifying the URL of the DATRAS web service.
#' Defaults to `"https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"`.
#'
#' @return A tibble (data frame) containing the field specifications with the
#' following columns:
#' \itemize{
#'   \item \code{RecordHeader}: A character string indicating the record header type.
#'   \item \code{FieldName}: A character string specifying the field name.
#'   \item \code{FieldNameOld}: A character string specifying the old field name.
#'   \item \code{DataFormat}: A character string representing the format of the data.
#'   \item \code{Description}: A character string describing the field.
#' }
#'
#' @examples
#' # Fetch the default DATRAS field specifications:
#' specs <- dr_get_fields()
#'
#' # View the first few rows:
#' head(specs)
#'
#' @export
dr_get_fields <- function(url = "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList") {

  # Send the HTTP request using httr2
  response <- httr2::request(url) |>
    httr2::req_perform()

  # Check the HTTP status code for success
  if (httr2::resp_status(response) == 200) {
    # Extract the response body as text
    xml_data <- httr2::resp_body_string(response)
    parsed_xml <- suppressWarnings(xml2::read_xml(xml_data))

    # Manually bind the default namespace ("xmlns") to a prefix ("d")
    ns <- c(d = "ices.dk.local/DATRAS")  # Bind the namespace to the prefix "d"

    # Extract the data into a data frame
    d <-
      parsed_xml |>
      xml2::xml_find_all("//d:Cls_Datras_FieldList", ns = ns) |>  # Use "d:" for namespace
      purrr::map_df(~ dplyr::tibble(
        RecordHeader = xml2::xml_text(xml2::xml_find_first(.x, "./d:RecordHeader", ns = ns)),
        FieldName = xml2::xml_text(xml2::xml_find_first(.x, "./d:FieldName", ns = ns)),
        FieldNameOld = xml2::xml_text(xml2::xml_find_first(.x, "./d:FieldNameOld", ns = ns)),
        DataFormat = xml2::xml_text(xml2::xml_find_first(.x, "./d:DataFormat", ns = ns)),
        Description = xml2::xml_text(xml2::xml_find_first(.x, "./d:Description", ns = ns))
      )) |>
      # get rid of extra space, including new line
      dplyr::mutate(RecordHeader = stringr::str_trim(RecordHeader),
                    FieldName = stringr::str_trim(FieldName),
                    FieldNameOld = stringr::str_trim(FieldNameOld),
                    DataFormat = stringr::str_trim(DataFormat),
                    Description = stringr::str_trim(Description),
                    FieldNameOld = ifelse(FieldNameOld == "-", NA, FieldNameOld),
                    # Check with Vaisav
                    DataFormat = dplyr::case_when(FieldName == "Year" ~ "int",
                                                  FieldName == "Distance" ~ "decimal",
                                                  .default = DataFormat),
                    FieldNameOld = dplyr::case_when(FieldName == "Survey" ~ "Survey",
                                                    .default = FieldNameOld))

    add <-
      tibble::tribble(~RecordHeader, ~FieldName,             ~FieldNameOld,    ~DataFormat,
                      "FL",          "RecordHeader",          "RecordHeader",   "char",
                      "FL",          "Survey",                "Survey",         "char",
                      "FL",          "Quarter",               "Quarter",        "int",
                      "FL",          "Country",               "Country",        "char",
                      "FL",          "Platform",              "Ship",           "char",
                      "FL",          "Gear",                  "Gear",           "char",
                      "FL",          "HaulNumber",            "HaulNo",         "int",
                      "FL",          "Year",                  "Year",           "int",
                      "FL",          "Month",                 "Month",          "int",
                      "FL",          "Day",                   "Day",            "int",
                      "FL",          "StartTime",             "TimeShot",       "char",
                      "FL",          "DepthStratum",          "DepthStratum",   "char",
                      "FL",          "HaulDuration",          "HaulDur",        "int",
                      "FL",          "DayNight",              "DayNight",       "char",
                      "FL",          "ShootLatitude",         "ShootLat",       "decimal",
                      "FL",          "ShootLongitude",        "ShootLong",      "decimal",
                      "FL",          "StatisticalRectangle",  "StatRec",        "char",
                      "FL",          NA,                      "ICESArea",       "char",
                      "FL",          "SweepLength",           "SweepLngt",      "int",
                      "FL",          "BottomDepth",           "Depth",          "int",
                      "FL",          "HaulValidity",          "HaulVal",        "char",
                      "FL",          "DataType",              "DataType",       "char",
                      "FL",          "WarpLength",            "Warplngt",       "int",
                      "FL",          "DoorSpread",            "DoorSpread",     "decimal",
                      "FL",          "WingSpread",            "WingSpread",     "decimal",
                      "FL",          "Distance",              "Distance",       "int",
                      "FL",          NA,                      "Cal_DoorSpread", "decimal",
                      "FL",          NA,                      "DSflag",         "char",
                      "FL",          NA,                      "Cal_WingSpread", "decimal",
                      "FL",          NA,                      "WSflag",         "char",
                      "FL",          NA,                      "Cal_Distance",   "decimal",
                      "FL",          NA,                      "DistanceFlag",   "char",
                      "FL",          NA,                      "SweptAreaDSKM2", "decimal",
                      "FL",          NA,                      "SweptAreaWSKM2", "decimal"
      )
    d <- dplyr::bind_rows(d, add)

    return(d)
  } else {
    stop("Failed to fetch data. Status code: ", httr2::resp_status(response))
  }
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


