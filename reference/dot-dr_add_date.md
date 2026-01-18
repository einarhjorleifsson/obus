# Calculate date based on `Year`, `Month`, and `Day`.

This function adds a new column `date` to the input table (DuckDB table
or dataframe), computed from the `Year`, `Month`, and `Day` columns. If
the provided input is neither a DuckDB table nor a dataframe, the
function returns `NULL` and informs the user.

## Usage

``` r
.dr_add_date(d)
```

## Arguments

- d:

  A DuckDB connection table or a dataframe containing at least the
  columns: `Year` (numeric or integer), `Month` (numeric or integer),
  and `Day` (numeric or integer).

## Value

The input table (DuckDB table or dataframe) with an additional `date`
column, or `NULL` if the input is neither a DuckDB table nor a
dataframe.

## Details

The function checks if the required columns `Year`, `Month`, and `Day`
exist, and throws an error if they are missing.
