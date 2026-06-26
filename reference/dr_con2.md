# Connect to DATRAS Parquet Files

Opens a lazy DuckDB connection to a DATRAS parquet file hosted on the
obus server. An HTTP HEAD request is made before opening the dataset to
give a clear error if the file is absent or the server is unreachable.

## Usage

``` r
dr_con2(
  type,
  url = "https://heima.hafro.is/~einarhj/datras",
  trim = TRUE,
  quiet = TRUE
)
```

## Arguments

- type:

  A character string specifying the table. One of `"HH"`, `"HL2"`,
  `"CA2"`.

- url:

  Base URL of the parquet directory.

- trim:

  Logical. If `TRUE` (default), returns only essential columns

- quiet:

  Logical. If `TRUE` (default), suppresses messages.

## Value

A lazy `tbl_duckdb_connection`. Pipe dplyr verbs and call
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html)
to bring data into memory.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con2("HL2")
  dr_con2("HL2", trim = FALSE)
} # }
```
