# Calculate column `n` based on `DataType` and `HaulDur`.

This function calculates a new column `n` for a table (`hl`) by joining
it with another table (`hh`). The calculation of `n` depends on the
values of the `DataType` column and the duration of the haul
(`HaulDur`). The function ensures all required columns exist in the
input tables before processing.

## Usage

``` r
.dr_calc_n(hh, hl)
```

## Arguments

- hh:

  A table containing columns `.id`, `DataType`, and `HaulDur`.

- hl:

  A table containing columns `.id` and `HLNoAtLngt`.

## Value

A table created by joining `hh` with `hl`, with an additional column
`n`:

- If `DataType == "R"`, `n` is set to `HLNoAtLngt` (data by haul).

- If `DataType == "C"`, `n` is calculated as `HLNoAtLngt * HaulDur / 60`
  (CPUE, number per hour).

- If `DataType == "P"` or `"S"`, `n` is set to `-9999` (unsupported
  case).

- If `DataType == "-9"` or `is.na(DataType)`, `n` is set to `NA`.

- All other `DataType` values default to `-10000` (unexpected).
