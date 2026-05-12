# Connect to Raw ICES DATRAS Tables

Opens a lazy DuckDB connection to "as-is" DATRAS parquet files — the raw
tables as downloaded from the ICES datacenter, with original old-style
column names (e.g. `Ship`, `HaulNo`, `ShootLat`). Use this when you need
unmodified ICES output rather than the tidied versions provided by
[`dr_con()`](dr_con.md).

## Usage

``` r
dr_con_raw(table = "HH")
```

## Arguments

- table:

  A character string specifying the table. One of `"HH"` (default),
  `"HL"`, `"CA"`, `"FL"`, `"LT"`, `"CPUEL"`, `"CPUEA"`, `"CW"`, or
  `"IDX"`.

## Value

A lazy `duckdbfs` tibble. Pipe dplyr verbs and call
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html)
to bring data into memory.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con_raw("FL") |> dplyr::glimpse()

  dr_con_raw("FL") |>
    dplyr::filter(Survey == "NS-IBTS", Year == 2020) |>
    dplyr::collect()
} # }
```
