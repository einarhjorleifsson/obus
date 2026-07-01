# Standardized HL: design rationale and implementation

## The problem with raw DATRAS HL

The DATRAS HL (length) table mixes three different kinds of information
in the same rows:

1.  **Length-frequency measurements** — `NumberAtLength` per length
    class, the distribution of fish by size
2.  **Haul-level bookkeeping** — `TotalNumber` and
    `SpeciesCategoryWeight`, the totals for the whole haul
3.  **Subsampling metadata** — `SubsamplingFactor`, `DataType`,
    `HaulDuration`, the procedural information about how the
    measurements relate to the totals

Once standardized and scaled appropriately, the third kind of
information becomes redundant for downstream analysis — users can work
with clean, already-scaled counts without needing to understand
subsampling procedures. (Subsampling metadata does retain QA/QC value if
needed; in that case, users would refer directly to raw HL rather than
the standardized table.)

On top of this mixing, the value of one variable often requires
knowledge of values in other variables:

- `LengthClass` value depends on `LengthCode` (is it mm? 0.5 cm? cm?)
- `NumberAtLength` meaning depends on `DataType` (is it raw count? CPUE?
  subsampled?) and `HaulDuration`, variables that are in another table
  (HH).
- `TotalNumber` and `SpeciesCategoryWeight` are repeated on every length
  row, creating redundancy. The meaning of these values also depends on
  `DataType` and `HaulDuration`.
- `aphia` is a code; users think in species names (latin or common
  names).
- Supporting columns (`LengthCode`, `SubsamplingFactor`) exist only to
  compute other variables — once length is standardised to one unit (mm
  or cm) and counts (`n_haul`, `n_hour`) are derived from them, they add
  no further information.

The general user of DATRAS data shouldn’t need to understand these
interdependencies. All they want is to start off with clean,
self-contained data — a data construct that is almost self-explanatory.

## Design

### What a clean table needs to look like

Users shouldn’t need to carry the interdependencies above in their head.
What they need is a single table where:

- **every variable has one, unambiguous meaning** — `length_mm` is
  always millimeters, not conditional on `LengthCode`
- **species are identified by name**, not just a numeric `aphia` code
- **length measurements and haul-level counts stay distinguishable**,
  not silently mixed into the same rows
- **the table is computed once and reused** across analyses, instead of
  every analysis re-deriving units, joins, and scaling from raw HH/HL

### Row structure: from raw HL to standardized

Raw HL’s row key includes multiple dimensions beyond haul, species, and
length: `sex`, `DevelopmentStage`, and (implicitly) which counting
source the row came from. On top of that, some HH-level columns get
carried onto every HL row. The standardized HL restructures all of this
through four distinct decisions.

**Keep: both counting paths, distinguished by `type`**

`NumberAtLength` (the raw length-frequency count) and `TotalNumber` (the
haul-level total) represent the same underlying count for a haul ×
species, but aren’t directly comparable. `NumberAtLength`’s meaning
depends on `DataType`: `R`/`P`/`S` report a raw, per-haul count
(differing only in subsampling correction), while `C` reports a
pre-raised catch-per-hour rate. Hauls also towed for different durations
(`HaulDuration`), so even per-haul counts need scaling to be comparable.
`TotalNumber` is independently reported with the same
`DataType`/`HaulDuration` dependency.

Rather than picking one source and discarding the other, the design
computes `n_haul`/`n_hour` from *both* — one scaled to represent the
actual haul as towed, one scaled to represent a standard one-hour catch
(catch-per-unit-effort) — and tags which source each row came from with
a `type` column:

- `type == "length"`: `n_haul`/`n_hour` derived from `NumberAtLength`.
- `type == "haul"`: `n_haul`/`n_hour` derived from `TotalNumber`.

Same column names, same units, two different upstream sources — that’s
exactly what `type` disambiguates. This leads directly to the row count:
exactly one `type="haul"` row per haul × species, plus one
`type="length"` row per distinct length class for that species in that
haul. So a species with no length measurements contributes only its
`type="haul"` row; one with 12 length classes contributes 1 + 12 = 13
rows. A plain row count over the combined table is therefore not
comparable to a row count over raw HL — always split by `type` first.

**Why one table, two types, instead of two separate files?**

- **Simplicity** — users interact with one output, not two files to keep
  in sync
- **Completeness** — every caught species is present (via its
  `type="haul"` row) even when never measured at length
- **Self-documenting** — the `type` flag makes the two-counting-paths
  contract explicit
- **Reproducibility** — everyone downstream works from the same
  standardized source

**Collapse: sex into a single proportion per haul × species × length**

Raw HL’s row key also includes `sex`: the same haul × species × length
can appear as multiple rows, split by sex (`F`, `M`, `B`, or
unrecorded). On a single survey-quarter (NS-IBTS 2015 Q1), 653 of 51,685
distinct haul × species × length combinations are split across 2 rows,
and 2 are split across 3 — so `length_mm` alone is not a unique row key.

