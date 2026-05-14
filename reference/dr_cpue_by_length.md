# Calculate CPUE per length class from HH and HL exchange data

Computes catch per unit effort (numbers per hour of hauling) at each
length class per haul per species from raw DATRAS HH and HL tables,
replicating the ICES DATRAS CPUE-per-length product from first
principles.

## Usage

``` r
dr_cpue_by_length(
  hh,
  hl,
  haulval = "V",
  specval = 1L,
  zerofill = FALSE,
  diag = FALSE
)
```

## Arguments

- hh:

  DATRAS haul header table (HH) with old-style column names as returned
  by [`dr_get`](dr_get.md) or the raw parquet. Required columns:
  `Survey`, `Year`, `Quarter`, `Country`, `Ship`, `Gear`, `StNo`,
  `HaulNo`, `HaulVal`, `DataType`, `HaulDur`.

- hl:

  DATRAS length table (HL) with old-style column names. Required
  columns: `Survey`, `Year`, `Quarter`, `Country`, `Ship`, `Gear`,
  `StNo`, `HaulNo`, `SpecVal`, `LngtCode`, `LngtClass`, `HLNoAtLngt`,
  `SubFactor`, `Valid_Aphia`.

- haulval:

  Character vector of `HaulVal` codes to retain. Default `"V"` (valid
  hauls only).

- specval:

  Integer or character vector of `SpecVal` codes to retain. Default `1L`
  (standard species records only).

- zerofill:

  Logical. When `TRUE`, adds explicit zero rows for every haul × species
  combination where the species was observed somewhere in the same
  `Survey` / `Year` / `Quarter` but was absent from that haul. Zero rows
  carry `length_mm = NA` and `n_hour = 0`. Replicates the ICES CPUEL
  zero-fill convention. Ignored when `diag = TRUE`. Default `FALSE`.

- diag:

  Logical. When `TRUE`, skips the final aggregation and returns the
  per-row pre-aggregation table, retaining `Sex`, `CatIdentifier`,
  `HLNoAtLngt`, `SubFactor`, `DataType`, `HaulDur`, `n_haul`, and
  `n_hour`. Useful for inspecting duplicate rows or the Sex /
  CatIdentifier structure that drives the aggregation. Default `FALSE`.

## Value

When `diag = FALSE` (default), a tibble with one row per `.id` x
`Valid_Aphia` x `length_mm` combination (plus one zero row per absent
haul × species when `zerofill = TRUE`):

- `.id`:

  8-field unique haul identifier from [`dr_add_id`](dr_add_id.md):
  `Survey:Year:Quarter:Country:Ship:Gear:StNo:HaulNo`.

- `.id2`:

  6-field identifier matching the ICES CPUEL product join key (lacks
  `Country` and `StNo`): `Survey:Year:Quarter:Ship:Gear:HaulNo`.

- `Survey`, `Year`, `Quarter`:

  Survey metadata.

- `Valid_Aphia`:

  Valid WoRMS AphiaID.

- `length_mm`:

  Length class in millimetres (converted from `LngtClass` via
  `LngtCode`). `NA` for zero-fill rows.

- `n_hour`:

  CPUE: estimated numbers per hour of hauling, summed across `Sex` and
  `CatIdentifier`. `0` for zero-fill rows.

When `diag = TRUE`, returns the pre-aggregation table with additional
columns `Sex`, `CatIdentifier`, `HLNoAtLngt`, `SubFactor`, `DataType`,
`HaulDur`, `n_haul`.

## Details

Filters to valid hauls (`HaulVal == "V"`) and standard species records
(`SpecVal == 1`) by default, then applies
[`dr_add_n_and_cpue`](dr_add_n_and_cpue.md) and
[`dr_add_length_mm`](dr_add_length_mm.md). Counts are aggregated across
`Sex` and `CatIdentifier` so each output row represents a unique haul x
species x length combination.

## See also

[`dr_cpue_by_haul`](dr_cpue_by_haul.md) for the haul-aggregated version.
[`dr_add_n_and_cpue`](dr_add_n_and_cpue.md),
[`dr_add_length_mm`](dr_add_length_mm.md), [`dr_add_id`](dr_add_id.md)
