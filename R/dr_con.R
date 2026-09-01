# Two connections, one engine ------------------------------------------------
#
# obus reads two parquet collections that live side by side on the same server:
#
#   .../datras/raw/   the four Tier-1 exchange tables as opus stages them
#                     (HH, HL, CA, LT) -- opus's own current field names, no
#                     `.id`, nothing derived. dr_con_raw().
#   .../datras/       what obus itself builds from those: HH (raw + `.id`),
#                     species, HL_length, HL_summary. dr_con().
#
# Both open onto the SAME DuckDB connection (duckdbfs's cached one). That is
# not incidental -- dr_HL_length()/dr_HL_summary() join a raw HL against
# dr_con("species"), and dbplyr refuses to join two lazy tables held on
# different connections ("`x` and `y` must share the same source"). Verified
# 2026-08-31: opus::op_con() keeps its own private DBI connection, so calling
# it directly here would make that join fail. dr_con_raw() therefore delegates
# the part of op_con() that is genuinely opus's knowledge -- where the archive
# root is, and the invariant that it must be a directory named `raw` -- to
# opus::op_archive(), and opens the file itself on obus's one connection.

DR_RAW_TABLES <- c("HH", "HL", "CA", "LT")
DR_TABLES     <- c("HH", "species", "HL_length", "HL_summary",
                   "hl_flag", "hl_flag_code")

#' Connect to a raw DATRAS exchange table
#'
#' Opens a lazy DuckDB connection to one of the four Tier-1 exchange tables in
#' the raw opus archive. These carry opus's current field names exactly as
#' staged, with no obus-side additions -- in particular no \code{.id} (see
#' \code{\link{dr_add_id}}) and no \code{aphia}/\code{sex} rename.
#'
#' @param table One of \code{"HH"}, \code{"HL"}, \code{"CA"}, \code{"LT"}.
#' @param path Archive root -- a directory named \code{raw}, local or remote.
#'   Defaults to \code{opus::op_archive()}, which honours
#'   \code{getOption("opus.archive")} and falls back to the published archive.
#' @param quiet Logical. If \code{FALSE}, report what was connected to.
#'
#' @return A lazy \code{tbl}. Pipe \code{{dplyr}} verbs and call
#'   \code{\link[dplyr]{collect}}.
#'
#' @seealso \code{\link{dr_con}} for the tables obus derives from these.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con_raw("HH") |>
#'     dplyr::filter(Survey == "NS-IBTS", Year == 2022) |>
#'     dplyr::collect()
#' }
dr_con_raw <- function(table, path = opus::op_archive(), quiet = TRUE) {
  full_path <- .dr_resolve_parquet_path(table, path, DR_RAW_TABLES, quiet)
  duckdbfs::open_dataset(full_path)
}

#' Connect to a derived DATRAS parquet table
#'
#' Opens a lazy DuckDB connection to one of the tables obus builds from the raw
#' archive and publishes alongside it. Nothing downloads until
#' \code{\link[dplyr]{collect}}; \code{{dplyr}} verbs push down to SQL.
#'
#' @param type One of:
#'   \describe{
#'     \item{\code{"HH"}}{The raw haul table with \code{.id} added.}
#'     \item{\code{"species"}}{WoRMS lookup: \code{aphia}, \code{latin},
#'       \code{species} (English common name), \code{rank}, the higher
#'       classification, and WoRMS \code{status}/\code{valid_aphia}.}
#'     \item{\code{"HL_length"}}{One row per \code{.id} x \code{aphia} x
#'       \code{length_mm} x \code{sex}; see \code{\link{dr_HL_length}}.}
#'     \item{\code{"HL_summary"}}{One row per \code{.id} x \code{aphia};
#'       see \code{\link{dr_HL_summary}}.}
#'     \item{\code{"hl_flag"}}{One row per \code{.id} x \code{aphia} x
#'       \code{code}, for records carrying a flag. Long, so a record with
#'       several flags has several rows. Joins onto \code{"HL_summary"}
#'       directly, and onto \code{"HL_length"} as a property of the haul x
#'       species group.}
#'     \item{\code{"hl_flag_code"}}{The flag lookup: \code{code},
#'       \code{kind}, \code{affects}, \code{label}, \code{meaning},
#'       \code{evidence}. \code{kind} is the one to filter on --
#'       \code{"intrinsic"} and \code{"property"} records are not defects.}
#'   }
#' @param path Location of the parquet directory, local or remote. Trailing
#'   slashes are stripped; \code{~} is expanded for local paths.
#' @param quiet Logical. If \code{FALSE}, report what was connected to.
#'
#' @return A lazy \code{tbl}. Pipe \code{{dplyr}} verbs and call
#'   \code{\link[dplyr]{collect}}.
#'
#' @seealso \code{\link{dr_con_raw}} for the raw exchange tables these are
#'   built from.
#' @export
#'
#' @examples
#' \dontrun{
#'   dr_con("HL_summary") |>
#'     dplyr::filter(Survey == "NS-IBTS", Year == 2022) |>
#'     dplyr::collect()
#'
#'   # local build output
#'   dr_con("species", path = "data-raw/to_https")
#' }
dr_con <- function(type, path = "https://heima.hafro.is/~einarhj/datras",
                   quiet = TRUE) {
  full_path <- .dr_resolve_parquet_path(type, path, DR_TABLES, quiet)
  duckdbfs::open_dataset(full_path)
}

# Shared by dr_con_raw() and dr_con(): validate the table name against that
# function's own set, resolve `path` to a concrete file path/URL, and -- for a
# remote path -- confirm the file is actually there before handing it to
# DuckDB. Without the HEAD check a typo or an unpublished table surfaces later
# as an opaque DuckDB HTTP error at collect() time, well away from the call
# that caused it.
.dr_resolve_parquet_path <- function(type, path, valid_types, quiet = TRUE) {

  if (!is.character(type) || length(type) != 1L || is.na(type)) {
    stop("`type` must be a single table name, one of: ",
         paste(valid_types, collapse = ", "), call. = FALSE)
  }
  if (!type %in% valid_types) {
    stop(sprintf("Invalid table '%s'. Valid names are: %s",
                 type, paste(valid_types, collapse = ", ")), call. = FALSE)
  }

  is_local <- !grepl("^https?://", path)

  if (is_local) {
    path <- sub("/+$", "", path.expand(path))
    full_path <- file.path(path, paste0(type, ".parquet"))
    if (!file.exists(full_path)) {
      stop(sprintf("File not found: %s", full_path), call. = FALSE)
    }
  } else {
    path <- sub("/+$", "", path)
    full_path <- paste0(path, "/", type, ".parquet")
    ok <- tryCatch({
      resp <- httr2::request(full_path) |>
        httr2::req_method("HEAD") |>
        httr2::req_perform()
      httr2::resp_status(resp) < 400
    }, error = function(e) FALSE)
    if (!ok) {
      stop(sprintf("'%s' not found or server unreachable.", full_path),
           call. = FALSE)
    }
  }

  if (!quiet) {
    message(sprintf("Connected to %s '%s'",
                    if (is_local) "local" else "remote", full_path))
  }

  full_path
}