Keeping that split means every downstream length-based calculation — a
length-frequency plot, an age-length key, a maturity ogive — has to
decide for itself what to do with `sex`: drop it, or carry it through
every
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html). The
alternative this design takes is to collapse the sex dimension into a
single derived number per haul × species × length: the proportion of
sexed fish that are female. That’s enough to recover both sex-specific
counts later (`n_female = n_haul * p`, `n_male = n_haul * (1 - p)`)
without carrying a `sex` column through every row, at the cost of losing
anything more detailed than a two-way split. In the standardized output,
this proportion is stored in a column called `p_females`.

`p_females` follows the same two-counting-paths pattern as
`n_haul`/`n_hour`: each `type` computes it independently from its own
source column (`sex` split on `NumberAtLength` vs. on `TotalNumber`),
not derived from the other type. Where both exist for the same haul ×
species they agree closely within rounding. `p_females` is `NA` when no
fish in the group were sexed, and counts `sex ∈ {"F", "M", "B"}` — `"B"`
(Berried/egg-bearing) is a known-female state and counts as female.

**Drop: DevelopmentStage entirely**

`DevelopmentStage` is a second row-splitting column in raw HL, but it is
handled differently: dropped entirely rather than collapsed into a
summary. Unlike `sex`, it’s almost always missing — across 2010-2020 raw
HL, 99.7% of records have `DevelopmentStage = NA`, with the remaining
0.3% split across just three codes (`B`, `E`, `J`):

``` r

hl |> count(DevelopmentStage) |> mutate(p = n / sum(n))
```

Because it varies within a haul × species group so rarely, any variation
that does exist is silently summed over during aggregation — there is no
`p_developmentstage` equivalent to `p_females`. If `DevelopmentStage`
matters for your analysis (e.g. distinguishing berried females for some
crustaceans), don’t rely on the standardized HL for it — go back to raw
HL.

**Drop: `StandardSpeciesCode`/`BycatchSpeciesCode`**

