# Length-weight: predicting weight from length.
#
# The weight of one fish follows W = a * L^b. obus already produces the other
# two ingredients a haul's biomass needs -- dr_HL_length() gives the numbers
# caught (n_haul, n_hour) at each length_cm -- so the whole problem of getting
# weight out of a length-frequency table reduces to resolving (a, b) per
# species. No single source has them for every species, which is why the
# coefficients arrive through the ranked cascade in R/dr_resolve.R rather than
# from one lookup.
#
# This file holds the APPLY step -- dr_add_length_tl(), dr_add_predicted_weight()
# and dr_compare_length_weight(), all exported -- plus the internal producers
# that data-raw/DATASET_length_weight.R uses to BUILD the coefficient table:
# .dr_lw_fit_ca() (fit from obus's own CA data), .dr_lw_from_estimate()
# (FishBase, finfish) and .dr_lw_consensus()/.dr_lw_from_sealifebase()
# (SeaLifeBase, invertebrates). The cascade itself is assembled in that build
# script, not here.
#
# Ported from obus_retired 2026-09-02; `aphia` becomes `Valid_Aphia` throughout,
# the two lookups move from bundled .rda objects to dr_con() parquet tables, and
# dr_compare_length_weight() is rebuilt to span HL_length and HL_summary now
# that dr_HL_standardised() (which carried both in one table) is gone.


# ---- producers: used only by data-raw/DATASET_length_weight.R ---------------

# Internal: per-species log-log OLS on individual CA weight-at-length rows.
#
# Fits log(IndividualWeight) ~ log(length_cm) once per Valid_Aphia, directly on
# individual fish, via the nest/map/broom::glance() "many models" pattern.
# Fitting every species in CA this way takes a couple of seconds, so there is no
# performance reason to pre-aggregate to per-length-class means first -- and a
# good correctness reason not to: a count-weighted fit on bin MEANS equals a fit
# on raw rows only if the mean were taken in log space, which it is not. The
# retired implementation did pre-aggregate, and the damage showed up mostly in
# `sigma` rather than in a/b -- cod's sigma fell 0.73 -> 0.14 and herring's
# 1.61 -> 0.19 when the fit was moved onto raw rows, which matters because sigma
# drives dr_add_predicted_weight(bias_correct = TRUE).
#
# Returns one row per admissible species (a zero-row data frame if none).
#
# ca: data.frame with columns Valid_Aphia, length_cm, IndividualWeight -- one
#     row per individually-weighed fish. Restricting to NumberAtLength == 1, and
#     deciding which taxa are eligible to be fitted at all, are the CALLER's job
#     (see data-raw/DATASET_length_weight.R).
#
#     `length_cm` MUST already be the bin MIDPOINT (dr_add_length_mid()), not
#     the raw lower bound. CA's LengthClass is a lower boundary exactly as HL's
#     is, so fitting on lower bounds inflates `a` to compensate -- which only
#     cancels at apply time if the species happens to be reported at the same
#     bin width in both tables. It often is not: single-fish CA weight rows are
#     48.5% mm-resolution against HL_length's 31.8%. Fitting and applying on
#     midpoints removes the compensation entirely and makes these coefficients
#     directly comparable with FishBase's, which the cross-check assumes.
.dr_lw_fit_ca <- function(ca,
                          min_len_classes = 5L,
                          min_individuals = 30L,
                          b_range         = c(2, 4)) {
  for (pkg in c("broom", "purrr", "tidyr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(".dr_lw_fit_ca(): requires the '", pkg, "' package.", call. = FALSE)
    }
  }

  ca <- ca[is.finite(ca$length_cm) & ca$length_cm > 0 &
             is.finite(ca$IndividualWeight) & ca$IndividualWeight > 0, ,
           drop = FALSE]

  out <- ca |>
    tidyr::nest(data = c(length_cm, IndividualWeight)) |>
    dplyr::mutate(
      n_ca  = purrr::map_int(data, nrow),
      n_len = purrr::map_int(data, \(d) length(unique(d$length_cm)))
    ) |>
    dplyr::filter(n_len >= min_len_classes, n_ca >= min_individuals) |>
    dplyr::mutate(
      # Retransformation bias is left uncorrected here: exp(intercept) is the
      # MEDIAN weight at length, not the mean. Correcting it needs sigma, which
      # only this tier has, so applying it at build time would put ca_fit species
      # on a different scale from every other tier. It is an opt-in at apply
      # time instead -- see dr_add_predicted_weight(bias_correct = TRUE).
      fit = purrr::map(data, \(d) tryCatch(
        stats::lm(log(IndividualWeight) ~ log(length_cm), data = d),
        error = function(e) NULL))
    ) |>
    dplyr::filter(!purrr::map_lgl(fit, is.null)) |>
    dplyr::mutate(
      # sigma (residual SD on the log scale) is the multiplicative scatter and
      # the input to the bias correction. r2 is inflated by the wide length
      # range -- usually > 0.95 -- so it only really flags an outright bad fit.
      glance = purrr::map(fit, broom::glance),
      a      = purrr::map_dbl(fit, \(f) unname(exp(stats::coef(f)[["(Intercept)"]]))),
      b      = purrr::map_dbl(fit, \(f) unname(stats::coef(f)[["log(length_cm)"]])),
      r2     = purrr::map_dbl(glance, \(g) g$r.squared),
      sigma  = purrr::map_dbl(glance, \(g) g$sigma)
    ) |>
    dplyr::filter(is.finite(a), is.finite(b), a > 0,
                  b >= b_range[1], b <= b_range[2])

  as.data.frame(out[, c("Valid_Aphia", "a", "b", "n_ca", "n_len", "r2", "sigma")])
}


