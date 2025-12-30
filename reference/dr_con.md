# Create a DuckDB connection to a DATRAS Exchange dataset with Latin names included

This function establishes a DuckDB connection to a DATRAS dataset based
on the specified `type` ("HH", "HL" or "CA"). The dataset is accessed
via a URL and opened using the
[`duckdbfs::open_dataset`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
function. The function operates on experimental tables that include
Latin names in the "HL" and "CA" files.

## Usage

``` r
dr_con(
  type = NULL,
  trim = TRUE,
  url = "https://heima.hafro.is/~einarhj/datras_latin/"
)
```

## Arguments

- type:

  A character string specifying the type of dataset. Must be `"HH"`,
  `"HL"`, or `"CA"`. This parameter maps to specific files in the
  provided data source.

- trim:

  A boolean flag (default `TRUE`). If `TRUE` and the `type` is `"HL"` or
  `"CA"`, the dataset is trimmed to ignore station-level fields.

- url:

  The http path to the DATRAS parquet files

## Value

A DuckDB dataset object.

## Datapath Explanation

The function constructs a URL for the dataset based on the following
pattern:
"https://heima.hafro.is/~einarhj/datras_latin/`{type}`.parquet". The
`type` parameter determines the specific file to connect to, where:

- `"HH"` refers to haul-level data.

- `"HL"` refers to catch-at-length data.

- `"CA"` refers to age-based biological sampling data.

Optionally, for the "HL" and "CA" types, setting `trim = TRUE` (the
default) excludes station-level variables. This allows a narrower view
(read: fewer variables) of these observations, station-level variables
can be retrieved by a join to the haul table (HH) using the `.id`
column.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con("HH")              # Connect to haul-level data.
  dr_con("HL", trim=FALSE)  # Get all fields for catch-at-length data.
} # }
```
