# Haul-level catch totals (numbers and weights) from HH and HL exchange data

Computes total catch in numbers and weight per haul per species from raw
DATRAS HH and HL tables. Counts are derived from `TotalNumber` and
weights from `SpeciesCategoryWeight`; both are haul-level summary fields
in HL that are repeated across every length row within a
species/sex/category group. The function deduplicates at the group level
before applying DataType-aware scaling and aggregating across
`SpeciesSex` and `SpeciesCategory`.

## Usage

``` r
.dr_cpue_by_haul(
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
  Required: `Survey`, `Year`, `Quarter`, `Country`, `Platform`, `Gear`,
  `StationName`, `HaulNumber`, `HaulValidity`, `DataType`,
  `HaulDuration`.

- hl:

  DATRAS length table (HL) with new-style column names. Required:
  `Survey`, `Year`, `Quarter`, `Country`, `Platform`, `Gear`,
  `StationName`, `HaulNumber`, `SpeciesValidity`, `ValidAphiaID`,
  `TotalNumber`, `SpeciesCategoryWeight`, `SpeciesSex`,
  `SpeciesCategory`.

- haulval:

  Character vector of `HaulValidity` codes to retain. Default `"V"`
  (valid hauls only).

- specval:

  Integer or character vector of `SpeciesValidity` codes to retain.
  Default `1L` (standard species records only).

- zerofill:

  Logical. When `TRUE`, adds explicit zero rows for every haul × species
  combination where the species was observed somewhere in the same
  `Survey` / `Year` / `Quarter` but was absent from that haul
  (`n_haul = n_hour = w_haul = w_hour = 0`). Default `FALSE`.

- diag:

  Logical. When `TRUE`, skips the aggregation over `SpeciesSex` and
  `SpeciesCategory` and returns the deduplicated, scaled table at the
  species/sex/category level. Retains `DataType`, `HaulDuration`,
  `TotalNumber`, and `SpeciesCategoryWeight` alongside the derived
  columns. Useful for QC (e.g. spotting inconsistent `TotalNumber`
  values or unexpected sex/category structure). Default `FALSE`.

## Value

When `diag = FALSE` and `zerofill = FALSE` (defaults), a tibble with one
row per `.id` × `ValidAphiaID`:

- `.id`:

  8-field haul key:
  `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`.

- `.id2`:

  6-field key matching the ICES CPUEL join key (lacks `Country` and
  `StationName`): `Survey:Year:Quarter:Platform:Gear:HaulNumber`.

- `Survey`, `Year`, `Quarter`:

  Survey metadata.

- `ValidAphiaID`:

  Valid WoRMS AphiaID.

- `n_haul`:

  Total estimated numbers caught per haul.

- `n_hour`:

  Total estimated numbers per hour of hauling.

- `w_haul`:

  Total catch weight per haul (grams).

- `w_hour`:

  Total catch weight per hour of hauling (grams).

`w_haul` and `w_hour` are `NA` when `SpeciesCategoryWeight` was not
recorded for all sex/category groups of a species. Zero-fill rows have
all four columns set to `0`.

## Details

This function operates independently of `.dr_cpue_by_length` and is the
appropriate choice when you need haul-level totals (including weights)
rather than length-disaggregated CPUE. Unlike `dr_cpue_by_length`, which
derives counts from `NumberAtLength`, this function uses `TotalNumber`
directly — the two approaches should give the same counts but may differ
slightly due to rounding in submitted data.

## See also

`.dr_cpue_by_length` for length-disaggregated CPUE derived from
`NumberAtLength`.
