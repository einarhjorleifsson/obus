# Download and Import DATRAS Data

Retrieves DATRAS trawl survey data from various sources:

- `"parquet"`: Reads the full dataset from URL-hosted Parquet files (no
  survey/year/quarter filtering).

- `"old"`: Retrieves data via the legacy
  [`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
  function.

- `"new"`: Retrieves data via
  `icesDatras::get_datras_unaggregated_data`.

## Usage

``` r
dr_get(
  recordtype,
  surveys = NULL,
  years = 1965:2030,
  quarters = 1:4,
  aphia = NULL,
  from = "parquet",
  quiet = TRUE
)
```

## Arguments

- recordtype:

  A string specifying the record type: `"HH"`, `"HL"`, `"CA"`, `"FL"`
  (flex file), `"LT"` (litter assessment), `"CPUEL"` (CPUE per length
  per haul per hour), `"CPUEA"` (CPUE per age per haul per hour), `"CW"`
  (catch weight by species and haul), or `"IDX"` (age-based survey
  indices).

- surveys:

  A character vector of survey IDs. If `NULL` (default), all ICES
  surveys excluding test surveys are used (via
  [`icesDatras::getSurveyList()`](https://rdrr.io/pkg/icesDatras/man/getSurveyList.html)).

- years:

  An integer vector of years (e.g. `1965:2030`).

- quarters:

  An integer vector of quarters (e.g. `1:4`).

- aphia:

  An integer vector of WoRMS Aphia species codes. Used by `"CW"` and
  `"IDX"`. If `NULL`, defaults to cod (126436), haddock (126437), and
  herring (126417).

- from:

  String specifying the data source for HH/HL/CA: `"parquet"` (default),
  `"old"`, or `"new"`. Ignored when `recordtype = "FL"`.

- quiet:

  Logical; suppresses progress messages if `TRUE` (default).

## Value

A data frame.

## Details

For `recordtype = "FL"` (flex file),
[`icesDatras::getFlexFile`](https://rdrr.io/pkg/icesDatras/man/getFlexFile.html)
is called for every combination of survey, year, and quarter; the `from`
argument is ignored.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_get("HH")                                                      # full parquet
  dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, from = "new")
  dr_get("FL", surveys = "NS-IBTS", years = 2020:2023, quarters = 1)
} # }
```
