# Check SubsamplingFactor constraints against DataType

DATRAS requires:

- DataType **R**: `SubsamplingFactor >= 1`

- DataType **S**: `SubsamplingFactor > 1` (strictly)

- DataType **C**: `SubsamplingFactor == 1`

## Usage

``` r
dr_check_subfactor(
  hl,
  DataType = DataType,
  SubsamplingFactor = SubsamplingFactor,
  flag = FALSE
)
```

## Arguments

- hl:

  HL exchange table. Must contain `DataType` and `SubsamplingFactor` (or
  the column names supplied via `DataType` / `SubsamplingFactor`). If
  `DataType` is absent, join HH before calling this function.

- DataType:

  Unquoted column name for the data type field. Default: `DataType`
  (same in both naming conventions).

- SubsamplingFactor:

  Unquoted column name for the subsampling factor. Default:
  `SubsamplingFactor` (new-style). Use `SubFactor` for old-style tables
  from `dr_con_raw()` or `dr_get(from = "old")`.

- flag:

  Logical. If `FALSE` (default) return a one-row summary tibble. If
  `TRUE` return the input data with a `.pass` column added (`TRUE` =
  passes, `FALSE` = fails, `NA` = DataType not R/S/C, not evaluated).

## Value

A one-row summary tibble, or the input data with `.pass` added.

## Details

Violations silently corrupt `n_haul` computed by
[`dr_add_n_and_cpue()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md).
