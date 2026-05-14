# Quality control functions for DATRAS exchange data.
#
# All dr_check_* functions:
#   - Accept a collected data frame (or tbl_duckdb_connection that is collected
#     internally where group-level aggregation is required).
#   - Default (flag = FALSE): return a one-row tibble with columns:
#       check    <chr>  name of the check
#       table    <chr>  which table was inspected
#       n_fail   <int>  number of failing rows / groups
#       n_total  <int>  total rows / groups evaluated
#       pct_fail <dbl>  percentage failing
#       detail   <chr>  human-readable breakdown of failures
#   - flag = TRUE: return the input data with a logical column `.pass` added.
#       TRUE  = passes the check
#       FALSE = fails the check
#       NA    = not evaluated by this check (e.g. DataType not R/S/C)
#   - Never stop() on failure; they report, they do not throw.
#
# Column name defaults follow the OLD-style names (as returned by dr_get() /
# dr_con_raw()), which is the primary fetch path for HH and HL exchange data.
# Pass new-style names explicitly when working on translated tables.


# Internal helper: collect DuckDB tables silently before row-level work --------
.dr_maybe_collect <- function(d) {
  if (inherits(d, "tbl_duckdb_connection")) dplyr::collect(d) else d
}

# Internal helper: build a standard one-row result tibble ----------------------
.dr_result <- function(check, table, n_fail, n_total, detail) {
  tibble::tibble(
    check    = check,
    table    = table,
    n_fail   = as.integer(n_fail),
    n_total  = as.integer(n_total),
    pct_fail = if (n_total == 0L) NA_real_ else round(100 * n_fail / n_total, 1),
    detail   = as.character(detail)
  )
}


# -----------------------------------------------------------------------------
#' Check SubsamplingFactor constraints against DataType
#'
#' DATRAS requires:
#' - DataType **R**: `SubFactor >= 1`
#' - DataType **S**: `SubFactor > 1` (strictly)
#' - DataType **C**: `SubFactor == 1`
#'
#' Violations silently corrupt `n_haul` computed by [dr_add_n_and_cpue()].
#'
#' @param hl HL exchange table. Must contain `DataType` and `SubFactor`
#'   (or the column names supplied via `DataType` / `SubFactor`).
#'   If `DataType` is absent, join HH before calling this function.
#' @param DataType Unquoted column name for the data type field.
#'   Default: `DataType` (old-style).
#' @param SubFactor Unquoted column name for the subsampling factor.
#'   Default: `SubFactor` (old-style). Use `SubsamplingFactor` for new-style.
#' @param flag Logical. If `FALSE` (default) return a one-row summary tibble.
#'   If `TRUE` return the input data with a `.pass` column added (`TRUE` =
#'   passes, `FALSE` = fails, `NA` = DataType not R/S/C, not evaluated).
#'
#' @return A one-row summary tibble, or the input data with `.pass` added.
#' @export
dr_check_subfactor <- function(hl,
                               DataType  = DataType,
                               SubFactor = SubFactor,
                               flag      = FALSE) {

  dt_col <- rlang::as_name(rlang::enquo(DataType))
  sf_col <- rlang::as_name(rlang::enquo(SubFactor))

  required <- c(dt_col, sf_col)
  missing  <- setdiff(required, colnames(hl))
  if (length(missing) > 0)
    stop("dr_check_subfactor: missing columns: ", paste(missing, collapse = ", "))

  hl <- .dr_maybe_collect(hl)

  # Compute per-row pass flag
  # NA = DataType not R/S/C (not evaluated by this check)
  hl <- hl |>
    dplyr::mutate(
      .pass = dplyr::case_when(
        is.na(.data[[dt_col]])                                      ~ NA,
        !(.data[[dt_col]] %in% c("R", "S", "C"))                   ~ NA,
        is.na(.data[[sf_col]])                                      ~ FALSE,
        .data[[dt_col]] == "R" & .data[[sf_col]] >= 1              ~ TRUE,
        .data[[dt_col]] == "S" & .data[[sf_col]] >  1              ~ TRUE,
        .data[[dt_col]] == "C" & .data[[sf_col]] == 1              ~ TRUE,
        TRUE                                                        ~ FALSE
      )
    )

  if (flag) return(hl)

  # --- Summary mode ---
  d_eval  <- dplyr::filter(hl, !is.na(.pass))
  n_total <- nrow(d_eval)
  n_fail  <- sum(!d_eval$.pass, na.rm = TRUE)

  detail_tbl <- d_eval |>
    dplyr::filter(!.pass) |>
    dplyr::count(.data[[dt_col]], name = "n") |>
    dplyr::mutate(s = paste0(.data[[dt_col]], ":", n)) |>
    dplyr::pull(s)

  detail <- if (n_fail == 0L) "all pass" else paste(detail_tbl, collapse = "; ")

  hl |>
    dplyr::select(-.pass) |>  # clean up before returning summary
    invisible()

  .dr_result("subfactor", "HL", n_fail, n_total, detail)
}


