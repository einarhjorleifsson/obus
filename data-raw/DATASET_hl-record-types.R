#' Lookup table for HL record types
#'
#' A tibble describing the integer codes assigned by \code{\link{dr_add_record_type}}.
#' Each row defines one record type with a short label and a description of
#' the variable pattern that defines it.
#'
#' @format A tibble with columns:
#' \describe{
#'   \item{record_type}{Integer code.}
#'   \item{lc_present}{Logical; whether \code{LengthClass} is present for this type.}
#'   \item{label}{Short human-readable label.}
#'   \item{description}{Full description of the variable pattern.}
#' }
#' @export
dr_lookup_hl_record_type <- tibble::tribble(
  ~record_type, ~lc_present, ~label,                              ~description,
  # --- Records WITH LengthClass ---
  1L,  TRUE,  "Length-frequency, standard",
  "LengthClass and n_haul present; no SpeciesSex or DevelopmentStage annotation",
  2L,  TRUE,  "Length-frequency, sex-disaggregated",
  "LengthClass and n_haul present, SpeciesSex present, no DevelopmentStage",
  3L,  TRUE,  "Length-frequency, with development stage",
  "LengthClass and n_haul present, DevelopmentStage present; ~99% also carry SpeciesSex. Seen mainly in cephalopod/maturity protocols (e.g. Sepia officinalis in BTS)",
  4L,  TRUE,  "Length-frequency, invalid haul",
  "LengthClass present but n_haul is NA: DataType = -9 or NA in the haul header (HH table)",
  # --- Records WITHOUT LengthClass ---
  10L, FALSE, "Explicit zero catch",
  "All measurement vars absent (TotalNumber, SpeciesCategoryWeight, SubsamplingFactor, SpeciesSex all NA). SpeciesValidity = 5 ('not found') in ~94% of cases. These are standard-species-list absences recorded for hauls where the species was looked for but not caught; distinct from implicit zeros (hauls that simply omit the species). Concentrated in BTS and NS-IBTS.",
  11L, FALSE, "Bulk bycatch weight",
  "LengthClass absent; SpeciesCategoryWeight present, TotalNumber absent; no type-3 record for the same .id + ValidAphiaID. Represents organisms weighed as bulk material without individual counting or length measurement: sponges, hydroids, algae, tunicates, etc. Primarily BTS.",
  12L, FALSE, "Counted catch, no subsampling",
  "LengthClass absent; TotalNumber present, SubsamplingFactor absent. Species was counted (and possibly weighed) but no length measurements were taken and no subsampling structure was recorded.",
  13L, FALSE, "Subsampled catch summary, no sex",
  "LengthClass absent; SubsamplingFactor present, SpeciesSex absent. In ~99.8% of cases standalone: species was counted with a subsampling factor but not individually measured. In the rare remaining cases (~0.2%) acts as a companion header row that duplicates the totals from co-occurring type-1 length-frequency records for the same .id + ValidAphiaID + SpeciesCategory.",
  14L, FALSE, "Subsampled catch summary, sex-disaggregated",
  "LengthClass absent; SubsamplingFactor and SpeciesSex present. Analogous to type 13 but with sex annotation. Standalone in ~99.4% of cases; in ~0.6% acts as a companion header to co-occurring type-2 length-frequency records.",
  15L, FALSE, "Sex-coded null record",
  "LengthClass absent; SpeciesSex present but TotalNumber, SpeciesCategoryWeight, and SubsamplingFactor all absent. Functionally equivalent to type 10 (explicit zero) with a sex code attached. Only ~100 records in the full dataset.",
  16L, FALSE, "Companion weight to length-frequency record",
  "LengthClass absent; SpeciesCategoryWeight present, TotalNumber absent; a length-frequency record (type 1, 2, or 3) exists for the same .id + ValidAphiaID. The weight duplicates the SpeciesCategoryWeight already carried by the co-occurring length records and should be excluded to avoid double-counting. Seen for Sepia officinalis (BTS, alongside type-3 development-stage records) and Mnemiopsis leidyi (DYFS, alongside type-2 sex-disaggregated records).",
  99L, FALSE, "Other / unclassified",
  "LengthClass absent; does not fit any of types 10-16"
)

usethis::use_data(dr_lookup_hl_record_type, overwrite = TRUE)
