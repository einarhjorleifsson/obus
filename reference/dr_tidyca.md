# Tidy DATRAS age (CA) data

Cleans and formats age (CA) data, converting length units, setting
weights, and finalizing aphia codes.

## Usage

``` r
dr_tidyca(d, trim = TRUE)
```

## Arguments

- d:

  A duckdb-table connection or a tibble containing CA data.

- trim:

  Boolean (default TRUE) remove haul data

## Value

A duckdb-table connection or a tibble with tidied CA data.
