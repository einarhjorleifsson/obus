# Download DATRAS latin tables

Each DATRAS latin table (HH, HL, CA) is downloaded and saved.

## Usage

``` r
dr_download_data_latin(
  surveys = NULL,
  years = NULL,
  quarters = NULL,
  outpath = "data",
  filetype = "parquet"
)
```

## Arguments

- surveys:

  Survey to get, if none specified get all

- years:

  Years to download, if none specified attempt to download all

- quarters:

  Quarters to download, if none specified attempt to download all

- outpath:

  The path (default 'data') where saved DATRAS exchange files are stored

- filetype:

  File type (default 'parquet'). Currently inactive. '

## Value

Files on disk
