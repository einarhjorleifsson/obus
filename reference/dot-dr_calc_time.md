# Calculate timestamp based on `Year`, `Month`, `Day`, and `TimeShot`.

This function calculates a precise timestamp using the `Year`, `Month`,
`Day`, and `TimeShot` columns from the input table (DuckDB table or
dataframe). The `TimeShot` column is expected to be a numeric or
character string representing time in 24-hour `HHMM` format. It ensures
all required columns are present in the input and adjusts behavior based
on whether the input is a DuckDB table or a standard dataframe.

## Usage

``` r
.dr_calc_time(d)
```

## Arguments

- d:

  A DuckDB connection table or a dataframe containing at least the
  columns: `Year` (numeric or integer), `Month` (numeric or integer),
  `Day` (numeric or integer), and `TimeShot` (numeric or character in
  `HHMM` format).

## Value

The input table (DuckDB table or dataframe) with an additional
`timestamp` column, calculated as a POSIXct timestamp, or `NULL` if the
input is neither a DuckDB table nor a dataframe.

## Details

The function performs the following:

- Pads `TimeShot` to ensure it is 4 digits (e.g., `800` becomes `0800`).

- Extracts hours and minutes from the padded `TimeShot`.

- Combines the values from `Year`, `Month`, `Day`, `Hour`, and `Minute`
  to generate a complete timestamp.

- Adds a `timestamp` column (calculated) and removes intermediate
  columns used in processing.
