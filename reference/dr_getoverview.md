# Summarize Data Availability

Retrieve a table of available DATRAS survey-year-quarter combinations.
This function is a wrapper around
[`icesDatras::getDatrasDataOverview`](https://rdrr.io/pkg/icesDatras/man/getDatrasDataOverview.html),
returning a tibble rather than a list of matrices.

## Usage

``` r
dr_getoverview(surveys = NULL)
```

## Arguments

- surveys:

  A character vector of survey names to process, or `NULL` to process
  all surveys.

## Value

A tibble with columns `survey`, `year`, and `quarter` for available
data.