# Internal: turn rfishbase::estimate() output into a (Valid_Aphia, a, b) tier.
#
# FishBase's estimate() gives one Bayesian length-weight (a, b) per species,
# already borrowing down genus/family for data-poor species -- so for finfish it
# subsumes both the taxonomy cascade and the multi-study aggregation in a single
# call. There is no SeaLifeBase equivalent, which is why invertebrates need the
# very different .dr_lw_from_sealifebase() path below.
#
# est:      data.frame with columns Species, a, b (rfishbase::estimate output).
# name_map: data.frame with columns name (the scientific name queried) and
#           Valid_Aphia. The DATRAS code stays the key; the name is only the
#           lookup handle.
.dr_lw_from_estimate <- function(est, name_map, b_range = c(2, 4)) {
  ok <- !is.na(est$a) & !is.na(est$b) &
    est$a > 0 & est$b >= b_range[1] & est$b <= b_range[2]
  keep <- est[ok, c("Species", "a", "b"), drop = FALSE]
  m <- merge(name_map, keep, by.x = "name", by.y = "Species")
  m <- m[!duplicated(m$Valid_Aphia), c("Valid_Aphia", "a", "b"), drop = FALSE]
  m[order(m$Valid_Aphia), , drop = FALSE]
}


# Internal: reduce several length-weight studies to one (a, b) by consensus.
#
# a and b are jointly fitted and strongly correlated, so averaging them
# independently across studies is wrong -- mean(a) paired with mean(b) describes
# no real animal. Instead: predict weight across a reference length grid from
# each study's own (a, b), take the median predicted weight at each length, and
# refit one (a, b) to that consensus curve. Because the inputs are exact power
# laws, the grid choice barely matters.
#
# ab: data.frame with columns a, b (one row per source study). Returns a one-row
# data.frame(a, b, n_src), or NULL if no usable study.
.dr_lw_consensus <- function(ab, L = seq(2, 60, by = 1)) {
  ab <- ab[is.finite(ab$a) & is.finite(ab$b) & ab$a > 0, , drop = FALSE]
  if (nrow(ab) == 0L) return(NULL)
  if (nrow(ab) == 1L) return(data.frame(a = ab$a[1], b = ab$b[1], n_src = 1L))

  W    <- vapply(seq_len(nrow(ab)), function(i) ab$a[i] * L ^ ab$b[i],
                 numeric(length(L)))
  wmed <- apply(W, 1, stats::median)
  co   <- stats::coef(stats::lm(log(wmed) ~ log(L)))
  data.frame(a = unname(exp(co[[1]])), b = unname(co[[2]]), n_src = nrow(ab))
}


