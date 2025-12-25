# Create a DuckDB connection to a DATRAS dataset (exchange format)

This function creates a URL for a DATRAS eschange dataset based on the
input `type` and opens the dataset using the
[`duckdbfs::open_dataset`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
function. The type must be one of "HH", "HL", or "CA".

## Usage

``` r
dr_con_exchange(type = NULL)
```

## Arguments

- type:

  A character string specifying the type of the dataset. Must be one of
  "HH", "HL", or "CA".

## Value

A DuckDB dataset object.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con_exchange("HH")
} # }
```
