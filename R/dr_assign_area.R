#' Assign Survey Strata to Hauls by Position
#'
#' Spatially joins haul shoot positions to survey area polygons, adding one or
#' more area attribute columns to the haul table.
#'
#' @section Two-path design:
#' The function follows a strict type convention:
#'
#' \describe{
#'   \item{Data frame path}{When \code{d} is a collected \code{data.frame},
#'     \code{areas} must be an \code{sf} object (or \code{NULL}, which uses the
#'     bundled \code{\link{dr_lookup_areas}}). The join is done with
#'     \code{sf::st_join()}.}
#'   \item{DuckDB path}{When \code{d} is a \code{tbl_duckdb_connection},
#'     \code{areas} must be a \code{tbl_duckdb_connection} (or \code{NULL},
#'     which auto-converts \code{\link{dr_lookup_areas}} via a temporary
#'     FlatGeobuf file). The join is executed entirely inside DuckDB using
#'     \code{ST_Within(ST_Point(lon, lat), geom)} — no data is moved to R.
#'     The result is a new lazy table.}
#' }
#'
#' @section Providing custom areas:
#' Supply your own \code{sf} polygon layer (data frame path) or
#' \code{tbl_duckdb_connection} (DuckDB path) as \code{areas}. Any column(s)
#' named in \code{keep_cols} are appended. Common sources:
#' \itemize{
#'   \item \code{dr_get_areas()} for live full-resolution ICES polygons.
#'   \item \code{duckdbfs::open_dataset("https://.../areas.fgb")} for
#'     the server FlatGeobuf — the DuckDB path requires the geometry column
#'     to be named \code{geom}.
#'   \item Any user-supplied \code{sf} or spatial file opened as a duckdb
#'     connection.
#' }
#'
#' @section Survey filtering:
#' Whenever both \code{d} and \code{areas} contain a \code{Survey} column the
#' join is additionally constrained to \code{h.Survey = a.Survey}, preventing
#' false-positive matches where surveys have geographically overlapping strata.
#' This applies whether \code{areas} is the default \code{\link{dr_lookup_areas}}
#' or a custom object (e.g. the server FlatGeobuf).  To suppress it, drop or
#' rename the \code{Survey} column from \code{areas} before passing.
#'
#' @section FlatGeobuf on server:
#' A full-resolution FlatGeobuf is available at
#' \code{https://heima.hafro.is/~einarhj/datras/areas.fgb} (all Valid
#' classes). Use it with:
#' \preformatted{
#' areas_con <- duckdbfs::open_dataset(
#'   "https://heima.hafro.is/~einarhj/datras/areas.fgb"
#' )
#' hh_con |> dr_assign_area(areas = areas_con)
#' }
#'
#' @param d An HH data frame or lazy \code{tbl_duckdb_connection}.
#' @param areas \code{NULL} (use \code{\link{dr_lookup_areas}}), an \code{sf}
#'   object (data frame path), or a \code{tbl_duckdb_connection} (DuckDB path).
#' @param lon Longitude column name in \code{d}. Default
#'   \code{"ShootLongitude"} (new-style). Old-style: \code{"ShootLong"}.
#' @param lat Latitude column name in \code{d}. Default
#'   \code{"ShootLatitude"} (new-style). Old-style: \code{"ShootLat"}.
#' @param keep_cols Character vector of column names from \code{areas} to
#'   append to \code{d}. Default \code{"AreaName"}. The geometry column
#'   (\code{geom} / \code{geometry}) is never included.
#' @param quiet Logical. If \code{TRUE} (default), suppresses progress messages.
#'
#' @return \code{d} with \code{keep_cols} appended. Hauls outside all polygons
#'   get \code{NA}. For the DuckDB path the result is a new lazy table; for
#'   the data frame path it is a \code{data.frame}. Overlapping polygons in
#'   \code{areas} may produce duplicate rows.
#'
#' @seealso \code{\link{dr_get_areas}}, \code{\link{dr_lookup_areas}},
#'   \code{\link{dr_add_id}}
#'
#' @examples
#' \dontrun{
#' # ── Data frame path ────────────────────────────────────────────────────────
#' hh <- dr_get("HH", surveys = "NS-IBTS", years = 2023, quarters = 1) |>
#'   dr_add_id()
#' hh |> dr_assign_area()                             # default bundled strata
#' hh |> dr_assign_area(areas = dr_get_areas("NS-IBTS", valid = 1))  # live fetch
#' hh |> dr_assign_area(areas = my_sf, keep_cols = "zone_id")        # custom
#'
#' # ── DuckDB path ────────────────────────────────────────────────────────────
#' hh_con <- duckdbfs::open_dataset("https://.../HH.parquet") |>
#'   dplyr::filter(Survey == "NS-IBTS", Year == 2023) |>
#'   dr_add_id()
#' hh_con |> dr_assign_area()          # auto-converts dr_lookup_areas
#'
#' # server FlatGeobuf, filtered to Valid = 1 before passing
#' areas_con <- duckdbfs::open_dataset(
#'   "https://heima.hafro.is/~einarhj/datras/areas.fgb"
#' ) |> dplyr::filter(Valid == 1L)
#' hh_con |> dr_assign_area(areas = areas_con)
#' }
#'
#' @export
dr_assign_area <- function(d,
                           areas     = NULL,
                           lon       = "ShootLongitude",
                           lat       = "ShootLatitude",
                           keep_cols = "AreaName",
                           quiet     = TRUE) {

  is_lazy <- inherits(d, "tbl_duckdb_connection")

  # ── Resolve default areas ──────────────────────────────────────────────────
  if (is.null(areas)) {
    if (is_lazy) {
      areas <- .dr_lookup_areas_as_dataset()
    } else {
      areas <- dr_lookup_areas
    }
  }

  # Apply Survey filter whenever both tables carry a Survey column.
  # This prevents cross-survey false matches with spatially overlapping strata
  # and works regardless of whether areas came from the default or a custom source.
  use_survey_filter <- "Survey" %in% colnames(d) && "Survey" %in% colnames(areas)

  # ── Dispatch ───────────────────────────────────────────────────────────────
  if (is_lazy) {
    .dr_assign_area_duckdb(d, areas, lon, lat, keep_cols, use_survey_filter, quiet)
  } else {
    .dr_assign_area_sf(d, areas, lon, lat, keep_cols, use_survey_filter, quiet)
  }
}


