# Download and Import DATRAS Data

This function streamlines the retrieval of DATRAS trawl survey data from
various sources, offering distinct methods for fetching and loading the
data:

- `"old"`: Retrieves data using the legacy
  [`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
  function.

- `"new"`:

- `"parquet"`: Reads directly from Parquet files via URL. survey, year,
  and quarter filter not applied.

## Usage

``` r
dr_get(
  recordtype,
  surveys = NULL,
  years = 1965:2030,
  quarters = 1:4,
  from = "parquet",
  quiet = TRUE
)
```

## Arguments

- recordtype:

  A string specifying the record type ("HH", "HL", or "CA"), indicating
  the data structure to retrieve.

- surveys:

  A character vector of survey IDs. Defaults to all ICES-recognized
  surveys, excluding "Test-DATRAS".

- years:

  An integer vector of years (e.g., `1965:2030`). Values outside the
  range `[1965, current year]` are invalid.

- quarters:

  An integer vector (e.g., `1:4`) representing quarter ranges.

- from:

  String (default 'parquet') specifying the data source: `"old"`,
  `"new"`, or `"parquet"`.

- quiet:

  Logical; suppresses progress messages if `TRUE` (default).

## Value

A data frame containing DATRAS data filtered by the specified parameters
if from is 'old' or 'new'.

## Details

Year and quarter ranges must be specified, and datasets are filtered
accordingly. Surveys supported by ICES can be automatically retrieved if
unspecified.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Download haul-level data (new API)
  dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, quarters = c(1, 3), from = "new")

  # Read full dataset
  dr_get("HL")
} # }
```
