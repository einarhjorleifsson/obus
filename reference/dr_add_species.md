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
  Defaults to `dr_con("species")`, a lazy DuckDB connection to the
  species parquet on the obus server.

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
