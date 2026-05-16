#' Fetch DATRAS Survey Area Polygons
#'
#' Downloads DATRAS survey area polygons from the ICES ArcGIS REST service and
#' returns them as an \code{sf} object (EPSG:4326). Each row is one spatial
#' polygon (or multipolygon) associated with a survey's sampling stratum or
#' individual ICES rectangle.
#'
#' @section Data source:
#' Data are fetched from:
#' \url{https://gis.ices.dk/gis/rest/services/ICES_Datasets/Datras_service_prod/MapServer/0}
#'
#' @section Valid flag:
#' The layer contains two types of polygons per survey:
#' \itemize{
#'   \item \strong{Valid = 1} — named strata / survey sub-areas (e.g. NS-IBTS
#'     areas 1–10). These are the polygons used in DATRAS derived products.
#'   \item \strong{Valid = 0} — additional spatial features associated with the
#'     survey domain (the exact meaning varies by survey).
#' }
#' By default both are returned; filter with \code{valid = 1} or \code{valid = 0}
#' to restrict to one type.
#'
#' @section Columns returned:
#' \describe{
#'   \item{Survey}{Survey acronym (e.g. \code{"NS-IBTS"}). Renamed from
#'     \code{DatasetVer} in the source.}
#'   \item{AreaName}{Area / stratum name.}
#'   \item{SubareaName}{Sub-area name (often \code{NA}).}
#'   \item{Description}{Human-readable description (often \code{NA}).}
#'   \item{Valid}{Integer flag: 1 = named stratum used in DATRAS products; 0 = other survey-associated feature.}
#'   \item{SurveyCode}{Internal integer survey code.}
#'   \item{Year}{Year string, only populated for surveys with year-specific areas
#'     (e.g. NS-IDPS).}
#'   \item{geometry}{Polygon / multipolygon geometry (EPSG:4326).}
#' }
#'
#' @param surveys Character vector of survey acronyms to retain (matched against
#'   the \code{Survey} / \code{DatasetVer} field). \code{NULL} (default) returns
#'   all surveys.
#' @param valid Integer scalar (0 or 1) to filter by the \code{Valid} flag, or
#'   \code{NULL} (default) to return both types.
#' @param quiet Logical. If \code{TRUE} (default), suppresses progress messages.
#'
#' @return An \code{sf} object with EPSG:4326 polygons.
#'
#' @examples
#' \dontrun{
#' # All areas for all surveys
#' areas <- dr_get_areas()
#'
#' # Named strata only for NS-IBTS
#' ns_strata <- dr_get_areas(surveys = "NS-IBTS", valid = 1)
#'
#' # Valid = 0 features for BITS
#' bits_v0 <- dr_get_areas(surveys = "BITS", valid = 0)
#' }
#'
#' @export
dr_get_areas <- function(surveys = NULL, valid = NULL, quiet = TRUE) {

  base_url <- paste0(
    "https://gis.ices.dk/gis/rest/services/",
    "ICES_Datasets/Datras_service_prod/MapServer/0/query"
  )

  # Build server-side WHERE clause to minimise download size
  where_parts <- "1=1"

  if (!is.null(surveys)) {
    surveys <- as.character(surveys)
    quoted  <- paste0("'", surveys, "'", collapse = ", ")
    where_parts <- paste0(where_parts, " AND DatasetVer IN (", quoted, ")")
  }

  if (!is.null(valid)) {
    where_parts <- paste0(where_parts, " AND Valid = ", as.integer(valid)[1L])
  }

  if (!quiet) {
    message("Fetching DATRAS survey areas from ICES GIS ...")
  }

  # Paginate in case the layer grows beyond maxRecordCount (currently 2000)
  max_per_page <- 2000L
  offset       <- 0L
  pages        <- list()

  repeat {
    resp <- httr2::request(base_url) |>
      httr2::req_url_query(
        where             = where_parts,
        outFields         = "DatasetVer,AreaName,SubareaName,Description,Valid,SurveyCode,Year",
        f                 = "geojson",
        resultOffset      = offset,
        resultRecordCount = max_per_page
      ) |>
      httr2::req_perform()

    page_sf <- sf::st_read(httr2::resp_body_string(resp), quiet = TRUE)

    if (nrow(page_sf) == 0L) break

    pages  <- c(pages, list(page_sf))
    offset <- offset + nrow(page_sf)

    if (nrow(page_sf) < max_per_page) break
  }

  if (length(pages) == 0L) {
    if (!quiet) message("No features returned.")
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }

  out <- do.call(rbind, pages)

  # Rename DatasetVer → Survey to match obus naming conventions
  names(out)[names(out) == "DatasetVer"] <- "Survey"

  if (!quiet) {
    message(sprintf("Retrieved %d features for %d survey(s).",
                    nrow(out),
                    length(unique(out$Survey))))
  }

  out
}
