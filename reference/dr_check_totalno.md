# Check TotalNo arithmetic against DataType rules

For each (`.id`, species, sex, `CatIdentifier`) group:

- DataType **R** or **S**: `TotalNo ~= sum(HLNoAtLngt) * SubFactor`

- DataType **C**: `TotalNo ~= sum(HLNoAtLngt)`

## Usage

``` r
dr_check_totalno(
  hl,
  DataType = DataType,
  TotalNo = TotalNo,
  SubFactor = SubFactor,
  HLNoAtLngt = HLNoAtLngt,
  Species = Valid_Aphia,
  Sex = Sex,
  CatIdentifier = CatIdentifier,
  tol = 0.5,
  flag = FALSE
)
```

## Arguments

- hl:

  HL exchange table. Must contain `DataType`, `TotalNo`, `SubFactor`,
  `HLNoAtLngt`, `.id`, and the grouping fields `Valid_Aphia`, `Sex`,
  `CatIdentifier` (or the column names supplied below). Join HH for
  `DataType` if it is not present.

- DataType, TotalNo, SubFactor, HLNoAtLngt, Species, Sex, CatIdentifier:

  Unquoted column names. Old-style defaults shown. New-style
  equivalents: `TotalNumber`, `SubsamplingFactor`, `NumberAtLength`,
  `ValidAphiaID`, `IndividualSex`, `SpeciesCategory`.

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
submissions. Groups with `NA` in `TotalNo`, `SubFactor`, or `HLNoAtLngt`
are skipped (counted separately in the detail string).