# -----------------------------------------------------------------------------
#' Check TotalNo arithmetic against DataType rules
#'
#' For each (`.id`, species, sex, `CatIdentifier`) group:
#' - DataType **R** or **S**: `TotalNo ~= sum(HLNoAtLngt) * SubFactor`
#' - DataType **C**:          `TotalNo ~= sum(HLNoAtLngt)`
#'
#' A tolerance of `tol` fish is applied to allow for rounding in submissions.
#' Groups with `NA` in `TotalNo`, `SubFactor`, or `HLNoAtLngt` are skipped
#' (counted separately in the detail string).
#'
#' @param hl HL exchange table. Must contain `DataType`, `TotalNo`, `SubFactor`,
#'   `HLNoAtLngt`, `.id`, and the grouping fields `Valid_Aphia`, `Sex`,
#'   `CatIdentifier` (or the column names supplied below). Join HH for
#'   `DataType` if it is not present.
#' @param DataType,TotalNo,SubFactor,HLNoAtLngt,Species,Sex,CatIdentifier
#'   Unquoted column names. Old-style defaults shown. New-style equivalents:
#'   `TotalNumber`, `SubsamplingFactor`, `NumberAtLength`, `ValidAphiaID`,
#'   `IndividualSex`, `SpeciesCategory`.
#' @param tol Numeric tolerance in number of fish. Default `0.5`.
#' @param flag Logical. If `FALSE` (default) return a one-row summary tibble.
#'   If `TRUE` return the input data with a `.pass` column added (`TRUE` =
#'   group passes, `FALSE` = group fails, `NA` = group not evaluated).
#'
#' @return A one-row summary tibble, or the input data with `.pass` added.
#' @export
dr_check_totalno <- function(hl,
                             DataType      = DataType,
                             TotalNo       = TotalNo,
                             SubFactor     = SubFactor,
                             HLNoAtLngt   = HLNoAtLngt,
                             Species       = Valid_Aphia,
                             Sex           = Sex,
                             CatIdentifier = CatIdentifier,
                             tol           = 0.5,
                             flag          = FALSE) {

  dt_col  <- rlang::as_name(rlang::enquo(DataType))
  tn_col  <- rlang::as_name(rlang::enquo(TotalNo))
  sf_col  <- rlang::as_name(rlang::enquo(SubFactor))
  nl_col  <- rlang::as_name(rlang::enquo(HLNoAtLngt))
  sp_col  <- rlang::as_name(rlang::enquo(Species))
  sx_col  <- rlang::as_name(rlang::enquo(Sex))
  cat_col <- rlang::as_name(rlang::enquo(CatIdentifier))

  required <- c(".id", dt_col, tn_col, sf_col, nl_col, sp_col, sx_col, cat_col)
  missing  <- setdiff(required, colnames(hl))
  if (length(missing) > 0)
    stop("dr_check_totalno: missing columns: ", paste(missing, collapse = ", "))

  hl <- .dr_maybe_collect(hl)

  # Group-level summary. Restrict to R/S/C rows only (ignore -9/NA DataType --
  # those are handled by dr_check_subfactor and dr_add_n_and_cpue's NA path).
  grp_keys <- c(".id", sp_col, sx_col, cat_col, dt_col)

  d <- hl |>
    dplyr::filter({{ DataType }} %in% c("R", "S", "C")) |>
    dplyr::group_by(.id,
                    .sp  = {{ Species }},
                    .sx  = {{ Sex }},
                    .cat = {{ CatIdentifier }},
                    .dt  = {{ DataType }}) |>
    dplyr::summarise(
      .tn      = dplyr::first({{ TotalNo }}),
      .sf      = dplyr::first({{ SubFactor }}),
      .sum     = sum({{ HLNoAtLngt }}, na.rm = TRUE),
      .has_len = any(!is.na({{ HLNoAtLngt }})),
      .na      = any(is.na({{ TotalNo }}) | is.na({{ SubFactor }})),
      .groups  = "drop"
    ) |>
    # Restrict to groups with at least one length measurement; groups where
    # HLNoAtLngt is entirely NA are counted/weighed catches without length
    # data (record_type 12/11) and the arithmetic rule does not apply.
    dplyr::filter(.has_len)

  n_total <- nrow(d)
  n_na    <- sum(d$.na, na.rm = TRUE)

  d_eval <- d |>
    dplyr::filter(!.na) |>
    dplyr::mutate(
      .expected = dplyr::if_else(.dt == "C", .sum, .sum * .sf),
      .pass     = abs(.tn - .expected) <= tol
    )

  n_fail <- sum(!d_eval$.pass, na.rm = TRUE)

  if (flag) {
    # Build a group-level pass flag and join back to every row in hl.
    # Groups that were skipped (no length data, NA fields, or DataType not
    # R/S/C) receive NA -- not evaluated.
    pass_tbl <- d_eval |>
      dplyr::select(.id, .sp, .sx, .cat, .dt, .pass) |>
      dplyr::rename(
        !!sp_col  := .sp,
        !!sx_col  := .sx,
        !!cat_col := .cat,
        !!dt_col  := .dt
      )

    return(dplyr::left_join(hl, pass_tbl, by = grp_keys))
  }

  # --- Summary mode ---
  fail_by_dt <- d_eval |>
    dplyr::filter(!.pass) |>
    dplyr::count(.dt, name = "n") |>
    dplyr::mutate(s = paste0(.dt, ":", n)) |>
    dplyr::pull(s)

  detail_parts <- character(0)
  if (n_fail > 0)  detail_parts <- c(detail_parts, paste(fail_by_dt, collapse = "; "))
  if (n_na   > 0)  detail_parts <- c(detail_parts, paste0("skipped (NA fields): ", n_na))
  detail <- if (length(detail_parts) == 0) "all pass" else paste(detail_parts, collapse = " | ")

  .dr_result("totalno", "HL", n_fail, n_total, detail)
}


