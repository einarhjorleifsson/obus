# Standardize HL table with derived columns and type flag

Creates a standardized HL parquet foundation with two row types:

- type="length": length-frequency records with computed n_haul/n_hour

- type="haul": haul-level summaries (TotalNumber, weight) deduplicated
  by haul × species

## Usage

``` r
dr_standardize_hl(hh, hl, species = NULL, haulval = NULL)
```

## Arguments

- hh:

  DATRAS HH table with columns: .id, Survey, Year, Quarter, DataType,
  HaulDuration

- hl:

  DATRAS HL table with columns: .id, aphia, LengthCode, LengthClass,
  NumberAtLength, SubsamplingFactor, TotalNumber, SpeciesCategoryWeight,
  SpeciesSex, SpeciesCategory, SpeciesValidity

- species:

  Species lookup table (aphia, latin, species). Defaults to
  dr_con("species")

- haulval:

  Character vector of HaulValidity codes to retain. NULL keeps all.

## Value

A lazy DuckDB table with two row types:

- type="length": one row per haul × species × length_mm

- type="haul": one row per haul × species Both have columns: .id,
  Survey, Year, Quarter, aphia, latin, species, type, length_mm,
  length_cm, accuracy (length type only), n_haul, n_hour, w_haul, w_hour
  (haul type only), SpeciesValidity, StandardSpeciesCode,
  BycatchSpeciesCode
