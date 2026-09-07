# Two connections, one engine ------------------------------------------------
#
# obus reads two parquet collections that live side by side on the same server:
#
#   .../datras/raw/   the four Tier-1 exchange tables as opus stages them
#                     (HH, HL, CA, LT) -- opus's own current field names, no
#                     `.id`, nothing derived. dr_con_raw().
#   .../datras/       what obus itself builds from those: HH, HL and CA
#                     (each the raw table + `.id`, nothing else), species,
#                     HL_length, HL_summary, and the flag/lookup tables.
#                     dr_con().
#
# HH, HL and CA therefore exist under BOTH names, and dr_con_raw("HL") and
# dr_con("HL") return the same rows and the same columns bar one: dr_con()'s
# carries `.id`. That is the only difference, and it is the point -- `.id`
# costs a dr_add_id() call and an eight-field concatenation over 14.4M rows
# every time a consumer wants to join HL to HH, so it is computed once at
# build time and published. Reach for dr_con_raw() when you specifically want
# what opus staged, untouched; otherwise prefer dr_con().
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
DR_TABLES     <- c("HH", "HL", "CA", "species", "HL_length", "HL_summary",
                   "hl_flag", "hl_flag_code",
                   "length_weight", "length_type_conversion")

#' Connect to a raw DATRAS exchange table
#'
#' Opens a lazy DuckDB connection to one of the four Tier-1 exchange tables in
#' the raw opus archive. These carry opus's current field names exactly as
#' staged, with no obus-side additions -- in particular no \code{.id} (see
#' \code{\link{dr_add_id}}) and no \code{Valid_Aphia}/\code{SpeciesSex} rename.
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
#' @details
#' \strong{Two layers, and which one to reach for.} \code{HH}, \code{HL} and
#' \code{CA} are the \emph{record} layer: the exchange tables exactly as opus
#' staged them, plus \code{.id}. Nothing is aggregated and nothing is dropped.
#' \code{HL_length} and \code{HL_summary} are the \emph{analysis} layer,
#' derived from HL. They are not redundant with it, and the difference matters.
#'
#' The analysis layer is \strong{faithful}. Verified archive-wide
#' (2026-09-03), \code{HL_length}'s \code{n_haul} reproduces the DATRAS R
#' package's own \code{Count} across all species and surveys -- 13,214,965
#' haul x species x length cells, 0 disagreeing by half a fish or more, max gap
#' 2.9e-11, and no cell present in one and missing from the other. The single
#' divergence is 23,856 cells (0.18 percent) where \code{SubsamplingFactor} was
#' never submitted: DATRAS assumes 1, obus returns \code{NA}. See
#' \code{\link{dr_add_n_and_cpue}}.
#'
#' The analysis layer is \strong{not lossless}. 13,957,390 of 14,001,605
#' \code{HL_length} rows (99.68 percent) come from exactly one raw HL row, but
#' 44,215 aggregate several -- and there \code{SubsamplingFactor} (42,089 rows)
#' and \code{SpeciesCategory} (43,989 rows) are collapsed away. Absent at this
#' grain too: \code{SubsampledNumber}, \code{SubsampleWeight},
#' \code{SpeciesCodeType}, per-category \code{SpeciesCategoryWeight}
#' (\code{w_haul} is summed to the species), and sex-specific weight, which is
#' not recoverable in general -- a property of the source data, not of the
#' split. See \code{\link{dr_HL_summary}}.
#'
#' So: length spectra, numbers and biomass per haul, CPUE, stratified indices,
#' species composition -- the analysis layer is a complete substitute for raw
#' HL, demonstrated by running the DATRAS/DATRASextra downstream stack on it
#' unmodified (\code{data-raw/CHECK_datras_adapter.R}). Subsampling QC,
#' anything keyed on \code{SpeciesCategory}, per-category weights, provenance,
#' or rebuilding an exchange file -- use the record layer.
#'
#' @param type One of:
#'   \describe{
#'     \item{\code{"HH"}, \code{"HL"}, \code{"CA"}}{The raw exchange table
#'       with \code{.id} added and \strong{nothing else changed} -- same rows,
#'       same columns, opus's field names, sentinels untouched. Identical to
#'       \code{\link{dr_con_raw}}'s version but for that one column, so a join
#'       between any two of them needs no \code{dr_add_id()} call and no
#'       eight-field concatenation over 14.4M HL rows.
#'       \code{.id} is not a guarantee of a matching haul, though. Every HL row
#'       matches an HH haul (verified: 0 orphans), but \strong{305,976 CA rows
#'       do not}, which is 5.13% of the table: they have both
#'       \code{StationName} and
#'       \code{HaulNumber} missing, so their \code{.id} ends \code{":NA:NA"}
#'       and identifies no haul. That is a property of the submissions, not of
#'       \code{.id}; an \code{inner_join} to HH silently drops them, so check
#'       with \code{\link[dplyr]{anti_join}} first if it matters. See
#'       \code{\link{dr_add_id}}.}
#'     \item{\code{"species"}}{WoRMS lookup: \code{Valid_Aphia}, \code{latin},
#'       \code{species} (English common name), \code{rank}, the higher
#'       classification, and WoRMS \code{status}/\code{worms_aphia}.}
#'     \item{\code{"HL_length"}}{One row per \code{.id} x \code{Valid_Aphia} x
#'       \code{length_mm} x \code{SpeciesSex}; see \code{\link{dr_HL_length}}.}
#'     \item{\code{"HL_summary"}}{One row per \code{.id} x \code{Valid_Aphia};
#'       see \code{\link{dr_HL_summary}}.}
#'     \item{\code{"hl_flag"}}{One row per \code{.id} x \code{Valid_Aphia} x
#'       \code{code}, for records carrying a flag. Long, so a record with
#'       several flags has several rows. Joins onto \code{"HL_summary"}
#'       directly, and onto \code{"HL_length"} as a property of the haul x
#'       species group.}
#'     \item{\code{"hl_flag_code"}}{The flag lookup: \code{code},
#'       \code{kind}, \code{affects}, \code{label}, \code{meaning},
#'       \code{evidence}. \code{kind} is the one to filter on --
#'       \code{"intrinsic"} and \code{"property"} records are not defects.}
#'     \item{\code{"length_weight"}}{Length-weight coefficients, one row per
#'       \code{Valid_Aphia}: \code{a}, \code{b}, the \code{lw_source}
#'       provenance label, the \code{ca_fit} metadata (\code{n_ca},
#'       \code{r2}, \code{sigma}) and \code{length_bearing}. Kept out of
#'       \code{"species"} despite the shared grain: it is obus's own modelled
#'       inference rather than WoRMS fact, and it rebuilds against different
#'       (FishBase/SeaLifeBase) remotes. See
#'       \code{\link{dr_add_predicted_weight}}.}
#'     \item{\code{"length_type_conversion"}}{Non-Total-Length landmark to
#'       Total Length, for the few species DATRAS measures otherwise:
#'       \code{Valid_Aphia}, \code{from_type}, \code{intercept},
#'       \code{slope}, \code{source}. See \code{\link{dr_add_length_tl}}.}
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
