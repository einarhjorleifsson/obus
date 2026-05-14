# Run all applicable QC checks and return a combined report

A convenience wrapper that runs
[`dr_check_sentinels()`](dr_check_sentinels.md),
[`dr_check_subfactor()`](dr_check_subfactor.md), and
[`dr_check_totalno()`](dr_check_totalno.md) on the supplied tables and
binds the results into a single report tibble.

## Usage

``` r
dr_check_all(hh = NULL, hl = NULL, ca = NULL, ...)
```

## Arguments

- hh:

  HH exchange table, or `NULL`.

- hl:

  HL exchange table (with `DataType` joined in), or `NULL`.

- ca:

  CA exchange table, or `NULL`.

- ...:

  Additional arguments passed to individual check functions (e.g., `tol`
  for [`dr_check_totalno()`](dr_check_totalno.md)).

## Value

A tibble with one row per check, columns `check`, `table`, `n_fail`,
`n_total`, `pct_fail`, `detail`.

## Details

Supply whichever tables you have. Checks that require a table you have
not supplied are silently skipped.

`DataType` must be present in `hl` for the HL arithmetic checks. If your
HL table does not yet contain `DataType`, join it from HH first:

    hl <- hl |> dplyr::left_join(hh |> dplyr::select(.id, DataType), by = ".id")
