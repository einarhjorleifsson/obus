# The eight fields that identify a dr_HL_length() row, and what may be done to
# each. Kept as constants because the error messages below quote them and the
# tests assert against them; a grain change must break in one place.
.DR_HL_GRAIN <- c(".id", "Valid_Aphia", "length_mm", "accuracy", "LengthType",
                  "SpeciesSex", "DevelopmentStage", "SpeciesValidity")

# Summable without qualification: two rows differing only in sex, stage or
# record type are two genuine counts of the same thing at the same length.
.DR_HL_FREE <- c("SpeciesSex", "DevelopmentStage", "SpeciesValidity")

# Summable only where the group does not actually mix them -- see the mixing
# check in dr_HL_collapse().
.DR_HL_GUARDED <- c("accuracy", "LengthType")

# The measure columns, in the order dr_HL_length() emits them.
.DR_HL_MEASURES <- c("n_haul", "n_hour", "n_measured")


#' Collapse dimensions out of the length-frequency catch table
#'
#' \code{\link{dr_HL_length}} publishes at the finest grain DATRAS supports:
#' one row per \code{.id} \eqn{\times} \code{Valid_Aphia} \eqn{\times}
#' \code{length_mm} \eqn{\times} \code{accuracy} \eqn{\times}
#' \code{LengthType} \eqn{\times} \code{SpeciesSex} \eqn{\times}
#' \code{DevelopmentStage} \eqn{\times} \code{SpeciesValidity}. Every
#' comparable project sums at least two of those away -- ICES's own CPUEL
#' drops sex, development stage and record type; Marine Scotland's
#' \code{9_Baseline_Bio_DP} drops sex and stage; FishGlob drops those plus
#' length -- so anyone arriving from one of them needs the reduction. You can
#' collapse down and never back up, which is why obus publishes fine and
#' reduces on request rather than the other way round.
#'
#' This is a verb on the table rather than an argument on the builder because
#' the builder is the minority path: \code{dr_con("HL_length")} returns the
#' same 18 columns as \code{\link{dr_HL_length}} and is how the table is
#' actually read. It takes either a lazy table or a collected data frame, and
#' on the lazy path the aggregation pushes to the server.
#'
#' \strong{What it is actually for is the guards}, which a hand-rolled
#' \code{group_by() |> summarise(sum())} silently loses:
#'
#' \itemize{
#'   \item \strong{The all-\code{NA} divergence.} \code{sum(x, na.rm = TRUE)}
#'     over a group with nothing in it is \code{0} in R and \code{NULL} in SQL,
#'     so a group whose raising is genuinely unknown comes back as a confident
#'     zero on the eager path. Each measure carries its own non-\code{NA}
#'     counter and is restored to \code{NA} where that counter is zero.
#'   \item \strong{The \code{DataType == "C"} rule for \code{n_measured}.}
#'     That convention reports an hourly rate rather than a count, so
#'     \code{\link{dr_HL_length}} sets \code{n_measured} to \code{NA} on those
#'     rows. \code{HL_length} does not carry \code{DataType}, but it does not
#'     need to: \code{DataType} is haul-level and \code{.id} is never
#'     collapsed, so every row of a group shares it and the all-\code{NA} guard
#'     above reproduces the rule exactly. A group is all-\code{NA} or none.
#' }
#'
#' \strong{\code{accuracy} and \code{LengthType} are collapsed only where the
#' data does not mix them.} Two records at \code{length_mm == 150} measured to
#' 1 cm and to 5 cm are different bins, and \code{LengthType} mixes total
#' against standard length; summing across either invents a count for a bin
#' nobody measured. \code{{DATRAS}}'s \code{addSpectrum()} collapses a mixed
#' \code{LngtCode} to the coarsest with only a warning -- obus errors instead,
#' and names the groups. This is rare rather than theoretical: over the full
#' archive, collapsing to \code{.id} \eqn{\times} \code{Valid_Aphia}
#' \eqn{\times} \code{length_mm} yields 13,214,965 groups of which 18 mix
#' \code{accuracy} and 4,051 mix \code{LengthType} (0.031\%, measured
#' 2026-09-17). The check costs a full scan and runs only when one of these
#' two is named in \code{collapse}; set \code{check = FALSE} to skip it, which
#' is a claim that you have established homogeneity some other way.
#'
#' \strong{\code{SpeciesValidity} collapses, but say so deliberately.} It is
#' tempting to read it as a quality flag and filter to \code{1}; it is not
#' one. It is a \emph{record type}, and DATRAS allows several per species per
#' haul -- lengths on one row, a total-only count on another -- so filtering
#' discards real records rather than bad ones. Summing across it is the right
#' operation for a total; naming it in \code{collapse} is what makes that
#' deliberate rather than accidental. It is also very nearly free: dropping it
#' merges only 15 groups archive-wide. One caveat to carry: Can-Mar puts real
#' length data on validity-\code{5} rows where every other survey does not.
#'
#' \strong{It does not reproduce \code{\link{dr_HL_summary}}.} That table's
#' totals come from the submitted \code{TotalNumber}; summing length rows is a
#' different quantity arrived at the other way, and the gap between the two is
#' a finding rather than an error. \code{length_mm} is therefore not
#' collapsible here.
#'
#' @param x A \code{\link{dr_HL_length}} table -- lazy (e.g.
#'   \code{dr_con("HL_length")}) or collected. Any column that is neither
#'   named in \code{collapse} nor a measure becomes part of the output grain,
#'   so columns added upstream are retained rather than silently summed over.
#' @param collapse Character vector of dimensions to sum away. Allowed:
#'   \code{"SpeciesSex"}, \code{"DevelopmentStage"},
#'   \code{"SpeciesValidity"}, and -- subject to the mixing check --
#'   \code{"accuracy"}, \code{"LengthType"}.
#' @param check Run the mixing check for \code{accuracy}/\code{LengthType}.
#'   Ignored when neither is being collapsed.
#'
#' @return \code{x} with the named dimensions removed and
#'   \code{n_haul}/\code{n_hour}/\code{n_measured} summed over them, lazy if
#'   \code{x} was lazy. Column order is preserved.
#'
#' @examples
#' \dontrun{
#' # obus's eight identifying fields reduced to CPUEL's three
#' # (.id x Valid_Aphia x length_mm). Scoped to one survey, because the
#' # archive as a whole mixes LengthType on 4,051 groups and the check --
#' # correctly -- refuses it.
#' dr_con("HL_length") |>
#'   dplyr::filter(Survey == "NS-IBTS", Year == 2022, Quarter == 1L) |>
#'   dr_HL_collapse(c("SpeciesSex", "DevelopmentStage", "SpeciesValidity",
#'                    "accuracy", "LengthType"))
#' }
#'
#' @seealso \code{\link{dr_HL_length}}, \code{\link{dr_HL_summary}}
#' @export
dr_HL_collapse <- function(x, collapse, check = TRUE) {
  if (!is.character(collapse) || !length(collapse)) {
    stop("`collapse` must be a non-empty character vector naming dimensions ",
         "to sum away. Allowed: ",
         paste(sQuote(c(.DR_HL_FREE, .DR_HL_GUARDED)), collapse = ", "), ".",
         call. = FALSE)
  }
  collapse <- unique(collapse)
  nm <- colnames(x)

  # -- refusals, most specific message first ---------------------------------
  if ("length_mm" %in% collapse || "length_cm" %in% collapse) {
    stop("length is not collapsible here. Summing length rows to a per-haul ",
         "species total is a different quantity from dr_HL_summary()'s ",
         "n_totalnumber, which comes from the submitted TotalNumber; the gap ",
         "between them is a finding, not a rounding error. Use ",
         "dr_HL_summary() if you want the reported total.", call. = FALSE)
  }
  if (any(c(".id", "Valid_Aphia") %in% collapse)) {
    stop("`.id` and `Valid_Aphia` identify the observation and cannot be ",
         "collapsed. Collapsing `.id` would also break the DataType == \"C\" ",
         "guard on n_measured, which holds only because every row of a group ",
         "shares a haul.", call. = FALSE)
  }
  bad <- setdiff(collapse, c(.DR_HL_FREE, .DR_HL_GUARDED))
  if (length(bad)) {
    stop("Cannot collapse ", paste(sQuote(bad), collapse = ", "), ". Allowed: ",
         paste(sQuote(c(.DR_HL_FREE, .DR_HL_GUARDED)), collapse = ", "), ".",
         call. = FALSE)
  }
  missing <- setdiff(collapse, nm)
  if (length(missing)) {
    stop("Not a column of `x`: ", paste(sQuote(missing), collapse = ", "), ".",
         call. = FALSE)
  }

  # HL_summary carries n_haul and n_measured too, so the measure test below
  # would pass and the verb would quietly group by w_haul/n_totalnumber/
  # p_females instead of summing them. Its grain and its guards are different
  # -- n_totalnumber comes from the submitted TotalNumber, not from raising --
  # so refuse it by name rather than doing something plausible-looking.
  summary_only <- intersect(c("n_totalnumber", "n_totalnumber_hour", "w_haul",
                              "w_hour", "p_females"), nm)
  if (length(summary_only)) {
    stop("`x` looks like dr_HL_summary(), not dr_HL_length() -- it carries ",
         paste(sQuote(summary_only), collapse = ", "),
         ". This verb is for the length table; it would leave those columns ",
         "in the grain rather than summing them. To collapse HL_summary over ",
         "SpeciesValidity, group and sum the columns you want explicitly, ",
         "choosing for each whether a sum is meaningful (p_females is a ",
         "proportion, not a count).", call. = FALSE)
  }

  measures <- intersect(.DR_HL_MEASURES, nm)
  if (!length(measures)) {
    stop("`x` carries none of ", paste(sQuote(.DR_HL_MEASURES), collapse = ", "),
         " -- it does not look like a dr_HL_length() table.", call. = FALSE)
  }
  keep <- setdiff(nm, c(collapse, measures))

  # -- the mixing check, only when it can fire -------------------------------
  guarded <- intersect(collapse, .DR_HL_GUARDED)
  if (length(guarded) && isTRUE(check)) {
    .dr_check_mixing(x, keep, guarded)
  }

  # -- aggregate -------------------------------------------------------------
  # Rename before summarising, for the reason dr_HL_length() gives: the all-NA
  # counter must read the PRE-aggregation column, and `n = sum(n)` in one
  # summarise() is resolved differently by the two backends. Distinct names
  # make them agree by construction rather than by luck.
  raw <- paste0(".raw_", measures)
  out <- dplyr::mutate(x, !!!rlang::set_names(
    lapply(measures, function(m) rlang::sym(m)), raw))

  sums <- rlang::set_names(
    lapply(raw, function(r) rlang::expr(sum(!!rlang::sym(r), na.rm = TRUE))),
    measures)
  oks <- rlang::set_names(
    lapply(raw, function(r) {
      rlang::expr(sum(as.integer(!is.na(!!rlang::sym(r))), na.rm = TRUE))
    }),
    paste0(".ok_", measures))

  out <- out |>
    dplyr::group_by(!!!rlang::syms(keep)) |>
    dplyr::summarise(!!!sums, !!!oks, .groups = "drop")

  # Restore NA where the group had nothing to sum. This is the 0-in-R /
  # NULL-in-SQL divergence, and for n_measured it is also the DataType == "C"
  # rule: .id is retained, so a group is all-"C" or none.
  restores <- rlang::set_names(
    lapply(measures, function(m) {
      rlang::expr(dplyr::if_else(!!rlang::sym(paste0(".ok_", m)) == 0,
                                 NA_real_, as.numeric(!!rlang::sym(m))))
    }),
    measures)

  out |>
    dplyr::mutate(!!!restores) |>
    dplyr::select(dplyr::all_of(setdiff(nm, collapse)))
}


