# Tidy DATRAS station (HH) data

Filters and formats station (HH) data, optionally retaining only valid
hauls (`haulval == "V"`).

## Usage

``` r
dr_tidyhh(d, valid_hauls = TRUE)
```

## Arguments

- d:

  A duckdb-table connection or a tibble containing HH data.

- valid_hauls:

  Logical; if `TRUE` (default), only valid hauls are retained.

## Value

A duckdb-table connection or a tibble with tidied HH data.
