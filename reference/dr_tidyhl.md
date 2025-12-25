# Tidy DATRAS length (HL) data

Cleans and formats length (HL) data, removing records with missing
length class or numbers, converting length units, applying subfactors,
and finalizing aphia codes.

## Usage

``` r
dr_tidyhl(d, trim = TRUE)
```

## Arguments

- d:

  A duckdb-table connection or a tibble containing HL data.

- trim:

  Boolean (default TRUE) remove haul data

## Value

A duckdb-table connection or a tibble with tidied HL data.