# Does any output group actually mix a guarded dimension? Counting distinct
# values needs an NA-safe surrogate: n_distinct() counts NA as a level in R
# while COUNT(DISTINCT) ignores NULL in SQL, and LengthType is NA on 70.74% of
# HL_length -- so the two backends would disagree on exactly the rows that
# matter. Coalescing to a sentinel string first makes them agree.
.dr_check_mixing <- function(x, keep, guarded) {
  counts <- rlang::set_names(
    lapply(guarded, function(g) {
      rlang::expr(dplyr::n_distinct(dplyr::coalesce(
        as.character(!!rlang::sym(g)), "<NA>")))
    }),
    paste0(".nd_", guarded))

  nd <- paste0(".nd_", guarded)
  mixed <- x |>
    dplyr::group_by(!!!rlang::syms(keep)) |>
    dplyr::summarise(!!!counts, .groups = "drop") |>
    dplyr::filter(!!Reduce(function(a, b) rlang::expr(!!a | !!b),
                           lapply(nd, function(n) {
                             rlang::expr(!!rlang::sym(n) > 1)
                           }))) |>
    # collect(n = ) rather than head(): it pushes a LIMIT down on the lazy
    # path and needs no utils:: import. We only ever print one row, but take a
    # few so the "which field mixed" test below sees more than one group.
    dplyr::collect(n = 5)

  if (!nrow(mixed)) return(invisible(TRUE))

  which_mixed <- guarded[vapply(nd, function(n) any(mixed[[n]] > 1), logical(1))]
  # Say why for the field that actually mixed, not for both.
  why <- c(
    accuracy = paste("two records at the same length_mm measured to 1 cm and",
                     "to 5 cm are different bins"),
    LengthType = paste("LengthType mixes total against standard length, so the",
                       "two records are not measurements of the same thing")
  )[which_mixed]
  stop("Cannot collapse ", paste(sQuote(which_mixed), collapse = " / "),
       ": the data mixes ", if (length(which_mixed) > 1) "them" else "it",
       " within at least one output group, so summing would invent a count ",
       "for a bin nobody measured -- ",
       paste(why, collapse = "; and "), ". One offending group:\n  ",
       .dr_fmt_row(mixed[1, , drop = FALSE]),
       "\nFilter to one convention first, or pass check = FALSE if you have ",
       "established homogeneity another way.", call. = FALSE)
}


# One row as "col=value, col=value", for the mixing error above. Avoids
# utils::capture.output(), which would pull utils into Imports for one line.
.dr_fmt_row <- function(row) {
  paste(paste0(names(row), "=", vapply(row, function(v) {
    as.character(v)[1]
  }, character(1))), collapse = ", ")
}
