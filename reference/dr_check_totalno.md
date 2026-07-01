# Check TotalNumber arithmetic against DataType rules

For each (`.id`, species, sex, `SpeciesCategory`) group:

- DataType **R** or **S**:
  `TotalNumber ~= sum(NumberAtLength) * SubsamplingFactor`

- DataType **C**: `TotalNumber ~= sum(NumberAtLength)`

## Usage

``` r
dr_check_totalno(
  hl,
  DataType = DataType,
  TotalNumber = TotalNumber,
  SubsamplingFactor = SubsamplingFactor,
  NumberAtLength = NumberAtLength,
  Species = aphia,
  Sex = sex,
  SpeciesCategory = SpeciesCategory,
  tol = 0.5,
  flag = FALSE
)
```

## Arguments

- hl:

  HL exchange table. Must contain `DataType`, `TotalNumber`,
  `SubsamplingFactor`, `NumberAtLength`, `.id`, and the grouping fields
  `aphia`, `sex`, `SpeciesCategory` (or the column names supplied
  below). Join HH for `DataType` if it is not present. Note: `.id` must
  be present (call
  [`dr_add_id()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)
  first if needed).

- DataType, TotalNumber, SubsamplingFactor, NumberAtLength, Species,
  Sex, SpeciesCategory:

  Unquoted column names. New-style defaults shown. For old-style tables
  from `dr_con_raw()` or `dr_get(from = "old")` use: `TotalNo`,
  `SubFactor`, `HLNoAtLngt`, `Valid_Aphia`, `Sex`, `CatIdentifier`.

- tol:

  Numeric tolerance in number of fish. Default `0.5`.

- flag:

  Logical. If `FALSE` (default) return a one-row summary tibble. If
  `TRUE` return the input data with a `.pass` column added (`TRUE` =
  group passes, `FALSE` = group fails, `NA` = group not evaluated).

## Value

A one-row summary tibble, or the input data with `.pass` added.

## Details

A tolerance of `tol` fish is applied to allow for rounding in
submissions. Groups with `NA` in `TotalNumber`, `SubsamplingFactor`, or
`NumberAtLength` are skipped (counted separately in the detail string).
