# Standardized HL: the semantic layer for DATRAS length data

## The problem with raw DATRAS HL

The DATRAS HL (length) table is a denormalized source of record: it
contains both length-frequency measurements and haul-level bookkeeping.
In addition, the value of one variable often requires knowledge of
others or external context:

- **`LengthClass`** value depends on **`LengthCode`** (is it mm? 0.5 cm?
  cm?)
- **`NumberAtLength`** meaning depends on **`DataType`** (is it raw
  count? CPUE? subsampled?) and **`HaulDuration`**
- **`TotalNumber`** and **`SpeciesCategoryWeight`** are repeated on
  every length row, creating redundancy
- **`aphia`** is a code; users think in species names (latin or common
  names).
- **Supporting columns** (`LengthCode`, `SubsamplingFactor`) are
  implementation details once extracted

Users shouldn’t need to understand these interdependencies. They should
work with clean, self-contained data.

## The solution: standardized HL

[`dr_standardize_hl()`](https://einarhjorleifsson.github.io/obus/reference/dr_standardize_hl.md)
creates a **semantic layer** — a parquet file that is designed to be
written once and reused across many analyses. For **interactive work** —
quick CPUE indices, length distributions, zero-filling handled
automatically — the [Catch
products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd)
pipeline
([`dr_catch_by_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
→
[`dr_catch_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
/
[`dr_expand_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md))
is more ergonomic. The two approaches are complementary: the
`catch_products` functions are convenient but do not expose protocol
metadata;
[`dr_standardize_hl()`](https://einarhjorleifsson.github.io/obus/reference/dr_standardize_hl.md)
carries `StandardSpeciesCode` and `BycatchSpeciesCode` through so
protocol-aware filtering is possible.

The standardized HL is a parquet file that is:

- **Self-contained**: every variable has unambiguous meaning.
  `length_mm` is always millimetres.
- **User-friendly**: species names pre-joined. No codes to translate.
- **Type-flagged**: distinguishes length measurements from haul
  bookkeeping
- **Publication-ready**: can be served over https and reused by many
  analyses

``` r

library(obus)
library(dplyr)
library(tidyr)
library(ggplot2)
library(Hmisc)

hh <- dr_con("HH")
hl <- dr_con("HL")

# Generate standardized HL for a small example
hl_std <- dr_standardize_hl(
  hh |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015, HaulValidity == "V") |> head(10),
  hl |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015)
) |> collect()

cat("Standardized HL rows:", nrow(hl_std), "\n")
```

    Standardized HL rows: 2139 

``` r

cat("Type breakdown:\n")
```

    Type breakdown:

``` r

print(table(hl_std$type))
```


      haul length
       266   1873 

## Two row types, one table

The standardized HL has a `type` flag that separates two fundamentally
different data:

``` r

length_rows <- hl_std |> filter(type == "length") |> head(3)
cat("Type='length' rows — length-frequency measurements:\n")
```

    Type='length' rows — length-frequency measurements:

``` r

print(length_rows |> select(.id, species, length_mm, n_haul, n_hour))
```

    # A tibble: 3 × 5
      .id                                  species           length_mm n_haul n_hour
      <chr>                                <chr>                 <int>  <dbl>  <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 blue whiting            170      1      2
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 grey gurnard            270     19     38
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Corbin's sand eel       280      1      2

``` r

haul_rows <- hl_std |> filter(type == "haul") |> head(3)
cat("\nType='haul' rows — haul-level bookkeeping (deduplicated):\n")
```


    Type='haul' rows — haul-level bookkeeping (deduplicated):

``` r

print(haul_rows |> select(.id, species, n_haul, w_haul))
```

    # A tibble: 3 × 4
      .id                                  species                 n_haul w_haul
      <chr>                                <chr>                    <dbl>  <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 American plaice            161   4945
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlantic horse mackerel      9    160
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:6:6   flet                         1    198

**Why two types in one table?**

1.  **Simplicity**: users interact with one parquet file
2.  **Flexibility**: users choose which data to use downstream
3.  **Completeness**: preserves all caught species (even those not
    measured at length)
4.  **Zero-fill**: haul-type rows define the species grid for
    zero-filling

## Example workflows

### Length-structured index

For stock assessment, use type=“length” rows:

``` r

# Haddock length distribution across all hauls
haddock_lf <- hl_std |>
  filter(type == "length", species == "haddock")

cat("Haddock length records:", nrow(haddock_lf), "\n")
```

    Haddock length records: 252 

``` r

cat("Mean CPUE by 10cm bin:\n")
```

    Mean CPUE by 10cm bin:

``` r

print(haddock_lf |>
  mutate(bin = floor(length_cm / 10) * 10) |>
  group_by(bin) |>
  summarise(mean_cpue = mean(n_hour, na.rm = TRUE), .groups = "drop"))
```

    # A tibble: 5 × 2
        bin mean_cpue
      <dbl>     <dbl>
    1    10     115.
    2    20      35.4
    3    30      27.7
    4    40      13.6
    5    50       2  

### Haul-level CPUE with zero-fill

For indices, use type=“haul” rows and add zero hauls:

``` r

# All hauls in the SYQ (collect to work with expand_grid)
all_hauls <- hh |>
  filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015, HaulValidity == "V") |>
  distinct(.id) |>
  pull(.id)

# Species that were caught (from haul-type rows)
caught_species <- hl_std |>
  filter(type == "haul") |>
  pull(species) |>
  unique()

# Build zero-filled CPUE (collect haul rows for join)
haul_cpue <- hl_std |>
  filter(type == "haul") |>
  select(.id, species, n_haul, n_hour) |>
  collect()

# Add zeros (expand_grid works on in-memory data)
zero_rows <- expand_grid(
  .id = all_hauls,
  species = caught_species
) |>
  anti_join(haul_cpue |> distinct(.id, species), by = c(".id", "species")) |>
  mutate(n_haul = 0, n_hour = 0)

cpue_complete <- bind_rows(haul_cpue, zero_rows)

cat("CPUE grid:", n_distinct(cpue_complete$.id), "×",
    n_distinct(cpue_complete$species), "=", nrow(cpue_complete), "\n")
```

    CPUE grid: 378 × 51 = 19286 

## Design rationale and trade-offs

### Why this approach?

1.  **Separation of concerns**: standardization (units, names, scaling)
    is independent of filtering/aggregation
2.  **Reusability**: one semantic layer, many downstream uses
3.  **Reproducibility**: everyone works from the same standardized
    source
4.  **Self-documenting**: the type flag makes the contract explicit

### Expected mismatches

**Length rows don’t sum to haul rows.** This is **not a bug**; it’s
revealing:

``` r

length_total <- hl_std |>
  filter(type == "length", .id == hl_std$.id[1]) |>
  group_by(.id, species) |>
  summarise(n_haul_from_length = sum(n_haul, na.rm = TRUE), .groups = "drop")

haul_total <- hl_std |>
  filter(type == "haul", .id == hl_std$.id[1]) |>
  select(.id, species, n_haul)

comparison <- full_join(length_total, haul_total, by = c(".id", "species"))
cat("Sample comparison (may not match):\n")
```

    Sample comparison (may not match):

``` r

print(head(comparison, 5))
```

    # A tibble: 5 × 4
      .id                                  species         n_haul_from_length n_haul
      <chr>                                <chr>                        <dbl>  <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 American plaice                 21     21
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic cod                    47     47
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic herri…                  1      1
    4 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic horse…                 20     20
    5 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic macke…                  1      1

**Why they differ:**

- **`NumberAtLength`** (length rows) = individuals actually measured at
  length
- **`TotalNumber`** (haul rows) = total individuals caught, regardless
  of length measurement
- **Not all fish are measured** — some are too small, damaged, or
  unmeasurable

This is **expected behavior in real DATRAS data**, not an error.

### Weaknesses

1.  **Redundancy eliminated** — you can’t reconstruct the original HL
    from type=“haul” rows alone (species/sex/category grouping is lost)
2.  **Inference required** — if you need to know which fish went
    unmeasured, you’d need to rejoin to raw HL
3.  **Trade-off**: smaller, cleaner file vs. lose granular subsampling
    details

## When to use each type

| Need | Use | Example |
|----|----|----|
| Length structure, zero-filled per haul | expand type=“length” to full length×haul grid | ALK, maturity ogive |
| Haul-level CPUE, zero-filled per species | type=“haul” + zero-fill across species | CPUE index, stock assessment |
| All caught species (even unmeasured) | type=“haul” species list | ecosystem analysis |
| Know which fish went unmeasured | rejoin to raw HL | detailed QA/QC |

## Sampling protocol flags

The output carries two haul-level flags, `StandardSpeciesCode` and
`BycatchSpeciesCode`, that document what the vessel was required to
record. These can substantially affect any analysis that depends on
species presence or zero-hauls. See the [Sampling
protocols](https://einarhjorleifsson.github.io/imbus/DATRAS/sampling_protocol.html)
article in the IMBUS documentation for a detailed treatment, including
examples of how ignoring these flags leads to phantom zeros and biased
CPUE indices.

To exclude hauls with incomplete recording before zero-filling:

``` r

hl_std <- dr_standardize_hl(hh, hl)

complete_hauls <- hl_std |>
  filter(type == "haul",
         StandardSpeciesCode == "1",   # full standard species list
         BycatchSpeciesCode  != "0")   # some bycatch recording done
```

## Implementation

`dr_standardize_hl(hh, hl, species = NULL, haulval = NULL)` takes: -
`hh`: haul header table (with DataType, HaulDuration,
StandardSpeciesCode, BycatchSpeciesCode) - `hl`: length table (with
NumberAtLength, TotalNumber, etc.) - `species`: species lookup (defaults
to `dr_con("species")`) - `haulval`: optional haul validity filter
(e.g. `"V"` only)

Output: lazy DuckDB table with 18 columns and two row types. Can be
written to parquet:

``` r

hl_std <- dr_standardize_hl(hh, hl) |>
  arrow::write_parquet("hl_standardized.parquet")
```

## Why now?

The standardized HL solves a user experience problem that has existed
since DATRAS was published. By pre-computing the hard parts (scaling,
naming, deduplication), we let users focus on their actual questions:
population dynamics, recruitment, gear selectivity, etc. — not on
decoding DATRAS conventions.
