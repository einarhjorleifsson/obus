# Create a DuckDB connection to a DATRAS dataset (exchange format)

This function establishes a DuckDB connection to DATRAS exchange-format
data based on the specified `type`. The dataset is accessed via a URL
and opened using the
[`duckdbfs::open_dataset`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
function.

## Usage

``` r
dr_con_exchange(type = NULL, url = "https://heima.hafro.is/~einarhj/datras/")
```

## Arguments

- type:

  A character string specifying the type of dataset. Must be `"HH"`,
  `"HL"`, or `"CA"`. This parameter maps to specific file types stored
  in the DATRAS data source.

- url:

  The http path to the DATRAS parquet files

## Value

A DuckDB dataset object representing the combined data for the specified
`type`.

## Datapath Explanation

The function constructs a URL for the dataset as:
"https://heima.hafro.is/~einarhj/datras/RecordType=`{type}`/Year=`{year}`/part-0.parquet".
The `type` parameter determines the file category (e.g., "HH", "HL",
"CA"). The function dynamically generates URLs for all years between
1965 and 2025. The DATRAS exchange dataset includes the following:

- `"HH"` refers to haul-level data.

- `"HL"` refers to catch-at-length data.

- `"CA"` refers to age-based biological sampling data.

## Examples

``` r
if (FALSE) { # \dontrun{
  dr_con_exchange("HH")  # Connect to haul-level data for all years.
  dr_con_exchange("CA")  # Connect to age-based biological data for all years.
} # }
```