These are haul-level flags from HH recording what a vessel was required
to record for that haul — not anything about an individual species
catch. They are not carried into the standardized output, because obus’s
current zero-filling doesn’t use them. See [Catch
products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd#which-hauls-get-a-zero-row)
for what these flags are for, why they’re not part of zero-filling yet,
and how to bring them back in from HH if you need them.

### Length totals vs. haul totals should match

The two counting paths — one from length-frequency measurements, one
from haul-level totals — should yield the same count for a given haul
and species. This isn’t just a design claim; it’s checkable directly on
the standardized table. In practice, `n_haul` summed across
`type="length"` rows (subsampling-corrected `NumberAtLength`) and
`n_haul` from the matching `type="haul"` row (`TotalNumber`) should
agree within rounding:

``` r

library(obus)
library(dplyr)

hh <- dr_con("HH")
hl <- dr_con("HL")

hl_std <- dr_standardize_hl(
  hh |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015, HaulValidity == "V") |> head(10),
  hl |> filter(Survey == "NS-IBTS", Quarter == 1, Year == 2015)
) |> collect()

length_total <- hl_std |>
  filter(type == "length", .id == hl_std$.id[1]) |>
  group_by(.id, species) |>
  summarise(n_haul_from_length = sum(n_haul, na.rm = TRUE), .groups = "drop")

haul_total <- hl_std |>
  filter(type == "haul", .id == hl_std$.id[1]) |>
  select(.id, species, n_haul)

full_join(length_total, haul_total, by = c(".id", "species")) |>
  head(5)
```

    # A tibble: 5 × 4
      .id                                  species         n_haul_from_length n_haul
      <chr>                                <chr>                        <dbl>  <dbl>
    1 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 American plaice                 21     21
    2 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic cod                    47     47
    3 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic herri…                  1      1
    4 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic horse…                 20     20
    5 NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13 Atlantic macke…                  1      1

A persistent, non-trivial mismatch is not a feature of the data design —
it points to an inconsistency in the original DATRAS submission for that
haul (`TotalNumber` not reconciled with the underlying length
measurements).
[`dr_check_totalno()`](https://einarhjorleifsson.github.io/obus/reference/dr_check_totalno.md)
flags this directly; in practice it affects roughly 1% of records,
almost all small rounding differences under DataType C.

### Trade-offs: this is not tidy data

The three rules of [tidy
data](https://tidyr.tidyverse.org/articles/tidy-data.html) are:

1.  Each variable is a column; each column is a variable.
2.  Each observation is a row; each row is an observation.
3.  Each value is a cell; each cell is a single value.

The standardized HL breaks rule 1: `n_haul` and `n_hour` are a single
column each, but their meaning (and their upstream source column)
depends on the value of `type` in that row — `type` is really a second,
hidden variable folded into what looks like one measurement column. The
table also has columns that are structurally `NA` depending on `type` —
`length_mm`/`length_cm`/`accuracy` for `type="haul"` rows,
`w_haul`/`w_hour` for `type="length"` rows — the classic symptom of
stacking two different observation types into one table (rule 2) instead
of keeping them separate.

**The biggest con is exactly that: this is not tidy data**, and code
consuming the standardized HL has to know about `type` before touching
`n_haul`/`n_hour`/`length_mm`/`w_haul` at all — the columns alone don’t
tell you. Two further, smaller costs: you can’t reconstruct the original
HL from `type="haul"` rows alone (species/sex/category grouping is
lost), and if you need to know which fish went unmeasured, you’d have to
rejoin to raw HL.

**The biggest pro is that it’s still less messy than raw HL.** Raw HL
mixes length-frequency rows and haul-bookkeeping columns in every single
row, with unit ambiguity resolved nowhere. The standardized HL moves
that ambiguity into exactly one place — the `type` column — instead of
spreading it across numerous interacting columns.

Would `filter(type=="length")` and `filter(type=="haul")`, kept as two
separate tables, actually be tidy? Yes — once `type` and the columns
that are always `NA` for that type are dropped (`w_haul`/`w_hour` from
the length table; `length_mm`/`length_cm`/`accuracy` from the haul
table), each remaining column means exactly one thing again, and each
row is unambiguously one observation. One lingering redundancy —
`aphia`/`latin`/`species` as three columns for one species identity —
looks untidy but isn’t: tidy data and database normalization are
different concerns, and repeated values across rows don’t violate any of
the three rules. So the split would produce two genuinely tidy tables,
at the cost of the one-table simplicity described above. That trade was
made deliberately, but it is a trade, not a free win, and feedback on
whether it’s the right one is welcome.

## Using `dr_standardize_hl()`

`dr_standardize_hl(hh, hl, species = NULL, haulval = NULL)` implements
the design above from raw HH and HL:

- `hh`: haul header table (with `DataType`, `HaulDuration`)
- `hl`: length table (with `NumberAtLength`, `TotalNumber`, etc.)
- `species`: species lookup (defaults to `dr_con("species")`)
- `haulval`: optional haul validity filter (e.g. `"V"` only)

Output: a lazy DuckDB table with 17 columns and two row types.

``` r

glimpse(hl_std)
```

    Rows: 2,106
    Columns: 17
    $ .id             <chr> "NS-IBTS:2015:1:GB-SCT:748S:GOV:13:13", "NS-IBTS:2015:…
    $ Survey          <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS",…
    $ Year            <dbl> 2015, 2015, 2015, 2015, 2015, 2015, 2015, 2015, 2015, …
    $ Quarter         <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ aphia           <int> 150637, 126822, 126426, 127136, 126445, 126555, 127214…
    $ latin           <chr> "Eutrigla gurnardus", "Trachurus trachurus", "Engrauli…
    $ species         <chr> "grey gurnard", "Atlantic horse mackerel", "anchovy", …
    $ type            <chr> "length", "length", "length", "length", "length", "len…
    $ length_mm       <int> 270, 140, 140, 310, 220, 420, 300, 420, 280, 550, 340,…
    $ length_cm       <dbl> 27, 14, 14, 31, 22, 42, 30, 42, 28, 55, 34, 11, 38, 51…
    $ accuracy        <dbl> 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,…
    $ n_haul          <dbl> 19, 3, 1, 1, 1, 1, 1, 3, 3, 1, 6, 2, 1, 1, 1, 7, 1, 1,…
    $ n_hour          <dbl> 38, 6, 2, 2, 2, 2, 2, 6, 6, 2, 12, 4, 2, 2, 2, 14, 2, …
    $ w_haul          <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
    $ w_hour          <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
    $ p_females       <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
    $ SpeciesValidity <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1",…

`filter(type == "length")` feeds directly into
[`dr_catch_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
and
[`dr_expand_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
for zero-filling; `filter(type == "haul")` gives haul-level numbers and
weights. See [Catch
products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd)
for worked zero-fill examples.

| Need | Use | Example |
|----|----|----|
| Length structure, zero-filled per haul | `filter(type=="length")` → `dr_expand_length(hh)` | ALK, maturity ogive |
| Haul-level CPUE, zero-filled per species | `filter(type=="length")` → `dr_catch_by_haul(hh)` | CPUE index, stock assessment |
| Haul totals with weight | `filter(type=="haul")` | biomass index |
| Sex composition at length | `filter(type=="length")` → use `p_females` | sex-ratio at size — see [Catch products](https://einarhjorleifsson.github.io/obus/articles/catch_products.qmd) |
| All caught species (even unmeasured) | `filter(type=="haul")` species list | ecosystem analysis |
| Know which fish went unmeasured | rejoin to raw HL | detailed QA/QC |

Since the output is designed to be computed once and reused, it’s
typically written to disk rather than recomputed per analysis:

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
