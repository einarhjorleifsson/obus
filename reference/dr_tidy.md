# Tidy DATRAS data

Cleans and formats a DATRAS data table by dispatching to table-specific
tidying functions. For station tables (HH), optionally returns only
valid hauls (`haulval == "V"`).

## Usage

``` r
dr_tidy(d, valid_hauls = TRUE)
```

## Arguments

- d:

  A duckdb-table connection or a tibble containing DATRAS data.

- valid_hauls:

  Logical; if `TRUE` (default), only records with `haulval == "V"` are
  retained in station tables (HH).

## Value

A duckdb-table connection or a tibble with tidied DATRAS data.
