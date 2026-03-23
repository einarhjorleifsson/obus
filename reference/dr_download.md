# Download DATRAS parquet files

Downloads HH, HL, and CA parquet files

## Usage

``` r
dr_download(
  recordtype = c("HH", "HL", "CA"),
  url = "https://heima.hafro.is/~einarhj/datras",
  dest_directory = "data"
)
```

## Arguments

- recordtype:

  Character. Base directory where parquet files will be written.

- url:

  path, default "https://heima.hafro.is/~einarhj/datras"

- dest_directory:

  path local storage directory (default "data")

## Value

Invisibly returns `NULL`. Called for its side effects.
