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
#'   \item{format}{Type: "chr", "int", or "dbl"}
#'   \item{description}{Field description from the ICES web service}
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


#' ICES vocabulary lookup table for DATRAS fields
#'
#' Valid codes and their descriptions for the categorical fields used in DATRAS
#' exchange data, sourced from the ICES vocabulary server. Only fields present
#' in \code{dr_lookup_fields} (old-style names) are retained; calendar fields
#' (\code{Month}, \code{Quarter}, \code{Year}) are excluded. Regenerate with
#' \code{data-raw/DATASET_vocabulary.R}.
#'
#' A data frame with 6 columns:
#' \describe{
#'   \item{old}{Old-style DATRAS column name (as returned by
#'     \code{icesDatras::getDATRAS} and derived products).}
#'   \item{new}{New-style column name (as returned by
#'     \code{icesDatras::get_datras_unaggregated_data}); \code{NA} where no
#'     mapping exists.}
#'   \item{key}{The valid code value (character) as it appears in the data,
#'     e.g. \code{"V"}, \code{"GOV"}, \code{"M"}.}
#'   \item{description}{Human-readable label for the code, e.g.
#'     \code{"Valid haul"}, \code{"Grand Opening Vertical trawl"}.}
#'   \item{type}{ICES vocabulary type key, e.g. \code{"TS_HaulVal"},
#'     \code{"Gear"}. Prefixes \code{TS_} and \code{AC_} are stripped when
#'     matching against \code{old} column names.}
#'   \item{type_desc}{Human-readable description of the vocabulary type,
#'     e.g. \code{"Haul Validity Codes"}, \code{"Gear Types"}.}
#' }
#'
#' @source \code{icesVocab::getCodeTypeList()} and \code{icesVocab::getCodeList()}
#'   via the ICES vocabulary server <https://vocab.ices.dk/>.
"dr_lookup_vocabulary"

