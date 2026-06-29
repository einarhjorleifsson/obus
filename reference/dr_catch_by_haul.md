# Haul-level CPUE with zero-fill across species

Collapses the length structure of
[`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
output to total CPUE per haul per species, then zero-fills: every
species observed anywhere in a Survey/Year/Quarter gets an explicit zero
row for each haul in that SQY where it was absent. Works with one or
more species.

## Usage

``` r
dr_catch_by_haul(catch, hh)
```

## Arguments

- catch:

  Output of
  [`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
  (or a filtered subset).

- hh:

  DATRAS haul header table providing the full haul list. Required
  columns: `.id`, `Survey`, `Year`, `Quarter`.

## Value

A lazy DuckDB table with one row per `.id` \\\times\\ `aphia`: `.id`,
`Survey`, `Year`, `Quarter`, `aphia`, `latin`, `species`, `n_haul`,
`n_hour`. `n_haul` and `n_hour` are `0` for zero rows.

## See also

[`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md),
[`dr_expand_length`](https://einarhjorleifsson.github.io/obus/reference/dr_expand_length.md)