# Internal: turn SeaLifeBase length_weight() records into a (Valid_Aphia, a, b)
# tier.
#
# SeaLifeBase has no Bayesian estimate(), so this works from the raw per-study
# records, with two invertebrate-specific concerns the fish path does not have:
#
#   1. Records are DIMENSION-specific. `Type` is a mantle length, a carapace
#      length or width, a shell length -- not total length. Only records whose
#      Type matches the dimension DATRAS measures for that target are kept
#      (name_map's `dim` column, resolved by the caller). A species measured
#      only on a non-matching dimension is left unresolved rather than filled
#      with a coefficient for a different body axis.
#   2. Several studies per taxon are reduced by .dr_lw_consensus(), never by
#      averaging a and b.
#
# rec:      SeaLifeBase length_weight() records (columns Species, a, b, Type).
# name_map: data.frame with columns name, Valid_Aphia, dim (the expected Type
#           code for this target, e.g. "ML", "CL", "CW", "ShL").
.dr_lw_from_sealifebase <- function(rec, name_map, b_range = c(2, 4)) {
  empty <- data.frame(Valid_Aphia = integer(0), a = numeric(0), b = numeric(0))

  ok <- !is.na(rec$a) & !is.na(rec$b) &
    rec$a > 0 & rec$b >= b_range[1] & rec$b <= b_range[2]
  rec <- rec[ok, c("Species", "a", "b", "Type"), drop = FALSE]

  m <- merge(name_map, rec, by.x = "name", by.y = "Species")
  if (nrow(m) == 0L) return(empty)

  m <- m[!is.na(m$dim) & m$Type == m$dim, , drop = FALSE]
  if (nrow(m) == 0L) return(empty)

  parts <- split(m, m$Valid_Aphia)
  out <- lapply(names(parts), function(k) {
    cons <- .dr_lw_consensus(parts[[k]][, c("a", "b")])
    if (is.null(cons)) return(NULL)
    data.frame(Valid_Aphia = as.integer(k), a = cons$a, b = cons$b)
  })
  res <- do.call(rbind, out)
  if (is.null(res)) empty else res[order(res$Valid_Aphia), , drop = FALSE]
}


# ---- apply -----------------------------------------------------------------

