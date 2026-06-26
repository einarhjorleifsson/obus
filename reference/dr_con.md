# Connect to DATRAS Parquet Files

Opens a lazy DuckDB connection to a DATRAS parquet file hosted on the
obus server. An HTTP HEAD request is made before opening the dataset to
give a clear error if the file is absent or the server is unreachable.

## Usage

``` r
dr_con(type, url = "https://heima.hafro.is/~einarhj/datras", quiet = TRUE)
```

## Arguments

- type:

  A character string specifying the table. One of `"HH"`, `"HL"`,
  `"CA"`, `"FL"`, `"LT"`, `"CPUEL"`, `"CPUEA"`, `"CW"`, `"IDX"`,
  `"species"`, `"by_length"` (CPUE per length class per haul, from
  [`.dr_cpue_by_length()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_cpue_by_length.md)),
  or `"by_haul"` (haul-level catch totals, from
  [`.dr_cpue_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_cpue_by_haul.md)).

- url:

  Base URL of the parquet directory.

- quiet:

  Logical. If `TRUE` (default), suppresses messages.

## Value

A lazy `tbl_duckdb_connection`. Pipe dplyr verbs and call
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html)
to bring data into memory.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con("HH")
  dr_con("HL") |> dplyr::filter(Survey == "NS-IBTS", Year == 2023) |> dplyr::collect()
} # }
```
