#' Haul-level catch totals (numbers and weights) from HH and HL exchange data
#'
#' Computes total catch in numbers and weight per haul per species from raw
#' DATRAS HH and HL tables. Counts are derived from \code{TotalNumber} and
#' weights from \code{SpeciesCategoryWeight}; both are haul-level summary
#' fields in HL that are repeated across every length row within a
#' species/sex/category group. The function deduplicates at the group level
#' before applying DataType-aware scaling and aggregating across
#' \code{SpeciesSex} and \code{SpeciesCategory}.
#'
#' This function operates independently of \code{\link{dr_cpue_by_length}} and
#' is the appropriate choice when you need haul-level totals (including weights)
#' rather than length-disaggregated CPUE. Unlike \code{dr_cpue_by_length},
#' which derives counts from \code{NumberAtLength}, this function uses
#' \code{TotalNumber} directly — the two approaches should give the same counts
#' but may differ slightly due to rounding in submitted data.
#'
#' @param hh DATRAS haul header table (HH) with new-style column names (as
#'   returned by \code{\link{dr_get}} with \code{from = "parquet"} or
#'   \code{from = "new"}, or by \code{\link{dr_con}}).
#'   Required: \code{Survey}, \code{Year}, \code{Quarter}, \code{Country},
#'   \code{Platform}, \code{Gear}, \code{StationName}, \code{HaulNumber},
#'   \code{HaulValidity}, \code{DataType}, \code{HaulDuration}.
#' @param hl DATRAS length table (HL) with new-style column names.
#'   Required: \code{Survey}, \code{Year}, \code{Quarter}, \code{Country},
#'   \code{Platform}, \code{Gear}, \code{StationName}, \code{HaulNumber},
#'   \code{SpeciesValidity}, \code{ValidAphiaID}, \code{TotalNumber},
#'   \code{SpeciesCategoryWeight}, \code{SpeciesSex}, \code{SpeciesCategory}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   Default \code{"V"} (valid hauls only).
#' @param specval Integer or character vector of \code{SpeciesValidity} codes
#'   to retain. Default \code{1L} (standard species records only).
#' @param zerofill Logical. When \code{TRUE}, adds explicit zero rows for every
#'   haul × species combination where the species was observed somewhere in the
#'   same \code{Survey} / \code{Year} / \code{Quarter} but was absent from that
#'   haul (\code{n_haul = n_hour = w_haul = w_hour = 0}). Default \code{FALSE}.
#' @param diag Logical. When \code{TRUE}, skips the aggregation over
#'   \code{SpeciesSex} and \code{SpeciesCategory} and returns the
#'   deduplicated, scaled table at the species/sex/category level. Retains
#'   \code{DataType}, \code{HaulDuration}, \code{TotalNumber}, and
#'   \code{SpeciesCategoryWeight} alongside the derived columns.
#'   Useful for QC (e.g. spotting inconsistent \code{TotalNumber} values or
#'   unexpected sex/category structure). Default \code{FALSE}.
#'
#' @return When \code{diag = FALSE} and \code{zerofill = FALSE} (defaults),
#'   a tibble with one row per \code{.id} × \code{ValidAphiaID}:
#'   \describe{
#'     \item{\code{.id}}{8-field haul key:
#'       \code{Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber}.}
#'     \item{\code{.id2}}{6-field key matching the ICES CPUEL join key
#'       (lacks \code{Country} and \code{StationName}):
#'       \code{Survey:Year:Quarter:Platform:Gear:HaulNumber}.}
#'     \item{\code{Survey}, \code{Year}, \code{Quarter}}{Survey metadata.}
#'     \item{\code{ValidAphiaID}}{Valid WoRMS AphiaID.}
#'     \item{\code{n_haul}}{Total estimated numbers caught per haul.}
#'     \item{\code{n_hour}}{Total estimated numbers per hour of hauling.}
#'     \item{\code{w_haul}}{Total catch weight per haul (grams).}
#'     \item{\code{w_hour}}{Total catch weight per hour of hauling (grams).}
#'   }
#'   \code{w_haul} and \code{w_hour} are \code{NA} when
#'   \code{SpeciesCategoryWeight} was not recorded for all sex/category groups
#'   of a species. Zero-fill rows have all four columns set to \code{0}.
#'
#' @seealso \code{\link{dr_cpue_by_length}} for length-disaggregated CPUE
#'   derived from \code{NumberAtLength}.
#'
#' @export
dr_cpue_by_haul <- function(hh, hl,
                            haulval  = "V",
                            specval  = 1L,
                            zerofill = FALSE,
                            diag     = FALSE) {

  # --- validate required columns ---------------------------------------------
  hh_required <- c("Survey", "Year", "Quarter", "Country", "Platform", "Gear",
                    "StationName", "HaulNumber", "HaulValidity", "DataType",
                    "HaulDuration")
  hh_missing  <- setdiff(hh_required, colnames(hh))
  if (length(hh_missing) > 0)
    stop("hh is missing required columns: ", paste(hh_missing, collapse = ", "))

  hl_required <- c("Survey", "Year", "Quarter", "Country", "Platform", "Gear",
                    "StationName", "HaulNumber", "SpeciesValidity", "ValidAphiaID",
                    "TotalNumber", "SpeciesCategoryWeight", "SpeciesSex",
                    "SpeciesCategory")
  hl_missing  <- setdiff(hl_required, colnames(hl))
  if (length(hl_missing) > 0)
    stop("hl is missing required columns: ", paste(hl_missing, collapse = ", "))

  # --- HH: filter to valid hauls, build identifiers -------------------------
  hh_filt <- hh |>
    dplyr::filter(HaulValidity %in% haulval) |>
    dr_add_id() |>
    dplyr::mutate(
      .id2 = paste(Survey, Year, Quarter, Platform, Gear, HaulNumber, sep = ":")
    ) |>
    dplyr::select(.id, .id2, Survey, Year, Quarter, DataType, HaulDuration)

  # --- HL: filter, build identifiers, join HH metadata ---------------------
  hl_joined <- hl |>
    dplyr::filter(SpeciesValidity %in% as.character(specval)) |>
    dr_add_id() |>
    dplyr::mutate(
      .id2 = paste(Survey, Year, Quarter, Platform, Gear, HaulNumber, sep = ":")
    ) |>
    dplyr::inner_join(hh_filt, by = c(".id", ".id2", "Survey", "Year", "Quarter"))

  # --- deduplicate to one row per haul × species × sex × SpeciesCategory ----
  # TotalNumber and SpeciesCategoryWeight are haul-level summary fields
  # repeated across every length row in a group. Distinct collapses them
  # without summing.
  hl_dedup <- hl_joined |>
    dplyr::distinct(.id, .id2, Survey, Year, Quarter, ValidAphiaID,
                    SpeciesSex, SpeciesCategory, DataType, HaulDuration,
                    TotalNumber, SpeciesCategoryWeight)

  # --- DataType-aware scaling -----------------------------------------------
  # R/S/P: TotalNumber and SpeciesCategoryWeight are already per-haul totals.
  # C:     TotalNumber and SpeciesCategoryWeight are raised to 1 hour; back-convert.
  hl_scaled <- hl_dedup |>
    dplyr::mutate(
      n_haul = dplyr::case_when(
        DataType == "C" ~ TotalNumber              * HaulDuration / 60,
        TRUE            ~ TotalNumber
      ),
      n_hour = dplyr::case_when(
        DataType == "C" ~ TotalNumber,
        TRUE            ~ TotalNumber              / HaulDuration * 60
      ),
      w_haul = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight    * HaulDuration / 60,
        TRUE            ~ SpeciesCategoryWeight
      ),
      w_hour = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight,
        TRUE            ~ SpeciesCategoryWeight    / HaulDuration * 60
      )
    )

  # --- diagnostic: return pre-aggregation table -----------------------------
  if (diag) {
    return(
      dplyr::select(hl_scaled,
                    .id, .id2, Survey, Year, Quarter, ValidAphiaID,
                    SpeciesSex, SpeciesCategory, DataType, HaulDuration,
                    TotalNumber, SpeciesCategoryWeight,
                    n_haul, n_hour, w_haul, w_hour)
    )
  }

  # --- aggregate across SpeciesSex and SpeciesCategory ----------------------
  result <- hl_scaled |>
    dplyr::group_by(.id, .id2, Survey, Year, Quarter, ValidAphiaID) |>
    dplyr::summarise(
      n_haul = sum(n_haul, na.rm = TRUE),
      n_hour = sum(n_hour, na.rm = TRUE),
      w_haul = sum(w_haul, na.rm = TRUE),
      w_hour = sum(w_hour, na.rm = TRUE),
      .groups = "drop"
    )

  if (!zerofill) return(result)

  # --- zero-fill -------------------------------------------------------------
  result <- dplyr::collect(result)

  species_per_sqy <- result |>
    dplyr::distinct(Survey, Year, Quarter, ValidAphiaID)

  all_hauls <- hh |>
    dplyr::filter(HaulValidity %in% haulval) |>
    dr_add_id() |>
    dplyr::mutate(
      .id2 = paste(Survey, Year, Quarter, Platform, Gear, HaulNumber, sep = ":")
    ) |>
    dplyr::select(.id, .id2, Survey, Year, Quarter) |>
    dplyr::collect()

  caught <- result |>
    dplyr::distinct(.id, ValidAphiaID)

  zeros <- all_hauls |>
    dplyr::inner_join(species_per_sqy, by = c("Survey", "Year", "Quarter")) |>
    dplyr::anti_join(caught, by = c(".id", "ValidAphiaID")) |>
    dplyr::mutate(n_haul = 0, n_hour = 0, w_haul = 0, w_hour = 0)

  dplyr::bind_rows(result, zeros) |>
    dplyr::arrange(.id, ValidAphiaID)
}


