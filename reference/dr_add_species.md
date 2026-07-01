# Add species names to a DATRAS table

Joins the WoRMS-accepted Latin name and common name onto any table that
contains an `aphia` column, using a left join so that rows with no match
are retained with `NA` in the new columns.

## Usage

``` r
dr_add_species(x, species = NULL)
```

## Arguments

- x:

  A data frame or DuckDB lazy table with an `aphia` column.

- species:

  Species lookup table with columns `aphia`, `latin`, and `species`.
  Defaults to matching `x`'s backend: the bundled
  [`dr_lookup_species`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_species.md)
  data frame when `x` is an eager data frame (e.g. from
  [`dr_get`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)),
  or `dr_con("species")` (a lazy DuckDB connection) when `x` is a lazy
  table (e.g. from
  [`dr_con`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md))
  – avoids an "x and y must share the same src" error from joining an
  eager table against a lazy one.

## Value

`x` with two additional columns:

- latin:

  WoRMS-accepted Latin name.

- species:

  Common name.

Rows whose `aphia` code is absent from the lookup table are kept with
`NA` in both new columns.

## Examples

``` r
if (FALSE) { # \dontrun{
hl <- dr_get("HL", surveys = "NS-IBTS", years = 2023, quarters = 1)
hl |> dr_add_species()
} # }
```
