# Shared setup for the data-raw build scripts.
#
# Nothing here is package code -- these scripts are run by hand, in order:
#
#   1. DATASET_species.R   -> to_https/species.parquet
#   2. DATASET_products.R  -> to_https/{HH,HL_length,HL_summary}.parquet
#
# and the results are published manually. Neither script uploads anything.

suppressMessages(library(dplyr))
devtools::load_all(".", quiet = TRUE)

# A local mirror of the opus raw archive. Named `raw` so opus::op_archive()
# accepts it as an archive root too -- the invariant is opus's, not obus's.
DR_RAW <- "data-raw/raw"
# Where this build's own parquets land, before anyone publishes them.
DR_OUT <- "data-raw/to_https"

DR_SERVER <- "https://heima.hafro.is/~einarhj/datras"

#' Mirror the raw archive locally.
#'
#' The whole raw archive is ~125 MB, and every build script scans all of it
#' more than once. Pulling it down first turns a long sequence of HTTP range
#' requests -- where DuckDB's filter pushdown is least reliable -- into local
#' file reads, which is both faster and less likely to fail halfway through a
#' 20-million-row aggregation.
dr_cache_raw <- function(tables = c("HH", "HL", "CA"), force = FALSE) {
  dir.create(DR_RAW, showWarnings = FALSE, recursive = TRUE)
  for (tb in tables) {
    dest <- file.path(DR_RAW, paste0(tb, ".parquet"))
    if (!force && file.exists(dest)) {
      message(sprintf("  %s.parquet cached (%.1f MB)", tb, file.size(dest) / 1e6))
      next
    }
    url <- paste0(DR_SERVER, "/raw/", tb, ".parquet")
    message(sprintf("  downloading %s ...", url))
    if (utils::download.file(url, dest, mode = "wb", quiet = TRUE) != 0) {
      stop("download failed: ", url, call. = FALSE)
    }
    message(sprintf("  %s.parquet (%.1f MB)", tb, file.size(dest) / 1e6))
  }
  invisible(DR_RAW)
}

#' Write one table to DR_OUT as zstd parquet.
#'
#' Written with duckdbfs -- the same engine dr_con() reads it back with, so any
#' type or encoding quirk is at least self-consistent. `x` may stay lazy: a
#' DuckDB COPY TO streams the result out without ever materialising it in R,
#' which matters for HL_length (tens of millions of rows).
dr_write <- function(x, name) {
  dir.create(DR_OUT, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(DR_OUT, paste0(name, ".parquet"))
  if (file.exists(out)) unlink(out)
  duckdbfs::write_dataset(x, out, options = "COMPRESSION 'zstd'")
  message(sprintf("  wrote %s (%.1f MB)", out, file.size(out) / 1e6))
  invisible(out)
}

#' Report a count without collecting the table.
dr_n <- function(x) dplyr::pull(dplyr::count(x), n)
