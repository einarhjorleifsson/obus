#' Datras variable types
#'
#' A table containing the variable (field) types of the datras data
#'
#' A data frame with 125 rows and 3 columns:
#' \describe{
#'   \item{field}{DATRAS variable name as returned by icesDatras::getDATRAS}
#'   \item{type}{The value type}
#'   \item{record}{The DATRAS data type - "HH": haul data, "HL": length-based data, "CA": age-based data}
#' }
#' @source <https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_May2022.xlsx>
"dr_coltypes"


#' Coastline covering majority of DATRAS data
#'
#' A data frame with over 2000 rows and 3 columns:
#' \describe{
#'   \item{Valid_Aphia}{Species id in the DATRAS exchange data}
#'   \item{latin}{Species latin name}
#'   \item{species}{Species english name}
#' }
#'
#' @source R-package worrms
"dr_latin_aphia"


#' A valid aphia id - latin name lookup
#'
#' Simple shapefile
#' @source R-package rnaturalearth
"dr_coastline"

