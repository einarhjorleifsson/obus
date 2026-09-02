# Shared primitive for resolve-with-provenance.
#
# Several obus quantities have no single authoritative source. Length-weight
# coefficients are the first: no one database has (a, b) for every species, and
# the reliability of what exists varies by taxon and region. The house answer is
# a ranked cascade -- try the most specific evidence first, fall back to
# progressively coarser sources, and record on every row WHICH tier answered.
#
# This file holds only the *collapse*. Candidate PRODUCTION (model fits, joins,
# aggregation) is variable-specific and lives in each variable's own producer --
# see .dr_lw_fit_ca() and friends in R/dr_length_weight.R. All this function
# does is choose, per target row, the first tier that offers a non-missing
# value, and stamp that tier's label into a provenance column.
#
# Two invariants the callers must uphold, because the collapse cannot check
# them cheaply:
#
#   1. Each tier's `data` is already aggregated to at most ONE row per key.
#      The collapse never joins with fan-out.
#   2. Each tier's `data` is already filtered to admissible rows. The collapse
#      never applies plausibility gates; a value present in a tier is a value
#      that tier vouches for.
#
# `value_cols` are taken as an ATOMIC UNIT from a single tier. For length-weight
# that is load-bearing: `a` and `b` are jointly fitted and strongly correlated,
# so an `a` from one source paired with a `b` from another describes no fish
# that ever swam.
#
# Ported from obus_retired 2026-09-02, with the eager default key changed from
# `aphia` to `Valid_Aphia` (obus carries opus's field names unchanged). Both the
# eager and lazy implementations are kept: the eager one resolves small
# per-species dimensions like length-weight, the lazy one resolves per-haul
# quantities on the large fact tables, where collecting first is not an option.


# Collapse ordered candidate tiers into one resolved value bundle + provenance.
#
# base:        data.frame OR lazy DuckDB table of target rows carrying the key
#              column(s). When lazy, each tier$data must be an eager data.frame;
#              it is uploaded to DuckDB via copy = TRUE.
# tiers:       ordered list, MOST SPECIFIC FIRST, each
#              list(label = <chr>, data = <data.frame with keys + value_cols>).
# value_cols:  the bundle resolved together, e.g. c("a", "b").
# keys:        join key column(s).
# source_col:  name of the provenance column added.
# unresolved_label: label for rows no tier resolved.
#
# Returns `base` plus value_cols (from the first tier with a non-NA value for
# that key) and source_col (that tier's label, or unresolved_label).
.dr_coalesce_with_provenance <- function(base, tiers, value_cols,
                                         keys = "Valid_Aphia",
                                         source_col = ".source",
                                         unresolved_label = "unresolved") {
  if (inherits(base, "tbl_lazy")) {
    return(.dr_coalesce_with_provenance_lazy(base, tiers, value_cols,
                                             keys, source_col, unresolved_label))
  }
  .dr_coalesce_with_provenance_eager(base, tiers, value_cols,
                                     keys, source_col, unresolved_label)
}


# Eager (data.frame) implementation -- base R, for small-dimension output.
#
# Deliberately not dplyr: the operation is "fill the still-empty slots from this
# tier", which is a vectorised subassignment, and match() on a pasted key
# expresses it directly. A coalesce()-per-tier chain of left_joins would build
# one intermediate frame per tier and still need the same NA bookkeeping.
.dr_coalesce_with_provenance_eager <- function(base, tiers, value_cols,
                                               keys = "Valid_Aphia",
                                               source_col = ".source",
                                               unresolved_label = "unresolved") {
  # "\r" as the separator, not "_" or "-": it cannot occur inside an Aphia code,
  # a survey name or any other DATRAS key field, so two different key tuples
  # cannot collide into one string.
  key_str <- function(df) do.call(paste, c(as.list(df[keys]), sep = "\r"))

  out <- base
  for (v in value_cols) if (!v %in% names(out)) out[[v]] <- NA_real_
  out[[source_col]] <- NA_character_
  bkey <- key_str(out)

  for (tier in tiers) {
    cand <- tier$data
    if (is.null(cand) || nrow(cand) == 0L) next
    if (!all(value_cols %in% names(cand))) {
      stop(".dr_coalesce_with_provenance: tier '", tier$label,
           "' is missing value column(s): ",
           paste(setdiff(value_cols, names(cand)), collapse = ", "),
           call. = FALSE)
    }

    idx <- match(bkey, key_str(cand))
    # Three conditions, all required: this row is still unresolved, this tier
    # has a row for it, and that row actually carries a value. The third is why
    # a tier may legitimately contain NA rows -- it declines to answer for them.
    fillable <- is.na(out[[source_col]]) &
      !is.na(idx) &
      !is.na(cand[[value_cols[1]]][idx])
    if (!any(fillable)) next

    for (v in value_cols) out[[v]][fillable] <- cand[[v]][idx[fillable]]
    out[[source_col]][fillable] <- tier$label
  }

  out[[source_col]][is.na(out[[source_col]])] <- unresolved_label
  out
}


# Lazy (DuckDB) implementation -- for output whose grain is large enough that
# collecting it into R first is not reasonable (per-haul rather than
# per-species). Each tier's data must be an eager data.frame; it is uploaded to
# the DuckDB connection via copy = TRUE in the left_join.
.dr_coalesce_with_provenance_lazy <- function(base, tiers, value_cols,
                                              keys = ".id",
                                              source_col = ".source",
                                              unresolved_label = "unresolved") {
  out <- base

  existing <- colnames(out)
  for (v in value_cols) {
    if (!v %in% existing) out <- dplyr::mutate(out, !!rlang::sym(v) := NA_real_)
  }
  ss <- rlang::sym(source_col)
  out <- dplyr::mutate(out, !!ss := NA_character_)

  for (tier in tiers) {
    cand <- tier$data
    if (is.null(cand) || nrow(cand) == 0L) next
    if (!all(value_cols %in% names(cand))) {
      stop(".dr_coalesce_with_provenance_lazy: tier '", tier$label,
           "' is missing value column(s): ",
           paste(setdiff(value_cols, names(cand)), collapse = ", "),
           call. = FALSE)
    }

    # Prefix the candidate's value columns so the join cannot collide with the
    # accumulating output columns of the same name.
    cand_r <- dplyr::rename_with(cand, ~ paste0(".cand_", .x),
                                 dplyr::all_of(value_cols))

    out <- dplyr::left_join(out, cand_r, by = keys, copy = TRUE)

    # Fill from this tier -- every value_col together, gated on the SAME
    # condition (source still NA, and this tier's first value present), so the
    # bundle can never be split across two tiers.
    scv1 <- rlang::sym(paste0(".cand_", value_cols[1]))
    for (v in value_cols) {
      sv  <- rlang::sym(v)
      scv <- rlang::sym(paste0(".cand_", v))
      out <- dplyr::mutate(
        out, !!sv := dplyr::if_else(is.na(!!ss) & !is.na(!!scv1), !!scv, !!sv))
    }
    out <- dplyr::mutate(
      out, !!ss := dplyr::if_else(is.na(!!ss) & !is.na(!!scv1), tier$label, !!ss))

    out <- dplyr::select(out, -dplyr::starts_with(".cand_"))
  }

  dplyr::mutate(out, !!ss := dplyr::coalesce(!!ss, unresolved_label))
}
