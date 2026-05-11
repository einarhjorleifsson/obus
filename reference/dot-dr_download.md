# Download and process DATRAS data to parquet files

Downloads raw HH, HL, and CA records from the DATRAS API, applies
standard tidying and transformations, and writes the results as parquet
files. Processed data is written to `<path>/`. Optionally, unprocessed
data can also be saved to `<path>/raw/`.

## Usage

``` r
.dr_download(path, save_raw = FALSE)
```

## Arguments

- path:

  Character. Base directory where parquet files will be written.

- save_raw:

  Logical. If `TRUE`, saves the unprocessed data to `<path>/raw/` before
  tidying. Default is `FALSE`.

## Value

Invisibly returns `NULL`. Called for its side effects.
