#' DATRAS field type lookup table
#'
#' A table of column names and their data types across all DATRAS record types.
#' Used internally by \code{.dr_settypes()} to coerce columns to consistent types
#' after fetching data. Regenerate with \code{data-raw/DATASET_lookup_fields.R}.
#'
#' A data frame with 5 columns:
#' \describe{
#'   \item{table}{Record type: "HH", "HL", "CA", "FL", "LT", "CPUEL", "CPUEA", "IDX"}
#'   \item{new}{Column name as returned by \code{icesDatras::get_datras_unaggregated_data} (new-style)}
#'   \item{old}{Column name as returned by \code{icesDatras::getDATRAS} and derived products (old-style)}
#'   \item{DataFormat}{Type: "char", "int", or "decimal"}
#'   \item{Description}{Field description from the ICES web service}
#' }
#' @source <https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList>
#'   plus hand-curated entries for FL, LT, CPUEL, CPUEA, and IDX.
"dr_lookup_fields"


#' A table of english and latin species names and aphia
#'
#' A data frame with over 2000 rows and 3 columns:
#' \describe{
#'   \item{aphia}{Species id in the DATRAS exchange data}
#'   \item{latin}{Species latin name}
#'   \item{species}{Species english name}
#' }
#'
#' @source R-package worrms and aphia in HL- and CA-tables
"dr_lookup_species"


#' Simple shoreline for ICES area
#'
#' Simple shapefile
#' @source R-package rnaturalearth
"dr_coastline"

