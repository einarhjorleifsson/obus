# Haul-level catch totals (numbers and weights) from HH and HL exchange data

Computes total catch in numbers and weight per haul per species from raw
DATRAS HH and HL tables. Counts are derived from `TotalNo` and weights
from `CatCatchWgt`; both are haul-level summary fields in HL that are
repeated across every length row within a species/sex/category group.
The function deduplicates at the group level before applying
DataType-aware scaling and aggregating across `Sex` and `CatIdentifier`.

## Usage

``` r
dr_cpue_by_haul(
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

  DATRAS haul header table (HH) with old-style column names. Required:
  `Survey`, `Year`, `Quarter`, `Country`, `Ship`, `Gear`, `StNo`,
  `HaulNo`, `HaulVal`, `DataType`, `HaulDur`.

- hl:

  DATRAS length table (HL) with old-style column names. Required:
  `Survey`, `Year`, `Quarter`, `Country`, `Ship`, `Gear`, `StNo`,
  `HaulNo`, `SpecVal`, `Valid_Aphia`, `TotalNo`, `CatCatchWgt`, `Sex`,
  `CatIdentifier`.

- haulval:

  Character vector of `HaulVal` codes to retain. Default `"V"` (valid
  hauls only).

- specval:

  Integer or character vector of `SpecVal` codes to retain. Default `1L`
  (standard species records only).

- zerofill:

  Logical. When `TRUE`, adds explicit zero rows for every haul × species
  combination where the species was observed somewhere in the same
  `Survey` / `Year` / `Quarter` but was absent from that haul
  (`n_haul = n_hour = w_haul = w_hour = 0`). Default `FALSE`.

- diag:

  Logical. When `TRUE`, skips the aggregation over `Sex` and
  `CatIdentifier` and returns the deduplicated, scaled table at the
  species/sex/category level. Retains `DataType`, `HaulDur`, `TotalNo`,
  and `CatCatchWgt` alongside the derived columns. Useful for QC (e.g.
  spotting inconsistent `TotalNo` values or unexpected sex/category
  structure). Default `FALSE`.

## Value

When `diag = FALSE` and `zerofill = FALSE` (defaults), a tibble with one
row per `.id` × `Valid_Aphia`:

- `.id`:

  8-field haul key: `Survey:Year:Quarter:Country:Ship:Gear:StNo:HaulNo`.

- `.id2`:

  6-field key matching the ICES CPUEL join key.

- `Survey`, `Year`, `Quarter`:

  Survey metadata.

- `Valid_Aphia`:

  Valid WoRMS AphiaID.

- `n_haul`:

  Total estimated numbers caught per haul.

- `n_hour`:

  Total estimated numbers per hour of hauling.

- `w_haul`:

  Total catch weight per haul (grams).

- `w_hour`:

  Total catch weight per hour of hauling (grams).

`w_haul` and `w_hour` are `NA` when `CatCatchWgt` was not recorded for
all sex/category groups of a species. Zero-fill rows have all four
columns set to `0`.

## Details

This function operates independently of
[`dr_cpue_by_length`](dr_cpue_by_length.md) and is the appropriate
choice when you need haul-level totals (including weights) rather than
length-disaggregated CPUE. Unlike `dr_cpue_by_length`, which derives
counts from `HLNoAtLngt`, this function uses `TotalNo` directly — the
two approaches should give the same counts but may differ slightly due
to rounding in submitted data.

## See also

[`dr_cpue_by_length`](dr_cpue_by_length.md) for length-disaggregated
CPUE derived from `HLNoAtLngt`.
