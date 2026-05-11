#' Datras variable types
#'
#' A table containing the variable (field) types of the datras data
#'
#' A data frame with 208 rows and 5 columns:
#' \describe{
#'   \item{RecordHeader}{The DATRAS data type - "HH": haul data, "HL": length-based data, "CA": age-based data}
#'   \item{FieldName}{DATRAS variable name as returned by icesDatras::get_datras_unaggregated_data}
#'   \item{FieldNameOld}{DATRAS variable name as returned by icesDatras::getDatras}
#'   \item{DataFormat}{The value type, char (character), int (ingeger) and decimal (numeric)}
#'   \item{Description}{Some description}
#' }
#' @source <https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList> and then some
"dr_fields"


#' Coastline covering majority of DATRAS data
#'
#' A data frame with over 2000 rows and 3 columns:
#' \describe{
#'   \item{aphia}{Species id in the DATRAS exchange data}
#'   \item{latin}{Species latin name}
#'   \item{species}{Species english name}
#' }
#'
#' @source R-package worrms
"dr_latin_aphia"


#' #' A valid aphia id - latin name lookup
#' #'
#' #' Simple shapefile
#' #' @source R-package rnaturalearth
#' "dr_coastline"