# -----------------------------------------------------------------------------
#' Check for -9 sentinel values remaining in numeric columns
#'
#' In raw DATRAS exchange data, `-9` represents a missing/inapplicable field.
#' obus fetchers replace `-9` with `NA` after download. This function scans all
#' numeric and integer columns for any surviving `-9` values, which would
#' indicate that the replacement step was bypassed or a new fetcher path is
#' missing it.
#'
#' Safe to run on any DATRAS table (HH, HL, CA, etc.) or any data frame.
#'
#' @param d A data frame or `tbl_duckdb_connection`.
#' @param table_label Label for the `table` column in the result.
#'   Defaults to the name of `d`.
#' @param flag Logical. If `FALSE` (default) return a one-row summary tibble.
#'   If `TRUE` return the input data with a `.pass` column added (`TRUE` = no
#'   `-9` in any numeric column on that row, `FALSE` = at least one hit).
#'
#' @return A one-row summary tibble, or the input data with `.pass` added.
#' @export
dr_check_sentinels <- function(d, table_label = NULL, flag = FALSE) {

  if (is.null(table_label))
    table_label <- deparse(substitute(d))

  d <- .dr_maybe_collect(d)

  num_cols <- names(d)[vapply(d, function(x) is.numeric(x) || is.integer(x), logical(1))]

  if (length(num_cols) == 0L) {
    if (flag) return(dplyr::mutate(d, .pass = TRUE))
    return(.dr_result("sentinels", table_label, 0L, nrow(d),
                      "no numeric columns to check"))
  }

  # Per-row: any numeric column == -9?
  row_fail <- rowSums(
    vapply(num_cols, function(col) d[[col]] == -9L & !is.na(d[[col]]), logical(nrow(d)))
  ) > 0L

  if (flag) return(dplyr::mutate(d, .pass = !row_fail))

  # --- Summary mode ---
  hits <- vapply(num_cols, function(col) sum(d[[col]] == -9L, na.rm = TRUE), integer(1))
  hits <- hits[hits > 0L]

  n_fail  <- sum(hits)
  n_total <- nrow(d) * length(num_cols)  # cells checked

  detail <- if (length(hits) == 0L) {
    "all pass"
  } else {
    paste(paste0(names(hits), ":", hits), collapse = "; ")
  }

  .dr_result("sentinels", table_label, n_fail, n_total, detail)
}


