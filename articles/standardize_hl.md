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
written once and reused across many analyses. It is also the recommended
starting point for interactive work: `filter(type == "length")` output
feeds directly into
[`dr_catch_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
and
[`dr_expand_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
for zero-filling, while `filter(type == "haul")` gives haul-level
numbers and weights with protocol metadata (`StandardSpeciesCode`,
`BycatchSpeciesCode`) attached. See [Catch
products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd)
for worked zero-fill examples.

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
library(ggplot2)

hh <- dr_con("HH")
hl <- dr_con("HL")

# Generate standardized HL for a small example
hl_std <- dr_standardize_hl(
  hh |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015, HaulValidity == "V") |> head(10),
  hl |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015)
) |> collect()

cat("Standardized HL rows:", nrow(hl_std), "\n")
```

    Standardized HL rows: 2106 

``` r

cat("Type breakdown:\n")
```

    Type breakdown:

``` r

print(table(hl_std$type))
```


      haul length
       266   1840 

## Two row types, one table

The standardized HL has a `type` flag that separates two fundamentally
different data:

``` r

length_rows <- hl_std |> filter(type == "length") |> head(3)
cat("Type='length' rows — length-frequency measurements:\n")
```

    Type='length' rows — length-frequency measurements:

``` r

print(length_rows |> select(.id, species, length_mm, n_haul, n_hour, p_females))
```

    # A tibble: 3 × 6
      .id                                  species length_mm n_haul n_hour p_females
      <chr>                                <chr>       <int>  <dbl>  <dbl>     <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlant…       140      3      6        NA
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:9:9   bib           220      1      2        NA
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlant…       190      1      2        NA

``` r

haul_rows <- hl_std |> filter(type == "haul") |> head(3)
cat("\nType='haul' rows — haul-level bookkeeping (deduplicated):\n")
```


    Type='haul' rows — haul-level bookkeeping (deduplicated):

``` r

print(haul_rows |> select(.id, species, n_haul, w_haul, p_females))
```

    # A tibble: 3 × 5
      .id                                  species           n_haul w_haul p_females
      <chr>                                <chr>              <dbl>  <dbl>     <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 blue whiting          15    360        NA
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:7:7   grey gurnard         539  18110        NA
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Corbin's sand eel      1     36        NA

`p_females` encodes sex composition as a single proportion:
`n_F / (n_F + n_M)` computed from fish with recorded sex (`sex` ∈
`{"F", "M"}`). It is `NA` when no fish in the group were sexed (unsexed
catches, `"B"`, `"U"`). Males and females can be recovered downstream:

``` r

filter(type == "length") |>
  mutate(n_females = n_haul * p_females,
         n_males   = n_haul * (1 - p_females))
```

**Why two types in one table?**

1.  **Simplicity**: users interact with one parquet file
2.  **Flexibility**: users choose which data to use downstream
3.  **Completeness**: preserves all caught species (even those not
    measured at length)
4.  **Zero-fill**: type=“length” feeds
    [`dr_catch_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
    and
    [`dr_expand_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
    unchanged

For worked examples that build survey indices on top of these two row
types — CPUE, length distributions, sex-specific indices using
`p_females` — see [Catch
products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd).

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
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 American plaice                161    161
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlantic cod                     4      4
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlantic herri…                  3      3
    4 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlantic horse…                  9      9
    5 NS-IBTS:2015:1:GB-SCT:748S:GOV:12:12 Atlantic macke…                  2      2

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
| Length structure, zero-filled per haul | `filter(type=="length")` → `dr_expand_length(hh)` | ALK, maturity ogive |
| Haul-level CPUE, zero-filled per species | `filter(type=="length")` → `dr_catch_by_haul(hh)` | CPUE index, stock assessment |
| Haul totals with weight | `filter(type=="haul")` | biomass index |
| Sex composition at length | `filter(type=="length")` → use `p_females` | sex-ratio at size — see [Catch products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd) |
| All caught species (even unmeasured) | `filter(type=="haul")` species list | ecosystem analysis |
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

Output: lazy DuckDB table with 19 columns and two row types. Can be
written to parquet:

``` r

dr_standardize_hl(hh, hl) |>
  dplyr::collect() |>
  arrow::write_parquet("hl_standardized.parquet")
```

## Why now?

The standardized HL solves a user experience problem that has existed
since DATRAS was published. By pre-computing the hard parts (scaling,
naming, deduplication), we let users focus on their actual questions:
population dynamics, recruitment, gear selectivity, etc. — not on
decoding DATRAS conventions.
