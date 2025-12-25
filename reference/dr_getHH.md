# Retrieve DATRAS Station (HH) Table

Retrieve DATRAS station (HH) data for a given survey, year(s), and
quarter(s). This function is a wrapper around
`icesDatras::getDATRAS(record = "HH", ...)` that ensures variable types
are properly set.

## Usage

``` r
dr_getHH(survey, years, quarters, quiet = TRUE)
```

## Arguments

- survey:

  A character string, the survey acronym (e.g., `"NS-IBTS"`).

- years:

  An integer vector of years (e.g., `2010` or `2005:2010`).

- quarters:

  An integer vector of quarters (1, 2, 3, or 4).

- quiet:

  Logical; if `TRUE` (default), suppress messages.

## Value

A tibble with station data or an empty tibble if no data is available.