#' Calculate CPUE per length class from HH and HL exchange data
#'
#' Computes catch per unit effort (numbers per hour of hauling) at each length
#' class per haul per species from raw DATRAS HH and HL tables, replicating
#' the ICES DATRAS CPUE-per-length product from first principles.
#'
#' Filters to valid hauls (\code{HaulValidity == "V"}) and standard species
#' records (\code{SpeciesValidity == 1}) by default, then applies
#' \code{\link{dr_add_n_and_cpue}} and \code{\link{dr_add_length_mm}}. Counts
#' are aggregated across \code{SpeciesSex} and \code{SpeciesCategory} so each
#' output row represents a unique haul × species × length combination.
#'
#' @param hh DATRAS haul header table (HH) with new-style column names (as
#'   returned by \code{\link{dr_get}} with \code{from = "parquet"} or
#'   \code{from = "new"}, or by \code{\link{dr_con}}).
#'   Required columns: \code{Survey}, \code{Year}, \code{Quarter},
#'   \code{Country}, \code{Platform}, \code{Gear}, \code{StationName},
#'   \code{HaulNumber}, \code{HaulValidity}, \code{DataType},
#'   \code{HaulDuration}.
#' @param hl DATRAS length table (HL) with new-style column names. Required
#'   columns: \code{Survey}, \code{Year}, \code{Quarter}, \code{Country},
#'   \code{Platform}, \code{Gear}, \code{StationName}, \code{HaulNumber},
#'   \code{SpeciesValidity}, \code{LengthCode}, \code{LengthClass},
#'   \code{NumberAtLength}, \code{SubsamplingFactor}, \code{ValidAphiaID}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   Default \code{"V"} (valid hauls only).
#' @param specval Integer or character vector of \code{SpeciesValidity} codes
#'   to retain. Default \code{1L} (standard species records only).
#' @param zerofill Logical. When \code{TRUE}, adds explicit zero rows for every
#'   haul × species combination where the species was observed somewhere in
#'   the same \code{Survey} / \code{Year} / \code{Quarter} but was absent from
#'   that haul. Zero rows carry \code{length_mm = NA} and \code{n_hour = 0}.
#'   Replicates the ICES CPUEL zero-fill convention. Ignored when
#'   \code{diag = TRUE}. Default \code{FALSE}.
#' @param diag Logical. When \code{TRUE}, skips the final aggregation and
#'   returns the per-row pre-aggregation table, retaining \code{SpeciesSex},
#'   \code{SpeciesCategory}, \code{NumberAtLength}, \code{SubsamplingFactor},
#'   \code{DataType}, \code{HaulDuration}, \code{n_haul}, and \code{n_hour}.
#'   Useful for inspecting duplicate rows or the SpeciesSex / SpeciesCategory
#'   structure that drives the aggregation. Default \code{FALSE}.
#'
#' @return When \code{diag = FALSE} (default), a tibble with one row per
#'   \code{.id} × \code{ValidAphiaID} × \code{length_mm} combination (plus
#'   one zero row per absent haul × species when \code{zerofill = TRUE}):
#'   \describe{
#'     \item{\code{.id}}{8-field unique haul identifier from
#'       \code{\link{dr_add_id}}:
#'       \code{Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber}.}
#'     \item{\code{.id2}}{6-field identifier matching the ICES CPUEL product
#'       join key (lacks \code{Country} and \code{StationName}):
#'       \code{Survey:Year:Quarter:Platform:Gear:HaulNumber}.}
#'     \item{\code{Survey}, \code{Year}, \code{Quarter}}{Survey metadata.}
#'     \item{\code{ValidAphiaID}}{Valid WoRMS AphiaID.}
#'     \item{\code{length_mm}}{Length class in millimetres (converted from
#'       \code{LengthClass} via \code{LengthCode}). \code{NA} for zero-fill rows.}
#'     \item{\code{n_hour}}{CPUE: estimated numbers per hour of hauling,
#'       summed across \code{SpeciesSex} and \code{SpeciesCategory}.
#'       \code{0} for zero-fill rows.}
#'   }
#'   When \code{diag = TRUE}, returns the pre-aggregation table with additional
#'   columns \code{SpeciesSex}, \code{SpeciesCategory}, \code{NumberAtLength},
#'   \code{SubsamplingFactor}, \code{DataType}, \code{HaulDuration},
#'   \code{n_haul}.
#'
#' @seealso \code{\link{dr_cpue_by_haul}} for the haul-aggregated version.
#'   \code{\link{dr_add_n_and_cpue}}, \code{\link{dr_add_length_mm}},
#'   \code{\link{dr_add_id}}
#'
#' @export
dr_cpue_by_length <- function(hh, hl,
                    haulval  = "V",
                    specval  = 1L,
                    zerofill = FALSE,
                    diag     = FALSE) {

  # --- validate required columns ---------------------------------------------
  hh_required <- c("Survey", "Year", "Quarter", "Country", "Platform", "Gear",
                    "StationName", "HaulNumber", "HaulValidity", "DataType",
                    "HaulDuration")
  hh_missing  <- setdiff(hh_required, colnames(hh))
  if (length(hh_missing) > 0)
    stop("hh is missing required columns: ", paste(hh_missing, collapse = ", "))

  hl_required <- c("Survey", "Year", "Quarter", "Country", "Platform", "Gear",
                    "StationName", "HaulNumber", "SpeciesValidity", "LengthCode",
                    "LengthClass", "NumberAtLength", "SubsamplingFactor",
                    "ValidAphiaID")
  hl_missing  <- setdiff(hl_required, colnames(hl))
  if (length(hl_missing) > 0)
    stop("hl is missing required columns: ", paste(hl_missing, collapse = ", "))

  # --- HH: filter to valid hauls, build identifiers, select metadata ---------
  hh_filt <- hh |>
    dplyr::filter(HaulValidity %in% haulval) |>
    dr_add_id() |>
    dplyr::mutate(
      .id2 = paste(Survey, Year, Quarter, Platform, Gear, HaulNumber, sep = ":")
    ) |>
    dplyr::select(.id, .id2, Survey, Year, Quarter, DataType, HaulDuration)

  # --- HL: filter to requested SpeciesValidity codes, build identifiers ------
  hl_filt <- hl |>
    dplyr::filter(SpeciesValidity %in% as.character(specval)) |>
    dr_add_id() |>
    dplyr::mutate(
      .id2 = paste(Survey, Year, Quarter, Platform, Gear, HaulNumber, sep = ":")
    )

  # --- join HH metadata to HL; restrict to valid hauls ----------------------
  hl_joined <- hl_filt |>
    dplyr::inner_join(hh_filt, by = c(".id", ".id2", "Survey", "Year", "Quarter"))

  # --- length in mm ----------------------------------------------------------
  hl_joined <- hl_joined |>
    dr_add_length_mm() |>
    dplyr::filter(!is.na(length_mm))   # drop records without a valid length class

  # --- n_haul and n_hour -----------------------------------------------------
  hl_joined <- hl_joined |>
    dr_add_n_and_cpue()

  # --- diagnostic: return pre-aggregation table ------------------------------
  if (diag) {
    diag_cols <- c(".id", ".id2", "Survey", "Year", "Quarter",
                   "ValidAphiaID", "length_mm",
                   "SpeciesSex", "SpeciesCategory",
                   "NumberAtLength", "SubsamplingFactor", "DataType",
                   "HaulDuration", "n_haul", "n_hour")
    # tolerate trimmed inputs that lack SpeciesSex / SpeciesCategory
    return(dplyr::select(hl_joined, dplyr::any_of(diag_cols)))
  }

  # --- aggregate across SpeciesSex and SpeciesCategory ----------------------
  cpue_nonzero <- hl_joined |>
    dplyr::group_by(.id, .id2, Survey, Year, Quarter, ValidAphiaID, length_mm) |>
    dplyr::summarise(n_hour = sum(n_hour, na.rm = TRUE), .groups = "drop")

  if (!zerofill) return(cpue_nonzero)

  # --- zero-fill -------------------------------------------------------------
  # Collect the aggregated CPUE so we can use in-memory joins.
  # (bind_rows / anti_join across DuckDB lazy and in-memory frames requires
  #  one side to be a data frame; collecting cpue_nonzero is the natural place.)
  cpue_nonzero <- dplyr::collect(cpue_nonzero)

  # Species observed (in at least one haul) per Survey / Year / Quarter
  species_per_sqy <- cpue_nonzero |>
    dplyr::distinct(Survey, Year, Quarter, ValidAphiaID)

  # Every valid haul x every species seen in its Survey / Year / Quarter
  haul_x_species <- hh_filt |>
    dplyr::select(.id, .id2, Survey, Year, Quarter) |>
    dplyr::collect() |>
    dplyr::inner_join(species_per_sqy, by = c("Survey", "Year", "Quarter"))

  # Hauls where each species WAS caught (has at least one length row)
  caught <- cpue_nonzero |>
    dplyr::distinct(.id, ValidAphiaID)

  # Zero rows: in the grid but absent from the catch
  zeros <- haul_x_species |>
    dplyr::anti_join(caught, by = c(".id", "ValidAphiaID")) |>
    dplyr::mutate(length_mm = NA_real_, n_hour = 0)

  dplyr::bind_rows(cpue_nonzero, zeros) |>
    dplyr::arrange(.id, ValidAphiaID, length_mm)
}

