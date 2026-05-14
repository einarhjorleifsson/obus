# Check for -9 sentinel values remaining in numeric columns

In raw DATRAS exchange data, `-9` represents a missing/inapplicable
field. obus fetchers replace `-9` with `NA` after download. This
function scans all numeric and integer columns for any surviving `-9`
values, which would indicate that the replacement step was bypassed or a
new fetcher path is missing it.

## Usage

``` r
dr_check_sentinels(d, table_label = NULL, flag = FALSE)
```

## Arguments

- d:

  A data frame or `tbl_duckdb_connection`.

- table_label:

  Label for the `table` column in the result. Defaults to the name of
  `d`.

- flag:

  Logical. If `FALSE` (default) return a one-row summary tibble. If
  `TRUE` return the input data with a `.pass` column added (`TRUE` = no
  `-9` in any numeric column on that row, `FALSE` = at least one hit).

## Value

A one-row summary tibble, or the input data with `.pass` added.

## Details

Safe to run on any DATRAS table (HH, HL, CA, etc.) or any data frame.
