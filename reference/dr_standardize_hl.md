# Standardize HL into a clean catch foundation (length and haul summaries)

Produces a unified catch table from raw HH and HL exchange tables with
two row types controlled by the `type` column:

## Usage

``` r
dr_standardize_hl(hh, hl, species = NULL, haulval = NULL)
```

## Arguments

- hh:

  DATRAS HH table (standard column names, `.id` present). Required
  columns: `.id`, `Survey`, `Year`, `Quarter`, `DataType`,
  `HaulDuration`, `StandardSpeciesCode`, `BycatchSpeciesCode`. Optional:
  `HaulValidity` (used when `haulval` is set).

- hl:

  DATRAS HL table (standard column names, `.id` present). Required for
  `type = "length"`: `.id`, `aphia`, `NumberAtLength`, `LengthClass`,
  `LengthCode`, `SubsamplingFactor`, `sex`, `SpeciesValidity`. Required
  for `type = "haul"`: additionally `TotalNumber`,
  `SpeciesCategoryWeight`, `SpeciesCategory`.

- species:

  Species lookup with columns `aphia`, `latin`, `species`. Defaults to
  `dr_con("species")`.

- haulval:

  Character vector of `HaulValidity` codes to retain. `NULL` keeps all
  hauls.

## Value

A lazy DuckDB table with columns: `.id`, `Survey`, `Year`, `Quarter`,
`aphia`, `latin`, `species`, `type`, `length_mm`, `length_cm`,
`accuracy` (`NA` for `type = "haul"`), `n_haul`, `n_hour`, `w_haul`,
`w_hour` (`NA` for `type = "length"`), `p_females`, `SpeciesValidity`,
`StandardSpeciesCode`, `BycatchSpeciesCode`.

## Details

- `type = "length"`:

  One row per `.id` \\\times\\ `aphia` \\\times\\ `length_mm`. Sex and
  DevelopmentStage are collapsed; sex composition is summarised as
  `p_females` (proportion female among sexed fish). Derived from
  `NumberAtLength` via
  [`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md).
  Replaces
  [`dr_catch_by_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md).

- `type = "haul"`:

  One row per `.id` \\\times\\ `aphia`. Numbers (`n_haul`, `n_hour`)
  come from `TotalNumber`; weights (`w_haul`, `w_hour`) from
  `SpeciesCategoryWeight`. Sex composition summarised as `p_females`.
  Replaces
  [`dr_catch_total()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_total.md)
  (without zero-filling). Pass output to
  [`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
  for zero-filling.

**Note:** `n_haul` from `type = "haul"` may differ from the sum of
`n_haul` across `type = "length"` rows for the same haul and species.
The haul path uses `TotalNumber` which counts all fish including those
counted but not measured at length.

## See also

[`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md),
[`dr_expand_length`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
