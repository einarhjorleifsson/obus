# Create a DuckDB connection to a DATRAS dataset (latin names included)

This function creates a URL for a DATRAS dataset based on the input
`type` and opens the dataset using the
[`duckdbfs::open_dataset`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
function. The type must be one of "HH", "HL", or "CA".

## Usage

``` r
dr_con(type = NULL, trim = TRUE)
```

## Arguments

- type:

  A character string specifying the type of the dataset. Must be one of
  "HH", "HL", or "CA".

- trim:

  A boolean (default TRUE) which removes station variables from the HL
  and CA data, the join be made via the ".id" variable.

## Value

A DuckDB dataset object.

## Details

The connection is to an experimental table setup that includes latin
name in the HL and CA files

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con("HH")
} # }
```
