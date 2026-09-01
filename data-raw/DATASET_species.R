# Build species.parquet from scratch.
#
#   distinct Valid_Aphia in the raw archive  ->  WoRMS  ->  to_https/species.parquet
#
# One row per Valid_Aphia code that actually occurs in the archive (HL or CA), with
# the accepted Latin name, an English common name where WoRMS has one, the
# taxonomic rank and higher classification, and WoRMS' own validity status.
#
# Run before DATASET_products.R -- both catch tables join to this.
#
# Output: data-raw/to_https/species.parquet (publish by hand).

source("data-raw/build_helpers.R")

dr_cache_raw(c("HL", "CA"))

# ---- the codes to look up ---------------------------------------------------
# Valid_Aphia is opus's current name for the field; obus calls it `Valid_Aphia` from
# here on, and that is the join key both catch tables use.
Valid_Aphia <- dplyr::union(
  dr_con_raw("HL", path = DR_RAW) |> dplyr::distinct(Valid_Aphia),
  dr_con_raw("CA", path = DR_RAW) |> dplyr::distinct(Valid_Aphia)
) |>
  dplyr::filter(!is.na(Valid_Aphia)) |>
  dplyr::arrange(Valid_Aphia) |>
  dplyr::pull(Valid_Aphia) |>
  as.integer()

message(sprintf("%d distinct Valid_Aphia codes in the archive", length(Valid_Aphia)))

# ---- accepted Latin name ----------------------------------------------------
# Deliberately NOT wrapped in suppressWarnings(), unlike the common-name call
# below: a "(204) No Content" here means the Valid_Aphia does not resolve in WoRMS at
# all, which is rare and worth seeing.
message("wm_id2name_() ...")
latin <- worrms::wm_id2name_(id = Valid_Aphia)

# ---- English common name ----------------------------------------------------
# suppressWarnings: wm_common_id_() warns "(204) No Content" once per Valid_Aphia
# with no vernacular registered -- true for most taxa, not a sign of a bad id.
message("wm_common_id_() ...")
common <- suppressWarnings(worrms::wm_common_id_(id = Valid_Aphia))

sp <- data.frame(Valid_Aphia = as.integer(names(latin)),
                 latin = unlist(latin, use.names = FALSE),
                 stringsAsFactors = FALSE) |>
  dplyr::left_join(
    common |>
      dplyr::filter(language == "English") |>
      dplyr::group_by(Valid_Aphia = as.integer(id)) |>
      dplyr::slice(1) |>
      dplyr::ungroup() |>
      dplyr::select(Valid_Aphia, species = vernacular),
    by = "Valid_Aphia"
  )

# ---- rank, higher classification, validity ----------------------------------
# `rank` is what lets a caller collapse either catch table to genus, family,
# order and so on with a plain group_by(), regardless of what an individual
# Valid_Aphia's own native rank happens to be.
#
# The same response carries WoRMS' `status` ("accepted", "unaccepted",
# "superseded combination", ...) and, for an outdated code, the
# `valid_AphiaID`/`valid_name` it now forwards to. DATRAS assigns a Valid_Aphia once
# at submission and WoRMS taxonomy keeps moving, so a small fraction drift out
# of "accepted" over time. These columns are kept rather than acted on: the
# DATRAS-native `Valid_Aphia` stays the join key and is never silently remapped.
# Coarse deliberate codes (Pisces, Teuthida) and taxa inquirenda are flagged
# non-accepted but forward to themselves, and must not be "corrected".
#
# A subtler risk than staleness, which no refresh of this table can fix: a
# stable, still-accepted Valid_Aphia's species concept can itself be redefined by a
# later taxonomic split, with nothing in worms_status/worms_aphia to flag it. Aphia
# 105869 ("Dipturus batis") reads as continuously accepted straight through the
# 2009/2010 common-skate split and the 2016 revision that put the name back on
# the blue skate. Hauls tagged 105869 before ~2009 may be either post-split
# species pooled together -- a property of the historical data, not of how
# current this lookup is.
#
# WoRMS' AphiaRecordsByAphiaIDs endpoint caps at 50 ids per request
# (empirically: 50 works, 120 gives 400 Bad Request), so this chunks the sweep.
chunk_size <- 50L
chunks <- split(Valid_Aphia, ceiling(seq_along(Valid_Aphia) / chunk_size))
message(sprintf("wm_record() over %d chunks of %d ...", length(chunks), chunk_size))

# One transient 500 from WoRMS anywhere in ~40 sequential requests would
# otherwise discard the whole sweep several minutes in -- observed on
# 2026-09-01, where the failing id resolved perfectly on its own a moment
# later. Retry each chunk a few times with backoff before giving up.
.wm_record_retry <- function(ids, tries = 4L) {
  for (k in seq_len(tries)) {
    rec <- tryCatch(worrms::wm_record(id = ids), error = function(e) e)
    if (!inherits(rec, "error")) return(rec)
    if (k == tries) {
      stop("wm_record() failed ", tries, " times for ids ",
           paste(range(ids), collapse = "-"), ": ", conditionMessage(rec),
           call. = FALSE)
    }
    message(sprintf("    WoRMS failed (%s), retry %d/%d in %ds ...",
                    conditionMessage(rec), k, tries - 1L, 2L * k))
    Sys.sleep(2L * k)
  }
}

taxonomy <- lapply(chunks, function(ids) {
  Sys.sleep(0.5)  # considerate pacing across ~40 sequential requests
  rec <- .wm_record_retry(ids)
  if (nrow(rec) != length(ids)) {
    stop("wm_record() returned ", nrow(rec), " rows for ", length(ids),
         " requested ids -- the order-alignment assumption below is broken.",
         call. = FALSE)
  }
  # Trust input order, not the response's own AphiaID column: an id that fails
  # to resolve does not error the batch, it comes back as a row of NAs in its
  # own input position.
  rec$Valid_Aphia <- ids
  rec
}) |>
  dplyr::bind_rows() |>
  dplyr::select(Valid_Aphia, rank, kingdom, phylum, class, order, family, genus,
                worms_status = status, worms_aphia = valid_AphiaID,
                worms_name = valid_name)

n_unresolved <- sum(is.na(taxonomy$rank))
if (n_unresolved > 0) {
  message(sprintf("  %d of %d Valid_Aphia did not resolve to a WoRMS record (rank = NA)",
                  n_unresolved, nrow(taxonomy)))
}
message(sprintf("  %d of %d Valid_Aphia are not WoRMS-'accepted'; %d forward to a different worms_aphia",
                sum(taxonomy$worms_status != "accepted", na.rm = TRUE), nrow(taxonomy),
                sum(!is.na(taxonomy$worms_aphia) & taxonomy$worms_aphia != taxonomy$Valid_Aphia)))

species <- sp |>
  dplyr::left_join(taxonomy, by = "Valid_Aphia") |>
  dplyr::mutate(Valid_Aphia = as.integer(Valid_Aphia),
                worms_aphia = as.integer(worms_aphia)) |>
  dplyr::arrange(Valid_Aphia)

stopifnot(!anyDuplicated(species$Valid_Aphia), all(Valid_Aphia %in% species$Valid_Aphia))

# ---- write ------------------------------------------------------------------
dr_write(dplyr::copy_to(duckdbfs::cached_connection(), species,
                        "_obus_species_out", overwrite = TRUE),
         "species")

message("\nPublish with:")
message("  scp data-raw/to_https/species.parquet einarhj@heima.hafro.is:~/public_html/datras/species.parquet")
