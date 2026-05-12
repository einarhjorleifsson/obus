#' Set column types from the dr_lookup_fields specification
#'
#' Coerces columns in a DATRAS exchange table to the types specified in
#' [dr_lookup_fields]. Also replaces literal `"NA"` strings with real `NA`
#' before coercion.
#'
#' @param d A data frame or `tbl_lazy` (DATRAS exchange table).
#' @param name_col `"new"` (default) to match new-style column names as
#'   returned by `get_datras_unaggregated_data` / parquet; `"old"` to match
#'   old-style names as returned by `getDATRAS` and derived products.
#' @param recordheader If not `NULL`, restrict the lookup to a single record
#'   type (e.g. `"HH"`, `"CPUEL"`). `NULL` borrows types from all tables.
#'
#' @return An object of the same class as `d`.
#' @export

dr_settypes <- function(d, name_col = "new", recordheader = NULL) {
  fields <- dr_lookup_fields
  if (!is.null(recordheader))
    fields <- dplyr::filter(fields, table == recordheader)
  fields <- tidyr::drop_na(fields, dplyr::all_of(name_col))

  key_chr <- fields |> dplyr::filter(format == "chr") |> dplyr::pull(dplyr::all_of(name_col)) |> unique()
  key_int <- fields |> dplyr::filter(format == "int") |> dplyr::pull(dplyr::all_of(name_col)) |> unique()
  key_dbl <- fields |> dplyr::filter(format == "dbl") |> dplyr::pull(dplyr::all_of(name_col)) |> unique()

  d |>
    dplyr::mutate(dplyr::across(dplyr::where(is.character), \(x) dplyr::na_if(x, "NA"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_chr), as.character)) |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_int), as.integer))   |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_dbl), as.numeric))
}
