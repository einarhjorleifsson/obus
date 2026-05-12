# DATRAS field type lookup table

A table of column names and their data types across all DATRAS record
types. Used internally by `.dr_settypes()` to coerce columns to
consistent types after fetching data. Regenerate with
`data-raw/DATASET_lookup_fields.R`.

## Usage

``` r
dr_lookup_fields
```

## Format

An object of class `tbl_df` (inherits from `tbl`, `data.frame`) with 292
rows and 5 columns.

## Source

<https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList>
plus hand-curated entries for FL, LT, CPUEL, CPUEA, and IDX.

## Details

A data frame with 5 columns:

- table:

  Record type: "HH", "HL", "CA", "FL", "LT", "CPUEL", "CPUEA", "IDX"

- new:

  Column name as returned by `icesDatras::get_datras_unaggregated_data`
  (new-style)

- old:

  Column name as returned by
  [`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
  and derived products (old-style)

- format:

  Type: "chr", "int", or "dbl"

- description:

  Field description from the ICES web service
