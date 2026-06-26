# Haul-level catch totals (numbers and weights) from HH and HL exchange data

Computes total catch in numbers and weight per haul per species from raw
DATRAS HH and HL tables, and annotates each species with its Latin and
common name via
[`dr_add_species`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md).
`SpeciesSex` and `SpeciesCategory` are collapsed by summation.

## Usage

``` r
dr_hl_haul(hh = NULL, hl = NULL, species = NULL)
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
  Required columns: `.id`, `aphia`, `SpeciesValidity`, `TotalNumber`,
  `SpeciesCategoryWeight`, `SpeciesSex`, `SpeciesCategory`.

- species:

  Species lookup table with columns `aphia`, `latin`, and `species`
  (common name). When `NULL` (default), falls back to
  `dr_con("species")`.

## Value

A lazy DuckDB table or data frame (matching the input type) with one row
per `.id` \\\times\\ `latin` combination, plus one zero row per absent
haul \\\times\\ species:

- `.id`:

  8-field unique haul identifier:
  `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`.

- `latin`:

  WoRMS-accepted Latin species name.

- `species`:

  Common species name.

- `n_haul`:

  Total estimated numbers caught per haul. `0` for zero rows.

- `n_hour`:

  Total estimated numbers per hour of hauling. `0` for zero rows.

- `w_haul`:

  Total catch weight per haul in grams. `0` for zero rows. `NA` within
  non-zero rows when `SpeciesCategoryWeight` was not recorded for all
  sex/category groups.

- `w_hour`:

  Total catch weight per hour of hauling in grams. `0` for zero rows;
  `NA` as for `w_haul`.

- `SpeciesValidity`:

  Species validity code from HL. `NA` for zero rows.

## Details

`TotalNumber` and `SpeciesCategoryWeight` are haul-level summary fields
in HL that are repeated across every length row within a
species/sex/category group. The function deduplicates at the group level
before applying DataType-aware scaling, so each length row does not
inflate the totals. A zero row (all metrics `0`) is inserted for every
species that was observed somewhere in the same `Survey` / `Year` /
`Quarter` but was absent from a given haul, including hauls with no
catch at all.

## See also

[`dr_hl_length`](https://einarhjorleifsson.github.io/obus/reference/dr_hl_length.md)
for the length-disaggregated version.
[`dr_add_species`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md),
[`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md),
[`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