# -----------------------------------------------------------------------------
#' Run all applicable QC checks and return a combined report
#'
#' A convenience wrapper that runs [dr_check_sentinels()],
#' [dr_check_subfactor()], and [dr_check_totalno()] on the supplied tables and
#' binds the results into a single report tibble.
#'
#' Supply whichever tables you have. Checks that require a table you have not
#' supplied are silently skipped.
#'
#' `DataType` must be present in `hl` for the HL arithmetic checks. If your HL
#' table does not yet contain `DataType`, join it from HH first:
#' ```r
#' hl <- hl |> dplyr::left_join(hh |> dplyr::select(.id, DataType), by = ".id")
#' ```
#'
#' @param hh HH exchange table, or `NULL`.
#' @param hl HL exchange table (with `DataType` joined in), or `NULL`.
#' @param ca CA exchange table, or `NULL`.
#' @param ... Additional arguments passed to individual check functions
#'   (e.g., `tol` for [dr_check_totalno()]).
#'
#' @return A tibble with one row per check, columns `check`, `table`,
#'   `n_fail`, `n_total`, `pct_fail`, `detail`.
#' @export
dr_check_all <- function(hh = NULL, hl = NULL, ca = NULL, ...) {

  results <- list()

  # --- Sentinel checks -------------------------------------------------------
  if (!is.null(hh)) results[["hh_sentinel"]] <- dr_check_sentinels(hh, "HH")
  if (!is.null(hl)) results[["hl_sentinel"]] <- dr_check_sentinels(hl, "HL")
  if (!is.null(ca)) results[["ca_sentinel"]] <- dr_check_sentinels(ca, "CA")

  # --- HL arithmetic checks --------------------------------------------------
  if (!is.null(hl)) {
    has_dt <- "DataType" %in% colnames(hl)

    if (!has_dt) {
      message("dr_check_all: 'DataType' not in HL -- skipping subfactor and totalno checks.\n",
              "  Join HH first: hl |> left_join(hh |> select(.id, DataType), by = '.id')")
    } else {
      # Collect once for both HL checks to avoid double-fetching
      hl_df <- .dr_maybe_collect(hl)
      results[["hl_subfactor"]] <- dr_check_subfactor(hl_df, ...)
      results[["hl_totalno"]]   <- dr_check_totalno(hl_df, ...)
    }
  }

  dplyr::bind_rows(results)
}
