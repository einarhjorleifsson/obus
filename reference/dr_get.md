# Download and Import DATRAS Data

Retrieves DATRAS trawl survey data from two sources:

- `"parquet"`: Reads from URL-hosted Parquet files, filtered by
  `surveys`, `years`, and `quarters` before download. Returns standard
  column names directly.

- `"xml"`: Retrieves data via the legacy
  [`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
  function. Legacy column names are translated to standard names before
  returning.

## Usage

``` r
dr_get(
  recordtype,
  surveys = NULL,
  years = 1965:2030,
  quarters = 1:4,
  aphia = NULL,
  source = "parquet",
  dictionary = NULL,
  quiet = TRUE
)
```

## Arguments

- recordtype:

  A string specifying the record type: `"HH"`, `"HL"`, `"CA"`, `"FL"`
  (flex file), `"LT"` (litter assessment), `"CPUEL"` (CPUE per length
  per haul per hour), `"CPUEA"` (CPUE per age per haul per hour), `"CW"`
  (catch weight by species and haul), `"IDX"` (age-based survey
  indices), or `"HL_standardised"` (pre-computed standardized HL table;
  parquet-only, see
  [`dr_HL_standardised`](https://einarhjorleifsson.github.io/obus/reference/dr_HL_standardised.md)).

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

- source:

  String specifying the data source for HH/HL/CA: `"parquet"` (default)
  or `"xml"`. Ignored for FL, LT, CPUEL, CPUEA, CW, IDX. Must be
  `"parquet"` for `"HL_standardised"`.

- dictionary:

  A data frame with columns `old` and `new` used to translate legacy
  ICES column names to standard names. If `NULL` (default), built
  automatically from
  [dr_lookup_fields](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_fields.md).

- quiet:

  Logical; suppresses progress messages if `TRUE` (default).

## Value

A data frame with standard column names.

## Details

All other record types (FL, LT, CPUEL, CPUEA, CW, IDX) always use their
dedicated ICES API functions; the `source` argument is ignored for
these. Their legacy column names are translated to standard names before
returning.

`"HL_standardised"` is an obus-derived product (the output of
[`dr_HL_standardised`](https://einarhjorleifsson.github.io/obus/reference/dr_HL_standardised.md),
pre-computed and hosted as a parquet file) rather than a raw ICES record
type. It is parquet-only; there is no `"xml"` source for it.

Translation is performed by
[`dr_translate()`](https://einarhjorleifsson.github.io/obus/reference/dr_translate.md)
using the `dictionary` argument. Supply a custom data frame with columns
`old` and `new` to override the default mapping built from
[dr_lookup_fields](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_fields.md).

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_get("HH")                                                        # full parquet
  dr_get("HH", surveys = "NS-IBTS", years = 2020:2023, source = "xml")
  dr_get("FL", surveys = "NS-IBTS", years = 2020:2023, quarters = 1)
} # }
```
