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


