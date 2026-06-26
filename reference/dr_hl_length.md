# Zero-filled length-frequency CPUE table from HH and HL exchange data

Builds a species-annotated, zero-filled CPUE-per-length table from raw
DATRAS HH and HL tables. Joins HH metadata (`DataType`, `HaulDuration`),
converts length classes to centimetres via
[`dr_add_length_cm`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_cm.md),
computes `n_haul` and `n_hour` via
[`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md),
annotates species names via
[`dr_add_species`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md),
then collapses `SpeciesSex` and `DevelopmentStage`. Every species
observed in a `Survey` / `Year` / `Quarter` receives an explicit zero
row for each haul where it was absent, including hauls with no catch at
all (sourced from HH so that empty hauls are not missed).

## Usage

``` r
dr_hl_length(hh = NULL, hl = NULL, species = NULL)
```

## Arguments

- hh:

  DATRAS haul header table (HH) with new-style column names (as returned
  by
  [`dr_get`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
  or
  [`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)).
  When `NULL` (default), falls back to `dr_con("HH")`. Pre-filter before
  passing if desired (e.g. `dplyr::filter(HaulValidity == "V")`). Must
  already carry `.id` (add with
  [`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)).
  Required columns: `.id`, `Survey`, `Year`, `Quarter`, `DataType`,
  `HaulDuration`.

- hl:

  DATRAS length table (HL) with new-style column names. When `NULL`
  (default), falls back to `dr_con("HL")`. Pre-filter before passing if
  desired (e.g. `dplyr::filter(SpeciesValidity == "1")`). Must already
  carry `.id` (add with
  [`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)).
  Required columns: `.id`, `NumberAtLength`, `LengthClass`,
  `LengthCode`, `SubsamplingFactor`, `aphia`, `SpeciesValidity`.

- species:

  Species lookup table with columns `aphia`, `latin`, and `species`
  (common name). When `NULL` (default), falls back to
  `dr_con("species")`.

## Value

A lazy DuckDB table or data frame (matching the input type) with one row
per `.id` \\\times\\ `latin` \\\times\\ `length_cm` combination, plus
one zero row per absent haul \\\times\\ species:

- `.id`:

  8-field unique haul identifier:
  `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`.

- `latin`:

  WoRMS-accepted Latin species name.

- `species`:

  Common species name.

- `length_cm`:

  Length class in centimetres. `0` for zero rows.

- `accuracy`:

  Measurement resolution in centimetres (e.g. `0.5` for half-centimetre
  classes). `NA` for zero rows.

- `n_haul`:

  Estimated numbers caught per haul. `0` for zero rows.

- `n_hour`:

  Estimated numbers per hour of hauling (CPUE). `0` for zero rows.

- `SpeciesValidity`:

  Species validity code from HL. `NA` for zero rows.

## See also

[`dr_add_length_cm`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_cm.md),
[`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md),
[`dr_add_species`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md),
[`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md),
[`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
