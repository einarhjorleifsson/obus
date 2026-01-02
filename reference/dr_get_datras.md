# Retrieve DATRAS exchange table

This function combines the functionality of dr_get_HH, dr_get_HL,
dr_get_CA and dr_get_FL. It supports querying many surveys, years and
quarters in one function call.

## Usage

``` r
dr_get_datras(type, survey, years = NULL, quarters = NULL, quiet = TRUE)
```

## Arguments

- type:

  A character string, the DATRAS exchange table type (e.g., "HH").

- survey:

  A character string, the survey acronym (e.g., `"NS-IBTS"`).

- years:

  An integer vector of years (e.g., `2010` or `2005:2010`).

- quarters:

  An integer vector of quarters (1, 2, 3, or 4).

- quiet:

  Logical; if `TRUE` (default), suppress messages.

## Value

A tibble with exchange data or an empty tibble if no data is available.

## Details

This function is a wrapper around
[`icesDatras::getDATRAS()`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
that ensures variable types are properly set.