#' Convert a non-Total-Length landmark to Total Length
#'
#' Length-weight coefficients are fitted against Total Length; applying one to a
#' length measured to a different landmark -- Standard Length, Pre-Anal-Fin
#' Length -- biases the prediction, and nothing else in the pipeline flags it.
#' This converts \code{length_cm} to its Total Length equivalent for the species
#' and \code{LengthType} combinations covered by the
#' \code{"length_type_conversion"} lookup, and leaves every other row
#' unconverted, recording which happened in \code{length_type_source} rather
#' than leaving the caller to guess.
#'
#' The lookup is deliberately narrow. It holds only factors traced to a primary
#' publication; the wider set in Marine Scotland Science's \code{7_Species_QA}
#' (\url{https://github.com/MarineScotlandScience/MSFD-QA-GFSM-A-DP}) includes
#' Alepocephalidae (Standard Length) and Chimaeridae (Pre-Supra-Caudal-Fin
#' Length) factors that script does not cite to a paper, so those species come
#' back \code{"unconverted"} rather than converted with an untraceable number.
#'
#' The converted length lands in a NEW column, \code{length_cm_tl}; the input
#' column is never overwritten. To predict weight from the converted length,
#' pass it on explicitly:
#' \code{dr_add_predicted_weight(length_col = "length_cm_tl")}.
#'
#' \strong{Convert the bin MIDPOINT, not the bin's lower bound.} The conversion
#' is affine (\eqn{TL = intercept + slope \cdot L}), so it rescales the bin
#' width by \code{slope} as well as the length. Taking the midpoint afterwards
#' would add half of the \emph{measured} bin width to an already-converted
#' length and land in the wrong place. Run \code{\link{dr_add_length_mid}} first
#' and pass \code{length_col = "length_cm_mid"}, which is the default.
#'
#' @param catch A catch table (data frame or lazy table) with at least
#'   \code{Valid_Aphia}, \code{LengthType} and the column named by
#'   \code{length_col} -- as produced by \code{\link{dr_HL_length}} followed by
#'   \code{\link{dr_add_length_mid}}.
#' @param conv Conversion lookup with columns \code{Valid_Aphia},
#'   \code{from_type}, \code{intercept}, \code{slope}. Defaults to
#'   \code{dr_con("length_type_conversion")}, collected first when \code{catch}
#'   is an eager data frame.
#' @param length_col Name of the length column to convert, in centimetres.
#'   Default \code{"length_cm_mid"} (see above).
#'
#' @return \code{catch} with the joined lookup columns plus:
#'   \describe{
#'     \item{\code{length_cm_tl}}{\code{length_col} converted to Total Length
#'       where a factor applies, else \code{length_col} unchanged.}
#'     \item{\code{length_type_source}}{\code{"measured_tl"} (\code{LengthType}
#'       is \code{"1"} or \code{NA} -- already Total Length, or the assume-TL
#'       default), \code{"converted"} (a factor was applied), or
#'       \code{"unconverted"} (a non-TL landmark with no traced factor).}
#'   }
#'
#' @seealso \code{\link{dr_add_predicted_weight}}, \code{\link{dr_HL_length}}
#' @export
dr_add_length_tl <- function(catch, conv = NULL, length_col = "length_cm_mid") {
  .dr_require_cols(catch, c("Valid_Aphia", "LengthType", length_col),
                   "dr_add_length_tl")

  if (is.null(conv)) {
    conv <- dr_con("length_type_conversion")
    if (!inherits(catch, "tbl_lazy")) conv <- dplyr::collect(conv)
  }

  need_copy <- inherits(catch, "tbl_lazy") && !inherits(conv, "tbl_lazy")
  len <- rlang::sym(length_col)

  catch |>
    dplyr::left_join(
      conv,
      by = dplyr::join_by(Valid_Aphia == Valid_Aphia, LengthType == from_type),
      copy = need_copy
    ) |>
    dplyr::mutate(
      length_cm_tl = dplyr::if_else(!is.na(slope),
                                    intercept + slope * (!!len), !!len),
      length_type_source = dplyr::case_when(
        LengthType == "1" | is.na(LengthType) ~ "measured_tl",
        !is.na(slope)                         ~ "converted",
        TRUE                                  ~ "unconverted"
      )
    )
}


