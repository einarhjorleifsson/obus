# Download unaggregated DATRAS survey data

Downloads unaggregated haul- and biological-level data from the ICES
DATRAS Download API. \#' @author Vaishav Soni, International Council for
the Exploration of the Sea (ICES)

## Usage

``` r
get_datras_unaggregated_data(recordtype, survey, year, quarter)
```

## Arguments

- recordtype:

  Character. One of `"HH"`, `"HL"`, or `"CA"`.

- survey:

  Character. Survey acronym (e.g. `"NS-IBTS"`).

- year:

  Character. Year or range (e.g. `"2020"` or `"1965:2025"`).

- quarter:

  Character. Quarter or range (e.g. `"1"` or `"1:4"`).

## Value

A `data.table` containing the requested DATRAS data.

## Details

The function downloads a zipped CSV file from the official ICES DATRAS
API, extracts it locally, and reads it using fixed column classes to
avoid costly type guessing.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- get_datras_unaggregated_data(
  recordtype = "HH",
  survey = "NS-IBTS",
  year = "1965:2025",
  quarter = "1:4"
)
} # }
```
