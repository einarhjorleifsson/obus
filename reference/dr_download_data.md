# Download DATRAS tables

Each DATRAS table (HH, HL, CA and FL) is downloaded and saved.

## Usage

``` r
dr_download_data(
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

  Years to download, if none specified get all from 1990 onwards. Not
  yet active.

- quarters:

  Quarters to download, if none specified get all from 1990 onwards. Not
  yet active.

- outpath:

  The path (default 'data') where saved DATRAS exchange files are stored

- filetype:

  File type (default 'parquet'). Currently inactive. '

## Value

Files on disk