#' Predict individual and catch weight from length
#'
#' Attaches length-weight coefficients \eqn{(a, b)} to a length-resolved catch
#' table and computes \eqn{W = a \cdot L^b}. The coefficients come from the
#' \code{"length_weight"} lookup, whose \code{lw_source} column records, per
#' species, which tier of the resolution cascade supplied them -- a fit on
#' obus's own CA data, a FishBase or SeaLifeBase estimate, or the generic
#' finfish constant. That label is carried through onto every predicted weight,
#' so a prediction always states how it was arrived at.
#'
#' Predicted weight is in GRAMS, following the FishBase convention
#' \eqn{W(\mathrm{g}) = a \cdot L(\mathrm{cm})^b}, so the length column must be
#' in centimetres. Where a per-length count is present (\code{n_haul} and/or
#' \code{n_hour}, as on \code{\link{dr_HL_length}}) the corresponding predicted
#' catch weights are added by multiplication.
#'
#' Species with no resolved coefficient keep \code{NA} and therefore predict
#' \code{NA}. The function never substitutes a constant of its own: the lookup
#' already carries the constant tier explicitly for the taxa where one is
#' defensible, and labels the rest \code{"unresolved"} or
#' \code{"not_applicable"}.
#'
#' \strong{Length must be a bin MIDPOINT, and the default insists on it.}
#' \code{length_cm} is the lower boundary of a length bin, not a fish's length
#' (see \code{\link{dr_add_length_mid}}). Because \eqn{W = a L^b} is convex,
#' feeding it the lower bound under-predicts weight systematically -- 5.1% at
#' 30 cm with 1 cm bins, 15.8% at 10 cm -- and the error does not cancel when
#' summed over a haul. \code{length_col} therefore defaults to
#' \code{"length_cm_mid"}, so a pipeline that skipped
#' \code{\link{dr_add_length_mid}} errors instead of quietly returning low
#' weights. The coefficients are fitted on midpoints too, so both sides of the
#' prediction use the same convention.
#'
#' \strong{Length landmark.} \code{length_col} is assumed to be Total Length.
#' About 6.5% of HL rows are measured to a different landmark and would get a
#' TL-fitted coefficient applied to a non-TL length. Run
#' \code{\link{dr_add_length_tl}} between the two steps and pass
#' \code{length_col = "length_cm_tl"} to convert the species where a traced
#' factor exists. The full pipeline is
#' \code{dr_add_length_mid() |> dr_add_length_tl() |> dr_add_predicted_weight(length_col = "length_cm_tl")}.
#'
#' @param catch A length-resolved catch table (data frame or lazy table) with at
#'   least \code{Valid_Aphia} and the column named by \code{length_col}.
#'   \code{n_haul} and \code{n_hour} are used when present.
#' @param lw Coefficient lookup with columns \code{Valid_Aphia}, \code{a},
#'   \code{b} (and, carried through, \code{lw_source} and the fit metadata).
#'   Defaults to \code{dr_con("length_weight")}, collected first when
#'   \code{catch} is an eager data frame.
#' @param length_col Name of the length column, in centimetres, holding a bin
#'   MIDPOINT. Default \code{"length_cm_mid"} (from
#'   \code{\link{dr_add_length_mid}}); use \code{"length_cm_tl"} after
#'   \code{\link{dr_add_length_tl}}. Passing \code{"length_cm"} reinstates the
#'   lower-bound bias and is almost never what you want.
#' @param bias_correct Logical. If \code{TRUE}, scale \code{a} by the lognormal
#'   retransformation correction \eqn{\exp(\sigma^2 / 2)} wherever
#'   \code{lw_source == "ca_fit"} and a \code{sigma} is present -- the log-log
#'   fit otherwise estimates the median, not the mean, weight. No other tier
#'   carries a \code{sigma}, so mixing tiers under \code{TRUE} gives mean
#'   predictions for some species and median for others; the default
#'   \code{FALSE} keeps one consistent scale everywhere.
#' @param exclude_tiers Character vector of \code{lw_source} values to exclude,
#'   or \code{NULL} (default) to use every tier. Matching rows get \code{NA}
#'   coefficients, and therefore \code{NA} predictions, instead of silently
#'   using a tier the caller has reason to distrust -- the coarse
#'   \code{sealifebase_genus}/\code{_family} tiers systematically over-predict,
#'   as \code{\link{dr_compare_length_weight}} shows.
#'
#' @return \code{catch} with the joined coefficient columns plus \code{w_ind}
#'   (predicted individual weight, grams) and -- where the input carries the
#'   counts -- \code{w_haul_pred} (\code{n_haul * w_ind}) and \code{w_hour_pred}
#'   (\code{n_hour * w_ind}).
#'
#' @seealso \code{\link{dr_compare_length_weight}}, \code{\link{dr_HL_length}},
#'   \code{\link{dr_add_length_tl}}
#' @export
dr_add_predicted_weight <- function(catch, lw = NULL,
                                    length_col = "length_cm_mid",
                                    bias_correct = FALSE, exclude_tiers = NULL) {
  # The likeliest mistake is piping HL_length straight in, which has length_cm
  # but not length_cm_mid. .dr_require_cols() would say "missing required
  # columns: length_cm_mid" and leave the reader to work out why that column is
  # wanted, so name the fix instead.
  if (!length_col %in% colnames(catch) &&
      identical(length_col, "length_cm_mid") &&
      "length_cm" %in% colnames(catch)) {
    stop("dr_add_predicted_weight: `catch` has `length_cm` but not ",
         "`length_cm_mid`. `length_cm` is the LOWER BOUND of a length bin, and ",
         "predicting weight from it under-estimates by several percent. Run ",
         "dr_add_length_mid() first, or pass length_col = \"length_cm\" ",
         "deliberately to accept that bias.", call. = FALSE)
  }
  .dr_require_cols(catch, c("Valid_Aphia", length_col), "dr_add_predicted_weight")

  if (is.null(lw)) {
    lw <- dr_con("length_weight")
    if (!inherits(catch, "tbl_lazy")) lw <- dplyr::collect(lw)
  }

  if (!is.null(exclude_tiers)) {
    lw <- dplyr::mutate(
      lw,
      a = dplyr::if_else(lw_source %in% exclude_tiers, NA_real_, a),
      b = dplyr::if_else(lw_source %in% exclude_tiers, NA_real_, b)
    )
  }

  need_copy <- inherits(catch, "tbl_lazy") && !inherits(lw, "tbl_lazy")
  len <- rlang::sym(length_col)

  out <- dplyr::left_join(catch, lw, by = "Valid_Aphia", copy = need_copy)

  if (isTRUE(bias_correct)) {
    out <- dplyr::mutate(
      out,
      a = dplyr::if_else(lw_source == "ca_fit" & !is.na(sigma),
                         a * exp(sigma ^ 2 / 2), a)
    )
  }

  out <- dplyr::mutate(out, w_ind = a * (!!len) ^ b)

  if ("n_haul" %in% colnames(catch)) {
    out <- dplyr::mutate(out, w_haul_pred = n_haul * w_ind)
  }
  if ("n_hour" %in% colnames(catch)) {
    out <- dplyr::mutate(out, w_hour_pred = n_hour * w_ind)
  }

  out
}


