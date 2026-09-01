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
#' One row per \code{.id} \eqn{\times} \code{Valid_Aphia} \eqn{\times}
#' \code{length_mm} \eqn{\times} \code{SpeciesSex} \eqn{\times}
#' \code{DevelopmentStage} \eqn{\times} \code{LengthType} -- only for species
#' that were actually run through calipers (records with \code{LengthClass}
#' present). A
#' haul's bulk-counted or bulk-weighed species have no row here at all, not a
#' zero-length placeholder, since "count at length" is not a meaningful
#' description of a record that was never length-measured. See
#' \code{\link{dr_HL_summary}} for the full per-haul species roster, including
#' those species.
#'
#' \code{SpeciesSex} is carried as its own column rather than collapsed to a
#' \code{p_females} ratio. That is safe here and not in
#' \code{\link{dr_HL_summary}}: \code{NumberAtLength} is a genuine
#' per-sex-per-length count, and -- verified full-archive -- unlike
#' \code{TotalNumber} it never repeats a placeholder value across sex sub-rows.
#' The raw code is kept as reported (\code{"F"}, \code{"M"}, \code{"U"},
#' \code{"B"}, or \code{NA}): \code{"B"} (berried, egg-bearing) is not
#' pre-merged into \code{"F"}, and \code{"U"} (assessed, undetermined) stays
#' distinct from \code{NA} (never assessed). A caller wanting the old ratio can
#' derive it after grouping \code{SpeciesSex} away, e.g.
#' \code{summarise(p_females = sum(n_haul[SpeciesSex \%in\% c("F","B")]) /
#' sum(n_haul[SpeciesSex \%in\% c("F","M","B")]))}.
#'
#' \code{LengthType} and \code{DevelopmentStage} are part of the grain, not
#' carried attributes. ICES's own field descriptions define an HL record by the
#' combination \emph{haul, species, sex, devstage and subsampling category},
#' so one haul can measure the same species and length under two measurement
#' conventions, or as both egg-bearing and unstaged, and each is its own real
#' count that must not be summed away. Measured over the whole archive
#' (2026-08-31): 5,476 groups split on \code{DevelopmentStage}, 885 on
#' \code{LengthType}, 15 on \code{SpeciesValidity}, 14 on \code{accuracy}
#' (i.e. on \code{LengthCode}). At the full key the table is exactly unique
#' (verified: 0 duplicated groups over 14,001,605 rows); at any coarser key it
#' is not, so sum \code{n_haul} rather than assuming one row.
#'
#' @param hh DATRAS HH table with \code{.id} present (see
#'   \code{\link{dr_add_id}}). Required: \code{.id}, \code{Survey},
#'   \code{Year}, \code{Quarter}, \code{DataType}, \code{HaulDuration}.
#'   Optional: \code{HaulValidity}, used when \code{haulval} is set.
#' @param hl DATRAS HL table with \code{.id} present. Required: \code{.id},
#'   \code{Valid_Aphia}, \code{NumberAtLength}, \code{LengthClass},
#'   \code{LengthCode}, \code{LengthType}, \code{SubsamplingFactor},
#'   \code{SpeciesSex}, \code{SpeciesValidity}.
#' @param species Species lookup with \code{Valid_Aphia}, \code{latin},
#'   \code{species}, \code{rank}. Defaults to \code{dr_con("species")}.
#' @param haulval Character vector of \code{HaulValidity} codes to retain.
#'   \code{NULL} keeps all hauls.
#'
#' @return A lazy table, one row per \code{.id} \eqn{\times} \code{Valid_Aphia}
#'   \eqn{\times} \code{length_mm} \eqn{\times} \code{SpeciesSex} \eqn{\times}
#'   \code{DevelopmentStage} \eqn{\times} \code{LengthType} (see Details):
#'   \code{.id},
#'   \code{Survey}, \code{Year}, \code{Quarter}, \code{Valid_Aphia}, \code{latin},
#'   \code{species}, \code{rank}, \code{length_mm}, \code{length_cm},
#'   \code{accuracy}, \code{LengthType}, \code{SpeciesSex},
#'   \code{DevelopmentStage}, \code{n_haul}, \code{n_hour},
#'   \code{SpeciesValidity}.
#'
#' Where \code{HaulDuration} is 0 or negative (219 hauls archive-wide),
#' \code{n_hour} is \code{NA} rather than \code{Inf} -- an hourly rate is
#' undefined with no time fished. \code{DataType == "C"} is the exception: it
#' reports a rate directly, so there \code{n_hour} survives and \code{n_haul}
#' is \code{NA} instead.
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
    # Rename before summarising. Two reasons, both load-bearing: the guard
    # below must read n_haul's PRE-aggregation value, and `n_haul = sum(n_haul)`
    # in the same summarise() is resolved differently by the two backends --
    # dplyr evaluates expressions in order, so a later one sees the new scalar,
    # while SQL resolves every aggregate against the source column. Distinct
    # names make the two agree by construction rather than by luck.
    dplyr::mutate(.n_raw = n_haul, .h_raw = n_hour) |>
    dplyr::group_by(.id, Survey, Year, Quarter, Valid_Aphia, latin, species, rank,
                    length_mm, length_cm, accuracy, LengthType, SpeciesSex,
                    DevelopmentStage, SpeciesValidity) |>
    dplyr::summarise(
      n_haul = sum(.n_raw, na.rm = TRUE),
      n_hour = sum(.h_raw, na.rm = TRUE),
      # Same all-NA guard as dr_HL_summary(): sum(x, na.rm = TRUE) over a
      # group with nothing in it is 0 in R and NULL in SQL. Without this, a
      # group whose raising is genuinely unknown -- a missing
      # SubsamplingFactor, or a non-positive HaulDuration -- comes back as a
      # confident 0 on the eager path. Caught by a test, not by review.
      .n_ok = sum(as.integer(!is.na(.n_raw)), na.rm = TRUE),
      .h_ok = sum(as.integer(!is.na(.h_raw)), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      n_haul = dplyr::if_else(.n_ok == 0, NA_real_, n_haul),
      n_hour = dplyr::if_else(.h_ok == 0, NA_real_, n_hour)
    ) |>
    dplyr::select(
      .id, Survey, Year, Quarter, Valid_Aphia, latin, species, rank,
      length_mm, length_cm, accuracy, LengthType, SpeciesSex, DevelopmentStage,
      n_haul, n_hour, SpeciesValidity
    )
}


