# Shared prep: haulval filter + the HH columns every HL standardisation branch
# needs (DataType/HaulDuration for raising, Survey/Year/Quarter for grain).
# Used by both dr_HL_length() and dr_HL_summary() so the two stay in lockstep
# on which hauls are in scope.
.dr_hh_cols_for_hl <- function(hh, haulval) {
  if (!is.null(haulval)) hh <- dplyr::filter(hh, HaulValidity %in% haulval)
  dplyr::select(hh, .id, Survey, Year, Quarter, DataType, HaulDuration)
}


#' Length-frequency catch table from HH and HL
#'
#' One row per \code{.id} \eqn{\times} \code{aphia} \eqn{\times}
#' \code{length_mm} \eqn{\times} \code{sex} \eqn{\times} \code{LengthType}
#' -- only for species that were actually run through calipers (records with
#' \code{LengthClass} present). A
#' haul's bulk-counted or bulk-weighed species have no row here at all, not a
#' zero-length placeholder, since "count at length" is not a meaningful
#' description of a record that was never length-measured. See
#' \code{\link{dr_HL_summary}} for the full per-haul species roster, including
#' those species.
#'
#' \code{sex} is carried as its own column rather than collapsed to a
#' \code{p_females} ratio. That is safe here and not in
#' \code{\link{dr_HL_summary}}: \code{NumberAtLength} is a genuine
#' per-sex-per-length count, and -- verified full-archive -- unlike
#' \code{TotalNumber} it never repeats a placeholder value across sex sub-rows.
#' The raw code is kept as reported (\code{"F"}, \code{"M"}, \code{"U"},
#' \code{"B"}, or \code{NA}): \code{"B"} (berried, egg-bearing) is not
#' pre-merged into \code{"F"}, and \code{"U"} (assessed, undetermined) stays
#' distinct from \code{NA} (never assessed). A caller wanting the old ratio can
#' derive it after grouping \code{sex} away, e.g.
#' \code{summarise(p_females = sum(n_haul[sex \%in\% c("F","B")]) /
#' sum(n_haul[sex \%in\% c("F","M","B")]))}.
#'
#' \code{LengthType} is part of the grain, not just a carried attribute: one
#' haul can measure the same species, length and sex under two different
#' measurement conventions, and each is its own real count that must not be
#' collapsed. Measured over the whole archive (2026-08-31), 4,074 of
#' 13,992,024 groups (0.03\%) split this way -- 885 on \code{LengthType}, 15
#' on \code{SpeciesValidity}, 14 on \code{accuracy} (i.e. on
#' \code{LengthCode}), the rest on more than one at once. Grouping
#' \code{.id} \eqn{\times} \code{aphia} \eqn{\times} \code{length_mm}
#' \eqn{\times} \code{sex} alone and expecting one row will therefore fail
#' on a small number of hauls; sum \code{n_haul} rather than assuming
#' uniqueness.
#'
#' @param hh DATRAS HH table with \code{.id} present (see
#'   \code{\link{dr_add_id}}). Required: \code{.id}, \code{Survey},
#'   \code{Year}, \code{Quarter}, \code{DataType}, \code{HaulDuration}.
#'   Optional: \code{HaulValidity}, used when \code{haulval} is set.
#' @param hl DATRAS HL table with \code{.id} present. Required: \code{.id},
#'   \code{aphia}, \code{NumberAtLength}, \code{LengthClass},
#'   \code{LengthCode}, \code{LengthType}, \code{SubsamplingFactor},
#'   \code{sex}, \code{SpeciesValidity}.
#' @param species Species lookup with \code{aphia}, \code{latin},
#'   \code{species}, \code{rank}. Defaults to \code{dr_con("species")}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   \code{NULL} keeps all hauls.
#'
#' @return A lazy table, one row per \code{.id} \eqn{\times} \code{aphia}
#'   \eqn{\times} \code{length_mm} \eqn{\times} \code{sex} \eqn{\times}
#'   \code{LengthType} (see Details): \code{.id},
#'   \code{Survey}, \code{Year}, \code{Quarter}, \code{aphia}, \code{latin},
#'   \code{species}, \code{rank}, \code{length_mm}, \code{length_cm},
#'   \code{accuracy}, \code{LengthType}, \code{sex}, \code{n_haul},
#'   \code{n_hour}, \code{SpeciesValidity}.
#'
#' @seealso \code{\link{dr_HL_summary}}, \code{\link{dr_add_id}}
#' @export
dr_HL_length <- function(hh, hl, species = NULL, haulval = NULL) {
  hh_cols <- .dr_hh_cols_for_hl(hh, haulval)

  hl |>
    dplyr::filter(NumberAtLength != 0) |>
    dplyr::select(-dplyr::any_of(c("Survey", "Year", "Quarter"))) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::filter(!is.na(LengthClass)) |>
    dr_add_length_mm() |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    dr_join_species(species) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, latin, species, rank,
                    length_mm, length_cm, accuracy, LengthType, sex,
                    SpeciesValidity) |>
    dplyr::summarise(
      n_haul = sum(n_haul, na.rm = TRUE),
      n_hour = sum(n_hour, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species, rank,
      length_mm, length_cm, accuracy, LengthType, sex,
      n_haul, n_hour, SpeciesValidity
    )
}


