# Translate column names of a data.frame or lazy tibble using a dictionary

This function allows renaming column names in an input object (a
`data.frame` or `tbl_lazy`) by translating them with a user-supplied
dictionary. Users can choose to translate column names from "old" to
"new" or vice versa.

## Usage

``` r
dr_translate(d, dictionary, from = "old", to = "new")
```

## Arguments

- d:

  A `data.frame` or `tbl_lazy` object whose column names need to be
  translated.

- dictionary:

  A `data.frame` (or tibble) with at least two columns: `from` and `to`
  (default names are "old" and "new"). The `from` column contains the
  current column names in `d`, and the `to` column contains the new
  column names to translate to.

- from:

  A string specifying the column name in `dictionary` to use for current
  column name matching. Defaults to "old".

- to:

  A string specifying the column name in `dictionary` with new column
  names to translate to. Defaults to "new".

## Value

An object of the same class as `d` with column names translated.

## Examples

``` r
# Example dictionary
dictionary <- data.frame(
    old = c("Ship", "SweepLngt"),
    new = c("Platform", "SweepLength")
)
# Example data
df <- data.frame(Ship = "26D4", SweepLngt = 110)

dr_translate(df, dictionary)
#>   Platform SweepLength
#> 1     26D4         110
```