# ── DuckDB path ────────────────────────────────────────────────────────────────
.dr_assign_area_duckdb <- function(d, areas, lon, lat, keep_cols,
                                   use_survey_filter, quiet) {

  if (!inherits(areas, "tbl_duckdb_connection"))
    stop("dr_assign_area: when `d` is a DuckDB lazy table, `areas` must also ",
         "be a tbl_duckdb_connection (or NULL for the default).")

  con       <- duckdbfs::cached_connection()
  d_sql     <- as.character(dbplyr::sql_render(d))
  areas_sql <- as.character(dbplyr::sql_render(areas))

  cols_clause   <- paste(paste0("a.", keep_cols), collapse = ", ")
  survey_clause <- if (use_survey_filter) "AND h.Survey = a.Survey" else ""

  sql <- sprintf(
    "SELECT h.*, %s
     FROM (%s) h
     LEFT JOIN (%s) a
       ON ST_Within(ST_Point(h.%s, h.%s), a.geom)
     %s",
    cols_clause, d_sql, areas_sql, lon, lat, survey_clause
  )

  if (!quiet) message("Running DuckDB spatial join ...")
  dplyr::tbl(con, dplyr::sql(sql))
}


# ── sf / data frame path ───────────────────────────────────────────────────────
.dr_assign_area_sf <- function(d, areas, lon, lat, keep_cols,
                               use_survey_filter, quiet) {

  if (!inherits(areas, "sf"))
    stop("dr_assign_area: when `d` is a data frame, `areas` must be an sf ",
         "object (or NULL for the default).")

  # Coordinate columns present?
  missing_coords <- setdiff(c(lon, lat), names(d))
  if (length(missing_coords) > 0)
    stop("dr_assign_area: coordinate column(s) not found in d: ",
         paste(missing_coords, collapse = ", "))

  # Survey-aware filtering for the default areas
  if (use_survey_filter && "Survey" %in% names(areas)) {
    d_surveys <- unique(d[["Survey"]])
    areas     <- dplyr::filter(areas, .data$Survey %in% d_surveys)
    if (!quiet)
      message(sprintf("Using %d area polygon(s) for survey(s): %s",
                      nrow(areas),
                      paste(sort(unique(areas$Survey)), collapse = ", ")))
  }

  # Validate keep_cols
  missing_cols <- setdiff(keep_cols, names(areas))
  if (length(missing_cols) > 0)
    stop("dr_assign_area: column(s) not found in areas: ",
         paste(missing_cols, collapse = ", "))

  # Warn about columns being overwritten
  already_present <- intersect(keep_cols, names(d))
  if (length(already_present) > 0 && !quiet)
    message("dr_assign_area: overwriting existing column(s): ",
            paste(already_present, collapse = ", "))
  d <- d[, setdiff(names(d), keep_cols), drop = FALSE]

  # NA-coordinate rows → NA areas (handled by keeping them separate)
  valid_coords <- !is.na(d[[lon]]) & !is.na(d[[lat]])
  n_invalid    <- sum(!valid_coords)
  if (n_invalid > 0 && !quiet)
    message(sprintf("dr_assign_area: %d row(s) with NA coordinates will get NA area.",
                    n_invalid))

  pts <- sf::st_as_sf(
    d[valid_coords, , drop = FALSE],
    coords = c(lon, lat),
    crs    = 4326,
    remove = FALSE
  )

  # Planar st_within (s2 off to avoid topology warnings at this scale)
  old_s2 <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(old_s2), add = TRUE)

  joined <- sf::st_join(pts, areas[, keep_cols], join = sf::st_within, left = TRUE)
  sf::st_geometry(joined) <- NULL

  # Keep first match if custom areas overlap
  npts <- nrow(d[valid_coords, , drop = FALSE])
  if (nrow(joined) > npts) {
    if (!quiet)
      message("dr_assign_area: some points matched multiple polygons; keeping first match.")
    joined <- joined[!duplicated(joined[, setdiff(names(joined), keep_cols), drop = FALSE]), ]
  }

  # Re-attach NA-coordinate rows
  if (n_invalid > 0) {
    na_rows <- d[!valid_coords, , drop = FALSE]
    for (col in keep_cols) na_rows[[col]] <- NA
    joined <- dplyr::bind_rows(joined, na_rows)
  }

  joined
}


# ── Convert dr_lookup_areas to a duckdbfs lazy table (cached) ─────────────────
.obus_env <- new.env(parent = emptyenv())

.dr_lookup_areas_as_dataset <- function() {
  if (!is.null(.obus_env$areas_fgb_path) &&
      file.exists(.obus_env$areas_fgb_path)) {
    return(duckdbfs::open_dataset(.obus_env$areas_fgb_path))
  }
  tmp <- tempfile(fileext = ".fgb")
  old_s2 <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  sf::st_write(dr_lookup_areas, tmp, driver = "FlatGeobuf",
               quiet = TRUE, delete_dsn = TRUE)
  sf::sf_use_s2(old_s2)
  .obus_env$areas_fgb_path <- tmp
  duckdbfs::open_dataset(tmp)
}