#' Compare modelled catch weight against the measured catch weight
#'
#' Cross-checks the length-weight prediction against the independent
#' \emph{measured} weight obus already carries. For each haul \eqn{\times}
#' species the modelled total -- \eqn{\sum_{\mathrm{lengths}} n\_haul \cdot a
#' \cdot L^{b}}, summed over \code{\link{dr_HL_length}}'s rows -- is compared
#' with \code{w_haul} from \code{\link{dr_HL_summary}}, which derives from the
#' reported \code{SpeciesCategoryWeight}. The two are computed from different
#' fields by different routes, so their agreement is a genuine test rather than
#' a restatement.
#'
#' \strong{A mismatch is surfaced, never resolved.} A discrepancy can mean the
#' coefficients are wrong \emph{or} that the reported weight is wrong -- some
#' surveys' reported weight barely correlates with the length-reconstructed
#' weight -- and there is no principled way to pick a winner between two
#' independent measurements. This function reports; it never edits either
#' quantity.
#'
#' \strong{Ambiguous groups are excluded, not summed.} \code{\link{dr_HL_summary}}
#' is grained by \code{.id} \eqn{\times} \code{Valid_Aphia} \eqn{\times}
#' \code{SpeciesValidity}, and where a group splits across record types the
#' reported weight is often the same species-level total repeated rather than a
#' real partition -- summing it would double-count. Unlike \code{TotalNumber},
#' \code{SpeciesCategoryWeight} has no per-row arithmetic check that can tell
#' the two apart, so those groups are dropped from the comparison and counted in
#' the result instead. Archive-wide this is about 0.05% of groups.
#'
#' @param len A length table from \code{\link{dr_HL_length}} or
#'   \code{dr_con("HL_length")}. Pre-filter (to one survey, year or species)
#'   before calling for a scoped comparison.
#' @param smry The matching haul summary from \code{\link{dr_HL_summary}} or
#'   \code{dr_con("HL_summary")}, filtered the same way.
#' @param lw Coefficient lookup, as for \code{\link{dr_add_predicted_weight}}.
#' @param tol Tolerance band on the modelled/measured ratio. Default
#'   \code{0.25}, i.e. \eqn{\pm}25%.
#' @param flag Logical. \code{FALSE} (default) returns a one-row summary;
#'   \code{TRUE} returns the per-haul \eqn{\times} species comparison
#'   (\code{.id}, \code{Valid_Aphia}, \code{w_modelled}, \code{w_measured},
#'   \code{ratio}, \code{lw_source}, \code{.within_tol}), which is the form to
#'   group by \code{lw_source} when grading the tiers.
#'
#' @return A one-row data frame -- \code{n_compared}, \code{n_outside},
#'   \code{pct_outside}, \code{median_ratio}, \code{tol},
#'   \code{n_ambiguous_excluded} -- or, with \code{flag = TRUE}, the per-group
#'   comparison.
#'
#' @seealso \code{\link{dr_add_predicted_weight}}, \code{\link{dr_HL_length}},
#'   \code{\link{dr_HL_summary}}
#' @export
dr_compare_length_weight <- function(len, smry, lw = NULL, tol = 0.25,
                                     flag = FALSE) {
  .dr_require_cols(len, c(".id", "Valid_Aphia", "length_cm", "accuracy", "n_haul"),
                   "dr_compare_length_weight")
  .dr_require_cols(smry, c(".id", "Valid_Aphia", "w_haul"),
                   "dr_compare_length_weight")

  if (is.null(lw)) {
    lw <- dr_con("length_weight")
    if (!inherits(len, "tbl_lazy")) lw <- dplyr::collect(lw)
  }

  modelled <- len |>
    dplyr::select(.id, Valid_Aphia, length_cm, accuracy, n_haul) |>
    dr_add_length_mid() |>
    dr_add_predicted_weight(lw) |>
    dplyr::group_by(.id, Valid_Aphia) |>
    dplyr::summarise(w_modelled = sum(w_haul_pred, na.rm = TRUE),
                     .groups = "drop")

  # Collapse the summary to the comparison grain, carrying the row count so the
  # SpeciesValidity-split groups can be set aside rather than silently summed.
  measured <- smry |>
    dplyr::group_by(.id, Valid_Aphia) |>
    dplyr::summarise(w_measured = sum(w_haul, na.rm = TRUE),
                     n_rows = dplyr::n(), .groups = "drop")

  cmp <- dplyr::inner_join(modelled, measured, by = c(".id", "Valid_Aphia")) |>
    dplyr::filter(w_measured > 0, w_modelled > 0)

  cmp <- .dr_maybe_collect(cmp)

  n_ambiguous <- sum(cmp$n_rows > 1L, na.rm = TRUE)
  cmp <- cmp[cmp$n_rows == 1L, , drop = FALSE]
  cmp$n_rows <- NULL
  cmp$ratio <- cmp$w_modelled / cmp$w_measured
  cmp$.within_tol <- abs(cmp$ratio - 1) <= tol

  lw_eager <- .dr_maybe_collect(lw)
  cmp <- dplyr::left_join(cmp, lw_eager[, c("Valid_Aphia", "lw_source")],
                          by = "Valid_Aphia")

  if (flag) return(cmp)

  n_total <- nrow(cmp)
  data.frame(
    n_compared           = n_total,
    n_outside            = sum(!cmp$.within_tol, na.rm = TRUE),
    pct_outside          = if (n_total == 0L) NA_real_ else
      round(100 * sum(!cmp$.within_tol, na.rm = TRUE) / n_total, 1),
    median_ratio         = if (n_total == 0L) NA_real_ else
      stats::median(cmp$ratio, na.rm = TRUE),
    tol                  = tol,
    n_ambiguous_excluded = as.integer(n_ambiguous)
  )
}


# Collect a lazy table before row-level base-R work. A no-op on a data frame.
.dr_maybe_collect <- function(d) {
  if (inherits(d, "tbl_lazy")) dplyr::collect(d) else d
}
