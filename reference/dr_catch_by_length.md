# Standardised length-frequency catch table from HH and HL exchange data

Processes raw DATRAS HH and HL tables into a clean catch-only table with
standardised length units, corrected CPUE arithmetic, and species names.
Contains only observed catches — no zero rows. Use
[`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
or
[`dr_expand_length`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
downstream to add zero-fill.

## Usage

``` r
dr_catch_by_length(hh, hl, species = NULL, haulval = NULL)
```

## Arguments

- hh:

  DATRAS haul header table (HH). Must carry `.id`. Required columns:
  `.id`, `Survey`, `Year`, `Quarter`, `HaulValidity`, `DataType`,
  `HaulDuration`.

- hl:

  DATRAS length table (HL). Must carry `.id`. Required columns: `.id`,
  `NumberAtLength`, `LengthClass`, `LengthCode`, `SubsamplingFactor`,
  `aphia`, `SpeciesValidity`.

- species:

  Species lookup with columns `aphia`, `latin`, `species`. Defaults to
  `dr_con("species")`.

- haulval:

  Character vector of `HaulValidity` codes to retain. `NULL` keeps all
  hauls.

## Value

A lazy DuckDB table with one row per `.id` \\\times\\ `aphia` \\\times\\
`length_mm`:

- `.id`:

  8-field haul identifier.

- `Survey`:

  Survey code.

- `Year`:

  Survey year.

- `Quarter`:

  Survey quarter.

- `aphia`:

  WoRMS valid AphiaID.

- `latin`:

  WoRMS-accepted Latin name.

- `species`:

  Common name.

- `length_mm`:

  Length in millimetres.

- `length_cm`:

  Length in centimetres.

- `accuracy`:

  Measurement resolution in centimetres.

- `n_haul`:

  Estimated numbers per haul.

- `n_hour`:

  Estimated numbers per hour (CPUE).

- `SpeciesValidity`:

  Validity code from HL.

## See also

[`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md),
[`dr_expand_length`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md),
[`dr_add_length_cm`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_cm.md),
[`dr_add_n_and_cpue`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md),
[`dr_add_species`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md),
[`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