#' Haul x species catch summary from HH and HL
#'
#' One row per \code{.id} \eqn{\times} \code{Valid_Aphia} -- every species recorded
#' in \code{hl} for that haul, whether or not it was individually measured
#' (unlike \code{\link{dr_HL_length}}, which covers only the length-measured
#' subset). \code{n_totalnumber}/\code{n_totalnumber_hour} come from the
#' recorded \code{TotalNumber}, present regardless of length data and so the
#' one universal per-species haul total, rather than being reconstructed by
#' summing \code{\link{dr_HL_length}}'s length classes. The name says so on
#' purpose: \code{\link{dr_HL_length}}'s \code{n_haul} is the same conceptual
#' quantity arrived at the other way -- raising the measured length frequencies
#' -- and the two do not always agree (see below). Calling both \code{n_haul}
#' invited exactly that confusion. \code{w_haul}/\code{w_hour} keep their
#' names because \code{SpeciesCategoryWeight} is their only possible source;
#' there is no length-derived weight in obus to confuse them with.
#'
#' \code{n_measured} is the raw, un-raised count of individuals actually run
#' through calipers (\eqn{\Sigma}\code{NumberAtLength} before any
#' \code{DataType}/\code{SubsamplingFactor} raising), and \code{0} for a
#' species with no length data at all. It is a genuinely different quantity
#' from \code{n_totalnumber}: for a subsampled catch the two diverge on purpose
#' -- \code{n_totalnumber} is the reported whole-haul total, \code{n_measured}
#' is how many fish were actually put through calipers. It is \code{NA}, not \code{0}, when
#' \code{DataType == "C"}: that convention reports \code{NumberAtLength} as an
#' already-hourly rate, so no true physical count can be recovered, and
#' \code{0} is reserved for species genuinely never measured.
#'
#' \strong{Both routes are carried here.} \code{n_totalnumber} is the reported
#' total; \code{n_haul} is the same quantity reconstructed by raising the
#' length frequencies -- identical to summing \code{\link{dr_HL_length}}'s own
#' \code{n_haul} to this grain, and \code{NA} where the species has no length
#' data or its raising factor is unknown. Their difference is the disagreement
#' described below, available as a subtraction rather than a grouped join
#' (a naive \code{left_join()} to \code{\link{dr_HL_length}} fans out and
#' silently multiplies).
#'
#' \code{n_totalnumber} here and the length-class sum from
#' \code{\link{dr_HL_length}} describe the same underlying count \emph{when the source submission is
#' internally consistent} -- a cross-check worth running, not a guarantee.
#' Measured archive-wide on the retired implementation of this table
#' (1,920,932 groups), 3.5\% still disagreed meaningfully, concentrated in
#' particular surveys rather than spread evenly. Most of the rest is either
#' intrinsic to \code{DataType == "C"} (an independently reported catch rate
#' need not match a raised length-frequency sum exactly) or rounding noise from
#' a non-integer \code{SubsamplingFactor}.
#'
#' Unlike \code{\link{dr_HL_length}}, this table does \emph{not} carry
#' \code{SpeciesSex} as a grain dimension. That asymmetry is deliberate and
#' empirically grounded. Verified full-archive across 212,497 haul x species
#' groups reporting more than one sex, \code{TotalNumber} genuinely varies by
#' sex for 66\% of them and is a species-level placeholder repeated identically
#' across every sex sub-row for the other 34\% -- and per-sex arithmetic
#' reconciliation can tell those apart.
#' \code{SpeciesCategoryWeight} has no analogous check, and its
#' repeats-vs-varies pattern tracks \code{TotalNumber}'s only about half the
#' time. Splitting this table by \code{SpeciesSex} would therefore silently
#' misrepresent \code{w_haul}/\code{w_hour} for an unknown share of species
#' with no per-row way to flag which. Sex-specific \emph{counts} stay
#' recoverable by aggregating \code{\link{dr_HL_length}}; sex-specific
#' \emph{weight} is not recoverable in general -- a property of the source
#' data, not a gap in obus.
#'
#' \strong{The grain is \code{.id} \eqn{\times} \code{Valid_Aphia} \eqn{\times}
#' \code{SpeciesValidity}, and that is correct, not a defect.}
#' \code{SpeciesValidity} is a \emph{record type} field -- it says what kind of
#' data is present for a species in a haul, not whether the haul is valid -- and
#' the HL format deliberately allows more than one record type per species per
#' haul. ICES's own documentation is explicit that this is intentional, and
#' that "if you aggregate over \code{.id} x \code{Valid_Aphia} without also grouping
#' on \code{SpeciesValidity}, rows from different record types will be silently
#' mixed together." The typical case is a full length-frequency series
#' (\code{"1"}) alongside a supplementary presence marker (\code{"5"}) or a
#' count-only row (\code{"4"}) carrying the same \code{TotalNumber} again.
#'
#' Measured over the whole archive (2026-08-31): 1,219 of 2,290,203 groups
#' (0.05\%) carry more than one record type, the commonest pairs being
#' \code{\{1,5\}} and \code{\{4,7\}} -- matching ICES's own reported
#' pattern independently. Filtering to a single \code{SpeciesValidity} makes
#' \code{.id} \eqn{\times} \code{Valid_Aphia} exactly unique (verified: 0
#' duplicates at codes \code{"1"}, \code{"4"}, \code{"5"} and \code{"7"}).
#' For most surveys, filter to \code{SpeciesValidity == "1"} before
#' aggregating. Summing \code{n_haul} or \code{w_haul} per \code{.id}
#' \eqn{\times} \code{Valid_Aphia} without filtering mixes record types and
#' double-counts.
#'
#' Where \code{HaulDuration} is 0 or negative,
#' \code{n_totalnumber_hour}/\code{w_hour} are \code{NA} rather than
#' \code{Inf}; and for \code{DataType == "C"} -- which reports rates directly,
#' and is 200 of the 217 zero-duration hauls -- it is
#' \code{n_totalnumber}/\code{w_haul} that go \code{NA} instead of a
#' misleading \code{0}.
#'
#' \strong{Can-Mar is the documented exception}: it puts real
#' \code{LengthClass}/\code{NumberAtLength} data on \code{"5"} rows, so
#' filtering to \code{"1"} there discards genuine length data for a
#' substantial share of its groups. Treat Can-Mar separately.
#'
#' @inheritParams dr_HL_length
#' @param hl DATRAS HL table with \code{.id} present. Required: \code{.id},
#'   \code{Valid_Aphia}, \code{SpeciesSex}, \code{SpeciesCategory}, \code{SpeciesValidity},
#'   \code{TotalNumber}, \code{SpeciesCategoryWeight}, \code{NumberAtLength},
#'   \code{LengthClass} (the last two only for \code{n_measured}).
#'
#' @return A lazy table, one row per \code{.id} \eqn{\times} \code{Valid_Aphia}
#'   \eqn{\times} \code{SpeciesValidity} (see Details):
#'   \code{.id}, \code{Survey}, \code{Year}, \code{Quarter}, \code{Valid_Aphia},
#'   \code{latin}, \code{species}, \code{rank}, \code{n_totalnumber},
#'   \code{n_totalnumber_hour}, \code{n_haul}, \code{w_haul}, \code{w_hour},
#'   \code{n_measured}, \code{p_females}, \code{SpeciesValidity}.
#'
#' @seealso \code{\link{dr_HL_length}}, \code{\link{dr_add_id}}
#' @export
dr_HL_summary <- function(hh, hl, species = NULL, haulval = NULL) {
  hh_cols <- .dr_hh_cols_for_hl(hh, haulval)

  # ---- counts: TotalNumber, disambiguated per SpeciesSex, not just distinct()-collapsed --
  # TotalNumber is a per-.id x Valid_Aphia x SpeciesCategory total that DATRAS
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
  # length-derived expectation. A SpeciesSex whose own value reconciles is trusted
  # and summed individually, regardless of what any other sex shows. Sexes
  # that do not reconcile (or have no length data to check against, e.g.
  # bulk-only categories) fall back to the distinct()-collapse -- but only
  # among values not already claimed by a reconciling SpeciesSex, so a
  # one-SpeciesSex-subtotal-style value is not double-counted once as "trusted" and
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
  # DevelopmentStage belongs in this key because ICES's own field description
  # puts it there: TotalNumber is documented as the total "per category (unique
  # combination of cruise haul, species, sex, devstage and subsampling category
  # identifier)", and SpeciesCategoryWeight carries the identical wording.
  # obus_retired's own dev notes cite the same five-part key from
  # grammar_of_datras_data.qmd, but its code only ever used four parts -- so two
  # genuinely distinct per-devstage totals that happened to be equal were
  # collapsed by distinct() and undercounted. Measured archive-wide: 289 groups
  # span more than one DevelopmentStage, 21 of them with colliding TotalNumber,
  # worth +29 fish out of 1,443,326,029. Correct by the book and invisible in
  # practice -- fixed because it is free, and because DevelopmentStage may be
  # used more heavily in future submissions than the current 0.2% of rows.
  #
  # Weight is deliberately NOT keyed on devstage below, for the same reason it
  # is not keyed on sex: DATRAS demonstrably repeats one weight across those
  # sub-rows regardless of what its own spec says (verified 3x inflation on a
  # real NS-IBTS haul), so distinct() without them is the empirically-correct
  # reading.
  hh_dt <- dplyr::select(hh_cols, .id, DataType, HaulDuration)

  tn_by_sex <- hl |>
    dplyr::distinct(.id, Valid_Aphia, SpeciesCategory, SpeciesValidity, SpeciesSex,
                    DevelopmentStage, TotalNumber) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::mutate(
      # A HaulDuration of 0 (or negative) makes one of these two undefined, in
      # opposite directions depending on DataType, and the raw arithmetic hides
      # it either way: a derived hourly rate comes out Inf, and a "C" per-haul
      # count comes out 0. Both become NA. Archive-wide: 217 hauls at duration
      # 0 (200 of them "C"), plus 2 negative.
      n_haul_raw = dplyr::case_when(
        DataType == "C" & HaulDuration <= 0 ~ NA_real_,
        DataType == "C" ~ TotalNumber * HaulDuration / 60,
        TRUE            ~ TotalNumber
      ),
      n_hour_raw = dplyr::case_when(
        DataType == "C"   ~ TotalNumber,
        HaulDuration <= 0 ~ NA_real_,
        TRUE              ~ TotalNumber / HaulDuration * 60
      )
    )

  len_expected_by_sex <- hl |>
    dplyr::filter(NumberAtLength != 0, !is.na(LengthClass)) |>
    dplyr::inner_join(hh_dt, by = ".id") |>
    dplyr::mutate(
      raised = dplyr::case_when(
        DataType == "C" ~ NumberAtLength * SubsamplingFactor * HaulDuration / 60,
        TRUE            ~ NumberAtLength * SubsamplingFactor
      )
    ) |>
    dplyr::group_by(.id, Valid_Aphia, SpeciesCategory, SpeciesValidity, SpeciesSex,
                    DevelopmentStage) |>
    dplyr::summarise(sex_expected = sum(raised, na.rm = TRUE), .groups = "drop")

  # na_matches = "na" on every join below whose key can hold NA -- NOT optional,
  # and the single most consequential line in this function. SQL's `=` treats
  # NULL = NULL as unknown, so a lazy join silently fails to match any row with
  # an NA key, while dplyr's own eager join matches NA to NA. `SpeciesSex` is NA in
  # 54% of HL rows, and `SpeciesCategory`/`SpeciesValidity`/`TotalNumber` can
  # be NA too. Without this, every NA-SpeciesSex row fails to find its own
  # length-derived expectation, never reconciles, and falls to the
  # distinct()-collapse fallback -- which undercounts.
  #
  # Confirmed on the real case obus_retired documents for exactly this
  # scenario (BITS:1999:1:DK:26HI:TVS:017492:22, Valid_Aphia 127143): F's own total
  # 2, M's own 1, and an unsexed row's own 1 -- true total 4. Run lazily
  # without na_matches the unsexed row cannot reconcile and the answer comes
  # out 3. obus_retired never hit this because its build collected HH and HL
  # eagerly before calling this function; running it lazily, as obus now does,
  # makes the SQL semantics live. Its own dev notes flag the same NULL = NULL
  # trap, but only as a pitfall for validation scripts.
  #
  # dbplyr renders this as `IS NOT DISTINCT FROM`, which DuckDB supports
  # natively; verified to reproduce dplyr's eager result exactly.
  reconciled <- tn_by_sex |>
    dplyr::left_join(len_expected_by_sex,
                     by = c(".id", "Valid_Aphia", "SpeciesCategory", "SpeciesValidity",
                            "SpeciesSex", "DevelopmentStage"),
                     na_matches = "na") |>
    dplyr::mutate(reconciles = !is.na(sex_expected) & !is.na(n_haul_raw) &
                    abs(n_haul_raw - sex_expected) <= 0.5)

  trusted <- reconciled |> dplyr::filter(reconciles)

  already_claimed <- trusted |>
    dplyr::distinct(.id, Valid_Aphia, SpeciesValidity, TotalNumber)

  fallback <- reconciled |>
    dplyr::filter(!reconciles) |>
    dplyr::distinct(.id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity,
                    TotalNumber, n_haul_raw, n_hour_raw) |>
    dplyr::anti_join(already_claimed,
                     by = c(".id", "Valid_Aphia", "SpeciesValidity", "TotalNumber"),
                     na_matches = "na")

  hl_counts <- dplyr::union_all(
      dplyr::select(trusted, .id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity,
                    n_haul_raw, n_hour_raw),
      dplyr::select(fallback, .id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity,
                    n_haul_raw, n_hour_raw)
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity) |>
    dplyr::summarise(
      n_totalnumber      = sum(n_haul_raw, na.rm = TRUE),
      n_totalnumber_hour = sum(n_hour_raw, na.rm = TRUE),
      # How many inputs were actually present. Needed because sum(x, na.rm =
      # TRUE) over an all-NA group is 0 in R but NULL in SQL -- so without
      # this the two backends disagree, and the eager one silently converts
      # the deliberate zero-duration NA above straight back into the false
      # zero it was meant to prevent.
      .n_ok = sum(as.integer(!is.na(n_haul_raw)), na.rm = TRUE),
      .h_ok = sum(as.integer(!is.na(n_hour_raw)), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      n_totalnumber      = dplyr::if_else(.n_ok == 0, NA_real_, n_totalnumber),
      n_totalnumber_hour = dplyr::if_else(.h_ok == 0, NA_real_, n_totalnumber_hour)
    ) |>
    dplyr::select(-.n_ok, -.h_ok)

  # ---- weights: SpeciesCategoryWeight -----------------------------------
  # Deduplicated the same way as counts above, and for the same reason:
  # SpeciesCategoryWeight is a single per-.id x Valid_Aphia x SpeciesCategory total
  # DATRAS repeats identically on every sex-split row for that category.
  # Summing it together with SpeciesSex silently multiplies the weight by however
  # many sex groups a haul happens to report -- confirmed on real data: an
  # NS-IBTS haul with 3 sex groups for one category had w_haul inflated
  # exactly 3x. distinct() on SpeciesCategory + weight (no sex) handles both
  # real cases: a repeated identical weight collapses to one row; genuinely
  # distinct per-sex weights (some programmes do weigh sexes separately) are
  # kept and summed.
  #
  # Under DataType "P" (pseudo category sampling) the deduplication key is the
  # MAIN category, not the reported CatIdentifier. ICES's own guidance makes the
  # reason structural rather than incidental: a pseudocategory's raising factor
  # IS category weight / sample weight (in its worked haddock example,
  # 290.1 / 122.1988 = 2.374), so the category weight is necessarily present on
  # every pseudocategory row of that category. CatIdentifier is a two-part code
  # under "P" -- 11, 12, 13 are sub-categories of main category 1, 21 and 22 of
  # main category 2 -- and the archive agrees: every P code is exactly two
  # digits. Keying on the reported code therefore adds one category's weight
  # once per sub-category. Measured: 1,491 groups, 410,122,351 g, close to 29%
  # of all P weight mass, because sub-category sampling is used precisely on
  # the big catches.
  #
  # The collapse is deliberately limited to "P". Under "R" a repeated weight
  # across categories also occurs (209 groups) but its cause is NOT
  # established: 135 of them are a single vessel-year, and the 29 where
  # TotalNumber differs are a mix of implausible ties (two categories both at
  # exactly 9992 g) and plausible ones (two tiny catches both at 12 g). Worth
  # 485,711 g in total, 0.1% of the P defect. Those stay flagged
  # (WGT_CAT_REPEAT_R in hl_flag) rather than silently collapsed.
  hl_weights <- hl |>
    dplyr::select(.id, Valid_Aphia, SpeciesCategory, SpeciesValidity,
                  SpeciesCategoryWeight) |>
    dplyr::inner_join(hh_cols, by = ".id") |>
    dplyr::mutate(
      .wgt_cat = dplyr::if_else(
        DataType == "P",
        substr(as.character(SpeciesCategory), 1L, 1L),
        as.character(SpeciesCategory)
      )
    ) |>
    dplyr::distinct(.id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity,
                    .wgt_cat, SpeciesCategoryWeight, DataType, HaulDuration) |>
    dplyr::mutate(
      # Same zero-duration treatment as the counts above.
      w_haul_raw = dplyr::case_when(
        DataType == "C" & HaulDuration <= 0 ~ NA_real_,
        DataType == "C" ~ SpeciesCategoryWeight * HaulDuration / 60,
        TRUE            ~ SpeciesCategoryWeight
      ),
      w_hour_raw = dplyr::case_when(
        DataType == "C"   ~ SpeciesCategoryWeight,
        HaulDuration <= 0 ~ NA_real_,
        TRUE              ~ SpeciesCategoryWeight / HaulDuration * 60
      )
    ) |>
    dplyr::group_by(.id, Survey, Year, Quarter, Valid_Aphia, SpeciesValidity) |>
    dplyr::summarise(
      w_haul = sum(w_haul_raw, na.rm = TRUE),
      w_hour = sum(w_hour_raw, na.rm = TRUE),
      # Same all-NA guard as the counts above. It also settles a species with
      # no recorded weight at all (672,065 rows archive-wide) as NA in both
      # backends, rather than 0 eagerly and NULL lazily -- "not weighed" is
      # not "weighed nothing".
      .w_ok = sum(as.integer(!is.na(w_haul_raw)), na.rm = TRUE),
      .wh_ok = sum(as.integer(!is.na(w_hour_raw)), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      w_haul = dplyr::if_else(.w_ok == 0, NA_real_, w_haul),
      w_hour = dplyr::if_else(.wh_ok == 0, NA_real_, w_hour)
    ) |>
    dplyr::select(-.w_ok, -.wh_ok)

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
  # Grouped by SpeciesValidity as well as .id x Valid_Aphia -- the table's actual
  # grain. Without it these two are computed across every record type at once
  # and the same value is repeated onto each SpeciesValidity row, which is
  # exactly the silent mixing of record types DATRAS's own FAQ warns about
  # ("if you aggregate over .id x Valid_Aphia without also grouping on
  # SpeciesValidity, rows from different record types will be silently mixed
  # together"). Affects the 1,219 multi-validity groups.
  hl_pfem <- hl_len_base |>
    dr_add_n_and_cpue() |>
    dplyr::group_by(.id, Valid_Aphia, SpeciesValidity) |>
    dplyr::summarise(
      n_f = sum(dplyr::if_else(SpeciesSex %in% c("F", "B"), n_haul, 0), na.rm = TRUE),
      n_m = sum(dplyr::if_else(SpeciesSex == "M", n_haul, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      p_females = dplyr::if_else(n_f + n_m > 0, n_f / (n_f + n_m), NA_real_)
    ) |>
    dplyr::select(.id, Valid_Aphia, SpeciesValidity, p_females)

  # ---- n_haul: the raised length-frequency total -------------------------
  # The same quantity dr_HL_length() carries under the same name, summed to
  # this table's grain: sum(NumberAtLength x SubsamplingFactor), with the
  # DataType handling dr_add_n_and_cpue() applies.
  #
  # It sits beside n_totalnumber deliberately. The two are DIFFERENT routes to
  # one number -- n_totalnumber is what the submission declares, n_haul is what
  # the length frequencies reconstruct -- and they disagree for 3.85% of
  # groups. Carrying both makes that difference a subtraction in one table
  # rather than a grouped join across two, and a naive left_join() to
  # HL_length fans out and silently multiplies, which is a trap worth removing.
  #
  # The same all-NA guard as everywhere else: a group whose raising is unknown
  # (missing SubsamplingFactor, non-positive HaulDuration) must come back NA,
  # not the 0 that sum(x, na.rm = TRUE) yields in R.
  hl_raised <- hl_len_base |>
    dr_add_n_and_cpue() |>
    dplyr::mutate(.r_raw = n_haul) |>
    dplyr::group_by(.id, Valid_Aphia, SpeciesValidity) |>
    dplyr::summarise(
      n_haul = sum(.r_raw, na.rm = TRUE),
      .r_ok  = sum(as.integer(!is.na(.r_raw)), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(n_haul = dplyr::if_else(.r_ok == 0, NA_real_, n_haul)) |>
    dplyr::select(.id, Valid_Aphia, SpeciesValidity, n_haul)

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
    dplyr::group_by(.id, Valid_Aphia, SpeciesValidity) |>
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
                     by = c(".id", "Survey", "Year", "Quarter", "Valid_Aphia", "SpeciesValidity"),
                     na_matches = "na") |>
    dplyr::left_join(hl_raised, by = c(".id", "Valid_Aphia", "SpeciesValidity"),
                     na_matches = "na") |>
    dplyr::left_join(hl_pfem, by = c(".id", "Valid_Aphia", "SpeciesValidity"),
                     na_matches = "na") |>
    dplyr::left_join(hl_measured, by = c(".id", "Valid_Aphia", "SpeciesValidity"),
                     na_matches = "na") |>
    dplyr::mutate(n_measured = dplyr::if_else(is.na(.has_length), 0, n_measured)) |>
    dplyr::select(-.has_length) |>
    dr_join_species(species) |>
    dplyr::select(
      .id, Survey, Year, Quarter, Valid_Aphia, latin, species, rank,
      n_totalnumber, n_totalnumber_hour, n_haul, w_haul, w_hour,
      n_measured, p_females, SpeciesValidity
    )
}
