# Add a standardized `length_cm` column to the input table

This function adds a new column `length_cm` to the input table (`d`),
computed based on `LengthCode` and `LengthClass` (or their alternative
names).

## Usage

``` r
.dr_add_length_cm(d, LengthCode = LengthCode, LengthClass = LengthClass)
```

## Arguments

- d:

  A dataframe or DuckDB table containing at least two columns: a column
  for `LengthCode` and a column for `LengthClass`.

- LengthCode:

  The column specifying the length code (unquoted). Defaults to
  `LengthCode`.

- LengthClass:

  The column specifying the length class (unquoted). Defaults to
  `LengthClass`.

## Value

The input table with an additional column `length_cm`.
