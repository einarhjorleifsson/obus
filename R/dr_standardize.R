#' Standardize HL table with derived columns and type flag
#'
#' Creates a standardized HL parquet foundation with two row types:
#' - type="length": length-frequency records with computed n_haul/n_hour
#' - type="haul": haul-level summaries (TotalNumber, weight) deduplicated by haul × species
#'
#' @param hh DATRAS HH table with columns: .id, Survey, Year, Quarter, DataType, HaulDuration
#' @param hl DATRAS HL table with columns: .id, aphia, LengthCode, LengthClass,
#'   NumberAtLength, SubsamplingFactor, TotalNumber, SpeciesCategoryWeight,
#'   SpeciesSex, SpeciesCategory, SpeciesValidity
#' @param species Species lookup table (aphia, latin, species). Defaults to dr_con("species")
#' @param haulval Character vector of HaulValidity codes to retain. NULL keeps all.
#'
#' @return A lazy DuckDB table with two row types:
#'   - type="length": one row per haul × species × length_mm
#'   - type="haul": one row per haul × species
#'   Both have columns: .id, Survey, Year, Quarter, aphia, latin, species, type,
#'   length_mm, length_cm, accuracy (length type only), n_haul, n_hour,
#'   w_haul, w_hour (haul type only), SpeciesValidity, StandardSpeciesCode, BycatchSpeciesCode
#'
#' @export
dr_standardize_hl <- function(hh, hl, species = NULL, haulval = NULL) {
  if (is.null(species)) species <- dr_con("species")
  if (!is.null(haulval)) hh <- dplyr::filter(hh, HaulValidity %in% haulval)

  # ---- Type="length": length-frequency records ----
  hl_length <- hl |>
    dplyr::filter(NumberAtLength != 0) |>
    dplyr::select(-dplyr::any_of(c("Survey", "Year", "Quarter"))) |>
    dplyr::inner_join(
      dplyr::select(hh, .id, Survey, Year, Quarter, DataType, HaulDuration,
                    StandardSpeciesCode, BycatchSpeciesCode),
      by = ".id"
    ) |>
    dplyr::filter(!is.na(LengthClass)) |>
    dr_add_length_mm() |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    dr_add_species(species) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species,
      length_mm, length_cm, accuracy,
      n_haul, n_hour, SpeciesValidity,
      StandardSpeciesCode, BycatchSpeciesCode
    ) |>
    dplyr::mutate(type = "length")

  # ---- Type="haul": haul-level bookkeeping (deduplicated) ----
  # Deduplicate TotalNumber and weight by haul × species, summing over sex/category
  hl_haul <- hl |>
    dplyr::select(-dplyr::any_of(c("Survey", "Year", "Quarter"))) |>
    dplyr::inner_join(
      dplyr::select(hh, .id, Survey, Year, Quarter, DataType, HaulDuration,
                    StandardSpeciesCode, BycatchSpeciesCode),
      by = ".id"
    ) |>
    dplyr::distinct(.id, aphia, TotalNumber, SpeciesCategoryWeight, DataType, HaulDuration, .keep_all = TRUE) |>
    dr_add_species(species) |>
    dplyr::mutate(
      n_haul_raw = dplyr::case_when(
        DataType == "C"  ~ TotalNumber * HaulDuration / 60,
        DataType == "R"  ~ TotalNumber,
        DataType == "P"  ~ TotalNumber,
        DataType == "S"  ~ TotalNumber,
        TRUE ~ NA_real_
      ),
      w_haul_raw = SpeciesCategoryWeight
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, latin, species) |>
    dplyr::summarise(
      n_haul = sum(n_haul_raw, na.rm = TRUE),
      n_hour = sum(n_haul_raw / HaulDuration * 60, na.rm = TRUE),
      w_haul = sum(w_haul_raw, na.rm = TRUE),
      w_hour = sum(w_haul_raw / HaulDuration * 60, na.rm = TRUE),
      SpeciesValidity = dplyr::first(SpeciesValidity),
      StandardSpeciesCode = dplyr::first(StandardSpeciesCode),
      BycatchSpeciesCode = dplyr::first(BycatchSpeciesCode),
      .groups = "drop"
    ) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species,
      n_haul, n_hour, w_haul, w_hour, SpeciesValidity,
      StandardSpeciesCode, BycatchSpeciesCode
    ) |>
    dplyr::mutate(type = "haul")

  # ---- Bind and align columns ----
  hl_length |>
    dplyr::select(.id, Survey, Year, Quarter, aphia, latin, species, type,
                 length_mm, length_cm, accuracy,
                 n_haul, n_hour, SpeciesValidity,
                 StandardSpeciesCode, BycatchSpeciesCode) |>
    dplyr::mutate(w_haul = NA_real_, w_hour = NA_real_) |>
    dplyr::union_all(
      hl_haul |>
        dplyr::select(.id, Survey, Year, Quarter, aphia, latin, species, type,
                     n_haul, n_hour, w_haul, w_hour, SpeciesValidity,
                     StandardSpeciesCode, BycatchSpeciesCode) |>
        dplyr::mutate(length_mm = NA_integer_, length_cm = NA_real_,
                     accuracy = NA_real_)
    )
}