#' Haul x species catch summary from HH and HL
#'
#' One row per \code{.id} \eqn{\times} \code{aphia} -- every species recorded
#' in \code{hl} for that haul, whether or not it was individually measured
#' (unlike \code{\link{dr_HL_length}}, which covers only the length-measured
#' subset). \code{n_haul}/\code{n_hour} come from the recorded
#' \code{TotalNumber}, present regardless of length data and so the one
#' universal per-species haul total, rather than being reconstructed by summing
#' \code{\link{dr_HL_length}}'s length classes; \code{w_haul}/\code{w_hour}
#' come from \code{SpeciesCategoryWeight}.
#'
#' \code{n_measured} is the raw, un-raised count of individuals actually run
#' through calipers (\eqn{\Sigma}\code{NumberAtLength} before any
#' \code{DataType}/\code{SubsamplingFactor} raising), and \code{0} for a
#' species with no length data at all. It is a genuinely different quantity
#' from \code{n_haul}: for a subsampled catch the two diverge on purpose --
#' \code{n_haul} is the raised whole-haul estimate, \code{n_measured} is how
#' many fish that estimate was built from. It is \code{NA}, not \code{0}, when
#' \code{DataType == "C"}: that convention reports \code{NumberAtLength} as an
#' already-hourly rate, so no true physical count can be recovered, and
#' \code{0} is reserved for species genuinely never measured.
#'
#' \code{n_haul} here and the length-class sum from \code{\link{dr_HL_length}}
#' describe the same underlying count \emph{when the source submission is
#' internally consistent} -- a cross-check worth running, not a guarantee.
#' Measured archive-wide on the retired implementation of this table
#' (1,920,932 groups), 3.5\% still disagreed meaningfully, concentrated in
#' particular surveys rather than spread evenly. Most of the rest is either
#' intrinsic to \code{DataType == "C"} (an independently reported catch rate
#' need not match a raised length-frequency sum exactly) or rounding noise from
#' a non-integer \code{SubsamplingFactor}.
#'
#' Unlike \code{\link{dr_HL_length}}, this table does \emph{not} carry
#' \code{sex} as a grain dimension. That asymmetry is deliberate and
#' empirically grounded. Verified full-archive across 212,497 haul x species
#' groups reporting more than one sex, \code{TotalNumber} genuinely varies by
#' sex for 66\% of them and is a species-level placeholder repeated identically
#' across every sex sub-row for the other 34\% -- and per-sex arithmetic
#' reconciliation can tell those apart.
#' \code{SpeciesCategoryWeight} has no analogous check, and its
#' repeats-vs-varies pattern tracks \code{TotalNumber}'s only about half the
#' time. Splitting this table by \code{sex} would therefore silently
#' misrepresent \code{w_haul}/\code{w_hour} for an unknown share of species
#' with no per-row way to flag which. Sex-specific \emph{counts} stay
#' recoverable by aggregating \code{\link{dr_HL_length}}; sex-specific
#' \emph{weight} is not recoverable in general -- a property of the source
#' data, not a gap in obus.
#'
#' \strong{The grain is \code{.id} \eqn{\times} \code{aphia} \eqn{\times}
#' \code{SpeciesValidity}, not \code{.id} \eqn{\times} \code{aphia}} -- and
#' where those differ, the row is very likely a duplicated total rather than a
#' genuine split. Measured over the whole archive (2026-08-31), 1,219 of
#' 2,290,227 haul \eqn{\times} species groups (0.05\%) report the same
#' species under more than one \code{SpeciesValidity} code, and of the 2,716
#' \code{SpeciesCategory}/\code{sex} sub-groups that span more than one code,
#' 2,642 (97\%) repeat an \emph{identical} \code{TotalNumber} across them.
#' The typical shape is a full set of length rows under one code plus a single
#' extra length-free row under another, carrying the same
#' \code{TotalNumber}/\code{SpeciesCategoryWeight} again. This is the same
#' repeated-placeholder pattern already handled for \code{sex} and
#' \code{SpeciesCategory}, recurring one dimension further over; it is
#' \emph{not} yet collapsed here. Summing \code{n_haul} or \code{w_haul} per
#' \code{.id} \eqn{\times} \code{aphia} without first collapsing on
#' \code{SpeciesValidity} will double-count those groups.
#'
#' @inheritParams dr_HL_length
#' @param hl DATRAS HL table with \code{.id} present. Required: \code{.id},
#'   \code{aphia}, \code{sex}, \code{SpeciesCategory}, \code{SpeciesValidity},
#'   \code{TotalNumber}, \code{SpeciesCategoryWeight}, \code{NumberAtLength},
#'   \code{LengthClass} (the last two only for \code{n_measured}).
#'
#' @return A lazy table, one row per \code{.id} \eqn{\times} \code{aphia}
#'   \eqn{\times} \code{SpeciesValidity} (see Details):
#'   \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}, \code{aphia},
#'   \code{latin}, \code{species}, \code{rank}, \code{n_haul}, \code{n_hour},
#'   \code{w_haul}, \code{w_hour}, \code{n_measured}, \code{p_females},
#'   \code{SpeciesValidity}.
#'
#' @seealso \code{\link{dr_HL_length}}, \code{\link{dr_add_id}}
#' @export
dr_HL_summary <- function(hh, hl, species = NULL, haulval = NULL) {
  hh_cols <- .dr_hh_cols_for_hl(hh, haulval)

  # ---- counts: TotalNumber, disambiguated per sex, not just distinct()-collapsed --
  # TotalNumber is a per-.id x aphia x SpeciesCategory total that DATRAS
  # sometimes repeats identically across every sex sub-row for that category
  # (a placeholder, needing collapse) and sometimes reports as a genuine,
  # distinct per-sex split (needing separate summing). A plain distinct() on
  # the value alone gets the common cases right but has its own blind spot:
  # when two DIFFERENT sexes coincidentally report the SAME number (not a
  # duplicate, just two small counts that happen to match), distinct() cannot
  # tell that apart from a real placeholder and wrongly collapses them.
  # Confirmed on real data: a BITS haul with F (own total 2), M (own total 1)
  # and unsexed (own total 1, coincidentally equal to M's) -- true total 4,
  # distinct()-on-value-alone gave 3.
  #
  # Fix: test each sex's OWN recorded TotalNumber against its OWN
  # length-derived expectation. A sex whose own value reconciles is trusted
  # and summed individually, regardless of what any other sex shows. Sexes
  # that do not reconcile (or have no length data to check against, e.g.
  # bulk-only categories) fall back to the distinct()-collapse -- but only
  # among values not already claimed by a reconciling sex, so a
  # one-sex-subtotal-style value is not double-counted once as "trusted" and
  # again via the fallback.
  #
  # The same duplication risk recurs one dimension over, in SpeciesCategory (a
  # size-based subsampling stratum). Some surveys report TWO categories
  # sharing one identical, non-reconciling TotalNumber -- entirely
  # NS-IBTS/SCOROC/SCOWCGFS in practice, always the category pair "11"+"12",
  # 1,430 haul x species groups archive-wide. That value is the species-level
  # total for BOTH strata together, not each stratum's own, so keeping
  # SpeciesCategory in the fallback's distinct() key summed it once per
  # category and inflated the total by close to 2x. The fallback therefore
  # excludes SpeciesCategory from its collapse key too -- not the trusted
  # branch, which still credits any category whose own data genuinely
  # reconciles.
  hh_dt <- dplyr::select(hh_cols, .id, DataType, HaulDuration)

  tn_by_sex <- hl |>
    dplyr::distinct(.id, aphia, SpeciesCategory, SpeciesValidity, sex, TotalNumber) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::mutate(
      n_haul_raw = dplyr::case_when(
        DataType == "C" ~ TotalNumber * HaulDuration / 60,
        TRUE            ~ TotalNumber
      ),
      n_hour_raw = dplyr::case_when(
        DataType == "C" ~ TotalNumber,
        TRUE            ~ TotalNumber / HaulDuration * 60
      )
    )

  len_expected_by_sex <- hl |>
    dplyr::filter(NumberAtLength != 0, !is.na(LengthClass)) |>
    dplyr::inner_join(hh_dt, by = ".id") |>
    dplyr::mutate(
      raised = dplyr::case_when(
        DataType == "C" ~ NumberAtLength * SubsamplingFactor * HaulDuration / 60,
        TRUE            ~ NumberAtLength * dplyr::coalesce(SubsamplingFactor, 1)
      )
    ) |>
    dplyr::group_by(.id, aphia, SpeciesCategory, SpeciesValidity, sex) |>
    dplyr::summarise(sex_expected = sum(raised, na.rm = TRUE), .groups = "drop")

  reconciled <- tn_by_sex |>
    dplyr::left_join(len_expected_by_sex,
                     by = c(".id", "aphia", "SpeciesCategory", "SpeciesValidity", "sex")) |>
    dplyr::mutate(reconciles = !is.na(sex_expected) & abs(n_haul_raw - sex_expected) <= 0.5)

  trusted <- reconciled |> dplyr::filter(reconciles)

  already_claimed <- trusted |>
    dplyr::distinct(.id, aphia, SpeciesValidity, TotalNumber)

  fallback <- reconciled |>
    dplyr::filter(!reconciles) |>
    dplyr::distinct(.id, Survey, Year, Quarter, aphia, SpeciesValidity,
                    TotalNumber, n_haul_raw, n_hour_raw) |>
    dplyr::anti_join(already_claimed,
                     by = c(".id", "aphia", "SpeciesValidity", "TotalNumber"))

  hl_counts <- dplyr::union_all(
      dplyr::select(trusted, .id, Survey, Year, Quarter, aphia, SpeciesValidity,
                    n_haul_raw, n_hour_raw),
      dplyr::select(fallback, .id, Survey, Year, Quarter, aphia, SpeciesValidity,
                    n_haul_raw, n_hour_raw)
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, SpeciesValidity) |>
    dplyr::summarise(
      n_haul = sum(n_haul_raw, na.rm = TRUE),
      n_hour = sum(n_hour_raw, na.rm = TRUE),
      .groups = "drop"
    )

  # ---- weights: SpeciesCategoryWeight -----------------------------------
  # Deduplicated the same way as counts above, and for the same reason:
  # SpeciesCategoryWeight is a single per-.id x aphia x SpeciesCategory total
  # DATRAS repeats identically on every sex-split row for that category.
  # Summing it together with sex silently multiplies the weight by however
  # many sex groups a haul happens to report -- confirmed on real data: an
  # NS-IBTS haul with 3 sex groups for one category had w_haul inflated
  # exactly 3x. distinct() on SpeciesCategory + weight (no sex) handles both
  # real cases: a repeated identical weight collapses to one row; genuinely
  # distinct per-sex weights (some programmes do weigh sexes separately) are
  # kept and summed.
  hl_weights <- hl |>
    dplyr::distinct(.id, aphia, SpeciesCategory, SpeciesValidity, SpeciesCategoryWeight) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::mutate(
      w_haul_raw = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight * HaulDuration / 60,
        TRUE            ~ SpeciesCategoryWeight
      ),
      w_hour_raw = dplyr::case_when(
        DataType == "C" ~ SpeciesCategoryWeight,
        TRUE            ~ SpeciesCategoryWeight / HaulDuration * 60
      )
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, aphia, SpeciesValidity) |>
    dplyr::summarise(
      w_haul = sum(w_haul_raw, na.rm = TRUE),
      w_hour = sum(w_hour_raw, na.rm = TRUE),
      .groups = "drop"
    )

  # ---- shared base for p_females and n_measured -------------------------
  # Both are sourced from NumberAtLength, not TotalNumber. Shared to avoid
  # computing the same filter+join twice.
  hl_len_base <- hl |>
    dplyr::filter(NumberAtLength != 0, !is.na(LengthClass)) |>
    dplyr::inner_join(hh_cols, by = ".id")

  # ---- p_females: from NumberAtLength, not TotalNumber ------------------
  # TotalNumber's reliability as a per-sex value is exactly the ambiguity
  # handled above -- computing p_females from it would need the same
  # disambiguation every call. NumberAtLength has no such ambiguity (the same
  # property that makes it safe as a dr_HL_length() grain dimension), so
  # p_females is the proportion of individually-measured, sexed fish that are
  # female. "B" (berried) is a known-female state, counted as female. NA when
  # no fish in the group were sexed.
  hl_pfem <- hl_len_base |>
    dr_add_n_and_cpue() |>
    dplyr::group_by(.id, aphia) |>
    dplyr::summarise(
      n_f = sum(dplyr::if_else(sex %in% c("F", "B"), n_haul, 0), na.rm = TRUE),
      n_m = sum(dplyr::if_else(sex == "M", n_haul, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      p_females = dplyr::if_else(n_f + n_m > 0, n_f / (n_f + n_m), NA_real_)
    ) |>
    dplyr::select(.id, aphia, p_females)

  # ---- n_measured: raw, un-raised count actually run through calipers ----
  # DataType == "C" reports NumberAtLength as an already-hourly RATE, not a
  # per-haul count -- summing it raw gives a rate-scale number (confirmed:
  # exactly 2x n_haul for a 30-minute "C" haul), not "how many fish were
  # measured". No true physical count is recoverable from a rate-only
  # submission, so n_measured is NA for "C" rather than misleadingly scaled.
  # .has_length distinguishes "no match at all" (bulk-only species -- 0
  # measured, a known fact) from "matched but NA" (DataType == "C" --
  # unknown, not a known zero); a bare coalesce(n_measured, 0) cannot tell
  # those apart, since both look like NA after the left join.
  hl_measured <- hl_len_base |>
    dplyr::group_by(.id, aphia) |>
    dplyr::summarise(
      n_measured = dplyr::if_else(
        dplyr::first(DataType) == "C",
        NA_real_,
        sum(NumberAtLength, na.rm = TRUE)
      ),
      .groups = "drop"
    ) |>
    dplyr::mutate(.has_length = TRUE)

  hl_counts |>
    dplyr::left_join(hl_weights,
                     by = c(".id", "Survey", "Year", "Quarter", "aphia", "SpeciesValidity")) |>
    dplyr::left_join(hl_pfem, by = c(".id", "aphia")) |>
    dplyr::left_join(hl_measured, by = c(".id", "aphia")) |>
    dplyr::mutate(n_measured = dplyr::if_else(is.na(.has_length), 0, n_measured)) |>
    dplyr::select(-.has_length) |>
    dr_join_species(species) |>
    dplyr::select(
      .id, Survey, Year, Quarter, aphia, latin, species, rank,
      n_haul, n_hour, w_haul, w_hour, n_measured, p_females, SpeciesValidity
    )
}
