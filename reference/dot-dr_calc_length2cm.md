# Calculate length based on `LngtCode` and `LngtClass`.

This function adds a new column `length` to the input dataframe,
computed based on the `LngtCode` and `LngtClass` values. The
transformation rules for the `length` column are as follows:

- `LngtCode == "-9"`: The `length` is set to `NA` (assumed to have been
  handled upstream).

- `LngtCode %in% c(".", "0")`: The `length` is computed as the floor of
  `LngtClass` divided by 10.

- `LngtCode %in% c("1", "2", "5")`: The `length` is directly set as
  `LngtClass`.

- Otherwise: `length` is set to `NA`.

## Usage

``` r
.dr_calc_length2cm(d)
```

## Arguments

- d:

  A dataframe containing at least two columns: `LngtCode` (character)
  and `LngtClass` (numeric).

## Value

The table `d` with an additional column `length`.
