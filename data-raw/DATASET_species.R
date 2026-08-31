# Build species.parquet from scratch.
#
#   distinct aphia in the raw archive  ->  WoRMS  ->  to_https/species.parquet
#
# One row per aphia code that actually occurs in the archive (HL or CA), with
# the accepted Latin name, an English common name where WoRMS has one, the
# taxonomic rank and higher classification, and WoRMS' own validity status.
#
# Run before DATASET_products.R -- both catch tables join to this.
#
# Output: data-raw/to_https/species.parquet (publish by hand).

source("data-raw/build_helpers.R")

dr_cache_raw(c("HL", "CA"))

# ---- the codes to look up ---------------------------------------------------
# Valid_Aphia is opus's current name for the field; obus calls it `aphia` from
# here on, and that is the join key both catch tables use.
aphia <- dplyr::union(
  dr_con_raw("HL", path = DR_RAW) |> dplyr::distinct(aphia = Valid_Aphia),
  dr_con_raw("CA", path = DR_RAW) |> dplyr::distinct(aphia = Valid_Aphia)
) |>
  dplyr::filter(!is.na(aphia)) |>
  dplyr::arrange(aphia) |>
  dplyr::pull(aphia) |>
  as.integer()

message(sprintf("%d distinct aphia codes in the archive", length(aphia)))

# ---- accepted Latin name ----------------------------------------------------
# Deliberately NOT wrapped in suppressWarnings(), unlike the common-name call
# below: a "(204) No Content" here means the aphia does not resolve in WoRMS at
# all, which is rare and worth seeing.
message("wm_id2name_() ...")
latin <- worrms::wm_id2name_(id = aphia)

# ---- English common name ----------------------------------------------------
# suppressWarnings: wm_common_id_() warns "(204) No Content" once per aphia
# with no vernacular registered -- true for most taxa, not a sign of a bad id.
message("wm_common_id_() ...")
common <- suppressWarnings(worrms::wm_common_id_(id = aphia))

sp <- data.frame(aphia = as.integer(names(latin)),
                 latin = unlist(latin, use.names = FALSE),
                 stringsAsFactors = FALSE) |>
  dplyr::left_join(
    common |>
      dplyr::filter(language == "English") |>
      dplyr::group_by(aphia = as.integer(id)) |>
      dplyr::slice(1) |>
      dplyr::ungroup() |>
      dplyr::select(aphia, species = vernacular),
    by = "aphia"
  )

# ---- rank, higher classification, validity ----------------------------------
# `rank` is what lets a caller collapse either catch table to genus, family,
# order and so on with a plain group_by(), regardless of what an individual
# aphia's own native rank happens to be.
#
# The same response carries WoRMS' `status` ("accepted", "unaccepted",
# "superseded combination", ...) and, for an outdated code, the
# `valid_AphiaID`/`valid_name` it now forwards to. DATRAS assigns an aphia once
# at submission and WoRMS taxonomy keeps moving, so a small fraction drift out
# of "accepted" over time. These columns are kept rather than acted on: the
# DATRAS-native `aphia` stays the join key and is never silently remapped.
# Coarse deliberate codes (Pisces, Teuthida) and taxa inquirenda are flagged
# non-accepted but forward to themselves, and must not be "corrected".
#
# A subtler risk than staleness, which no refresh of this table can fix: a
# stable, still-accepted aphia's species concept can itself be redefined by a
# later taxonomic split, with nothing in status/valid_aphia to flag it. Aphia
# 105869 ("Dipturus batis") reads as continuously accepted straight through the
# 2009/2010 common-skate split and the 2016 revision that put the name back on
# the blue skate. Hauls tagged 105869 before ~2009 may be either post-split
# species pooled together -- a property of the historical data, not of how
# current this lookup is.
#
# WoRMS' AphiaRecordsByAphiaIDs endpoint caps at 50 ids per request
# (empirically: 50 works, 120 gives 400 Bad Request), so this chunks the sweep.
chunk_size <- 50L
chunks <- split(aphia, ceiling(seq_along(aphia) / chunk_size))
message(sprintf("wm_record() over %d chunks of %d ...", length(chunks), chunk_size))

taxonomy <- lapply(chunks, function(ids) {
  Sys.sleep(0.5)  # considerate pacing across ~40 sequential requests
  rec <- worrms::wm_record(id = ids)
  if (nrow(rec) != length(ids)) {
    stop("wm_record() returned ", nrow(rec), " rows for ", length(ids),
         " requested ids -- the order-alignment assumption below is broken.",
         call. = FALSE)
  }
  # Trust input order, not the response's own AphiaID column: an id that fails
  # to resolve does not error the batch, it comes back as a row of NAs in its
  # own input position.
  rec$aphia <- ids
  rec
}) |>
  dplyr::bind_rows() |>
  dplyr::select(aphia, rank, kingdom, phylum, class, order, family, genus,
                status, valid_aphia = valid_AphiaID, valid_name)

n_unresolved <- sum(is.na(taxonomy$rank))
if (n_unresolved > 0) {
  message(sprintf("  %d of %d aphia did not resolve to a WoRMS record (rank = NA)",
                  n_unresolved, nrow(taxonomy)))
}
message(sprintf("  %d of %d aphia are not WoRMS-'accepted'; %d forward to a different valid_aphia",
                sum(taxonomy$status != "accepted", na.rm = TRUE), nrow(taxonomy),
                sum(!is.na(taxonomy$valid_aphia) & taxonomy$valid_aphia != taxonomy$aphia)))

species <- sp |>
  dplyr::left_join(taxonomy, by = "aphia") |>
  dplyr::mutate(aphia = as.integer(aphia),
                valid_aphia = as.integer(valid_aphia)) |>
  dplyr::arrange(aphia)

stopifnot(!anyDuplicated(species$aphia), all(aphia %in% species$aphia))

# ---- write ------------------------------------------------------------------
dr_write(dplyr::copy_to(duckdbfs::cached_connection(), species,
                        "_obus_species_out", overwrite = TRUE),
         "species")

message("\nPublish with:")
message("  scp data-raw/to_https/species.parquet einarhj@heima.hafro.is:~/public_html/datras/species.parquet")
