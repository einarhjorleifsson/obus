# Download and read DATRAS data, single-year or contiguous year-range only

Accepts either a single year (e.g. 1988) or a contiguous range of years
specified as:

- a single integer (e.g. 1988)

- a single "start:end" style string (e.g. "1988:2025")

- or a numeric vector that is contiguous (e.g. 1988:2025)

## Usage

``` r
get_datras_table_base(
  recordtype,
  survey,
  year,
  quarter,
  timeout = 300,
  verbose = TRUE,
  cache = TRUE,
  cache_dir = NULL,
  overwrite_cache = FALSE
)
```

## Arguments

- recordtype:

  character Record type (one of "HH", "HL", "CA"; case-insensitive).

- survey:

  character Survey short code (e.g. "NS-IBTS").

- year:

  integer\|numeric\|character Single year (e.g. 1988), or a contiguous
  range specified as "1988:2025" or 1988:2025.

- quarter:

  integer\|numeric\|character Single quarter (1-4), or a contiguous
  range specified as "1:4" or 1:4.

- timeout:

  numeric Timeout in seconds for downloads via options(timeout). Default
  300.

- verbose:

  logical Whether to print progress messages. Default TRUE.

- cache:

  logical Whether to cache results on disk. Default TRUE.

- cache_dir:

  character Optional directory for cache files. If NULL the default is
  ~/.datras_cache (or tempdir() if HOME not set).

- overwrite_cache:

  logical If TRUE, ignore an existing cache file and re-download (then
  update cache). Default FALSE.

## Value

A data.frame

## Details

Non-contiguous year lists (e.g. c(1988, 1990) or c("1988","1990")) are
not allowed and will produce an error.

Quarter accepts the same forms (single or contiguous range), but values
must be in 1:4.

The recordtype argument must be one of "HH", "HL", or "CA"
(case-insensitive).

This version always performs a single API request (using the DATRAS
range syntax when ranges are provided). The function supports simple
file-based caching across R sessions.
