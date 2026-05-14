# Check SubsamplingFactor constraints against DataType

DATRAS requires:

- DataType **R**: `SubFactor >= 1`

- DataType **S**: `SubFactor > 1` (strictly)

- DataType **C**: `SubFactor == 1`

## Usage

``` r
dr_check_subfactor(
  hl,
  DataType = DataType,
  SubFactor = SubFactor,
  flag = FALSE
)
```

## Arguments

- hl:

  HL exchange table. Must contain `DataType` and `SubFactor` (or the
  column names supplied via `DataType` / `SubFactor`). If `DataType` is
  absent, join HH before calling this function.

- DataType:

  Unquoted column name for the data type field. Default: `DataType`
  (old-style).

- SubFactor:

  Unquoted column name for the subsampling factor. Default: `SubFactor`
  (old-style). Use `SubsamplingFactor` for new-style.

- flag:

  Logical. If `FALSE` (default) return a one-row summary tibble. If
  `TRUE` return the input data with a `.pass` column added (`TRUE` =
  passes, `FALSE` = fails, `NA` = DataType not R/S/C, not evaluated).

## Value

A one-row summary tibble, or the input data with `.pass` added.

## Details

Violations silently corrupt `n_haul` computed by
[`dr_add_n_and_cpue()`](dr_add_n_and_cpue.md).
