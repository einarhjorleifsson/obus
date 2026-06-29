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

  Output of
  [`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md)
  (or a filtered subset).

- hh:

  DATRAS haul header table providing the full haul list. Required
  columns: `.id`, `Survey`, `Year`, `Quarter`.

## Value

A lazy DuckDB table with one row per `.id` \\\times\\ `aphia` \\\times\\
`length_mm`: same columns as
[`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md).
`n_haul` and `n_hour` are `0` and `SpeciesValidity` is `NA` for zero
rows.

## See also

[`dr_catch_by_length`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_length.md),
[`dr_catch_by_haul`](https://einarhjorleifsson.github.io/obus/reference/dr_catch_by_haul.md)
