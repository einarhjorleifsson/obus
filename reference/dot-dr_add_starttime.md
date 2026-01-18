# Calculate timestamp based on `Year`, `Month`, `Day`, and `StartTime`/`TimeShot`.

This function calculates a precise timestamp using the `Year`, `Month`,
`Day`, and `StartTime` or `TimeShot` columns from the input table
(DuckDB table or dataframe). The time column is expected to be a numeric
or character string representing time in 24-hour `HHMM` format. It
ensures all required columns are present in the input and adjusts
behavior based on whether the input is a DuckDB table or a standard
dataframe.

## Usage

``` r
.dr_add_starttime(d)
```

## Arguments

- d:

  A DuckDB connection table or a dataframe containing at least the
  columns: `Year` (numeric or integer), `Month` (numeric or integer),
  `Day` (numeric or integer), and `StartTime`/`TimeShot` (numeric or
  character in `HHMM` format).

## Value

The input table (DuckDB table or dataframe) with an additional
`timestamp` column, calculated as a POSIXct timestamp, or `NULL` if the
input is neither a DuckDB table nor a dataframe.
