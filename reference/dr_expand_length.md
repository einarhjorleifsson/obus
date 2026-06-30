# Full length-bin expansion with zero-fill across hauls

Expands
[`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
output to a complete haul \\\times\\ length-bin grid: every length class
observed for a species anywhere in a Survey/Year/Quarter is propagated
to all hauls in that SQY, with zeros where absent. Works with one or
more species; filter to a single species before calling to keep the
result manageable.

## Usage

``` r
dr_expand_length(catch, hh)
```

## Arguments

- catch:

  A length-frequency catch table — typically
  `dr_standardize_hl(...) |> dplyr::filter(type == "length")`, or the
  deprecated
  [`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
  output. Must carry columns `.id`, `Survey`, `Year`, `Quarter`,
  `aphia`, `latin`, `species`, `length_mm`, `length_cm`, `accuracy`,
  `n_haul`, `n_hour`, `SpeciesValidity`.

- hh:

  DATRAS haul header table providing the full haul list. Required
  columns: `.id`, `Survey`, `Year`, `Quarter`.

## Value

A lazy DuckDB table with one row per `.id` \\\times\\ `aphia` \\\times\\
`length_mm`. `n_haul` and `n_hour` are `0` and `SpeciesValidity` is `NA`
for zero rows.

## See also

[`dr_standardize_hl`](https://einarhjorleifsson.github.io/obus/reference/dr_standardize_hl.md),
[`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
