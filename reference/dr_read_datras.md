# Download, extract, and import DATRAS Data

This function automates the process of downloading, unzipping, and
importing DATRAS (ICES Database of Trawl Surveys) data into R. The year
and quarter parameters must be provided as single text strings
specifying ranges (e.g., `"2020:2025"` for years and `"1:4"` for
quarters). Temporary files are automatically cleaned up.

## Usage

``` r
dr_read_datras(
  recordtype,
  survey,
  year = 1965:2030,
  quarter = 1:4,
  quiet = TRUE,
  how = "data.table"
)
```

## Arguments

- recordtype:

  A character string indicating the record type ("HH", "HL", or "CA").

- survey:

  A single character string specifying the survey name.

- year:

  A single text string specifying the range of years as `"start:end"`
  (e.g., `"2020:2025"`).

- quarter:

  A single text string specifying the range of quarters as `"start:end"`
  (e.g., `"1:4"`).

- quiet:

  A logical value; if `FALSE`, progress messages are displayed.

- how:

  Text string, any of "parquet", "arrow" or "data.table"

## Value

A data frame containing the requested DATRAS data for the specified year
and quarter ranges.
