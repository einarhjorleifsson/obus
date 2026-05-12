# Set column types from the dr_lookup_fields specification

Coerces columns in a DATRAS exchange table to the types specified in
[dr_lookup_fields](dr_lookup_fields.md). Also replaces literal `"NA"`
strings with real `NA` before coercion.

## Usage

``` r
dr_settypes(d, name_col = "new", recordheader = NULL)
```

## Arguments

- d:

  A data frame or `tbl_lazy` (DATRAS exchange table).

- name_col:

  `"new"` (default) to match new-style column names as returned by
  `get_datras_unaggregated_data` / parquet; `"old"` to match old-style
  names as returned by `getDATRAS` and derived products.

- recordheader:

  If not `NULL`, restrict the lookup to a single record type (e.g.
  `"HH"`, `"CPUEL"`). `NULL` borrows types from all tables.

## Value

An object of the same class as `d`.
