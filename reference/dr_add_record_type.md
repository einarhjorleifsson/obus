# Classify HL records by measurement type

Adds a `record_type` integer column to the HL table classifying each row
by the combination of variables that are present or absent. See
[`hl_record_type_lookup`](hl_record_type_lookup.md) for the full
definition of each code.

## Usage

``` r
dr_add_record_type(d)
```

## Arguments

- d:

  DATRAS length table (HL) containing at least the columns `.id`,
  `ValidAphiaID`, `LengthClass`, `n_haul`, `SpeciesSex`,
  `DevelopmentStage`, `TotalNumber`, `SpeciesCategoryWeight`, and
  `SubsamplingFactor`.

## Value

`d` with an additional integer column `record_type`.

## Details

The function requires that [`dr_add_n_and_cpue`](dr_add_n_and_cpue.md)
has already been run so that `n_haul` is present; it uses `n_haul` as a
proxy for haul validity (types 1–3 vs type 4) rather than reading
`DataType` directly.

Classification uses two passes. The first pass assigns types row-by-row
using variable presence/absence. The second pass requires haul-level
context: weight-only records (initially type 11) are reclassified as
type 16 when a development-stage length-frequency record (type 3) exists
for the same `.id` and `ValidAphiaID`, identifying them as companion
weight entries rather than standalone bulk bycatch.

## See also

[`hl_record_type_lookup`](hl_record_type_lookup.md)
