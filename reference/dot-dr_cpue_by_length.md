# Calculate CPUE per length class from HH and HL exchange data

Computes catch per unit effort (numbers per hour of hauling) at each
length class per haul per species from raw DATRAS HH and HL tables,
replicating the ICES DATRAS CPUE-per-length product from first
principles.

## Usage

``` r
.dr_cpue_by_length(
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

  DATRAS haul header table (HH) with new-style column names (as returned
  by
  [`dr_get`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
  with `from = "parquet"` or `from = "new"`, or by
  [`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)).
  Required columns: `Survey`, `Year`, `Quarter`, `Country`, `Platform`,
  `Gear`, `StationName`, `HaulNumber`, `HaulValidity`, `DataType`,
  `HaulDuration`.

- hl:

  DATRAS length table (HL) with new-style column names. Required
  columns: `Survey`, `Year`, `Quarter`, `Country`, `Platform`, `Gear`,
  `StationName`, `HaulNumber`, `SpeciesValidity`, `LengthCode`,
  `LengthClass`, `NumberAtLength`, `SubsamplingFactor`, `ValidAphiaID`.

- haulval:

  Character vector of `HaulValidity` codes to retain. Default `"V"`
  (valid hauls only).

- specval:

  Integer or character vector of `SpeciesValidity` codes to retain.
  Default `1L` (standard species records only).

- zerofill:

  Logical. When `TRUE`, adds explicit zero rows for every haul × species
  combination where the species was observed somewhere in the same
  `Survey` / `Year` / `Quarter` but was absent from that haul. Zero rows
  carry `length_mm = NA` and `n_hour = 0`. Replicates the ICES CPUEL
  zero-fill convention. Ignored when `diag = TRUE`. Default `FALSE`.

- diag:

  Logical. When `TRUE`, skips the final aggregation and returns the
  per-row pre-aggregation table, retaining `SpeciesSex`,
  `SpeciesCategory`, `NumberAtLength`, `SubsamplingFactor`, `DataType`,
  `HaulDuration`, `n_haul`, and `n_hour`. Useful for inspecting
  duplicate rows or the SpeciesSex / SpeciesCategory structure that
  drives the aggregation. Default `FALSE`.

## Value

When `diag = FALSE` (default), a tibble with one row per `.id` ×
`ValidAphiaID` × `length_mm` combination (plus one zero row per absent
haul × species when `zerofill = TRUE`):

- `.id`:

  8-field unique haul identifier from
  [`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md):
  `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`.

- `.id2`:

  6-field identifier matching the ICES CPUEL product join key (lacks
  `Country` and `StationName`):
  `Survey:Year:Quarter:Platform:Gear:HaulNumber`.

- `Survey`, `Year`, `Quarter`:

  Survey metadata.

- `ValidAphiaID`:

  Valid WoRMS AphiaID.

- `length_mm`:

  Length class in millimetres (converted from `LengthClass` via
  `LengthCode`). `NA` for zero-fill rows.

- `n_hour`:

  CPUE: estimated numbers per hour of hauling, summed across
  `SpeciesSex` and `SpeciesCategory`. `0` for zero-fill rows.

When `diag = TRUE`, returns the pre-aggregation table with additional
columns `SpeciesSex`, `SpeciesCategory`, `NumberAtLength`,
`SubsamplingFactor`, `DataType`, `HaulDuration`, `n_haul`.

## Details

Filters to valid hauls (`HaulValidity == "V"`) and standard species
records (`SpeciesValidity == 1`) by default, then applies
[`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md)
and
[`dr_add_length_mm`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_mm.md).
Counts are aggregated across `SpeciesSex` and `SpeciesCategory` so each
output row represents a unique haul × species × length combination.

## See also

`.dr_cpue_by_haul` for the haul-aggregated version.
[`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md),
[`dr_add_length_mm`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_mm.md),
[`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)
