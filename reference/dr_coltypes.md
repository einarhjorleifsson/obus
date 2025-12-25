# Datras variable types

A table containing the variable (field) types of the datras data

## Usage

``` r
dr_coltypes
```

## Format

An object of class `tbl_df` (inherits from `tbl`, `data.frame`) with 159
rows and 3 columns.

## Source

<https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_May2022.xlsx>

## Details

A data frame with 125 rows and 3 columns:

- field:

  DATRAS variable name as returned by icesDatras::getDATRAS

- type:

  The value type

- record:

  The DATRAS data type - "HH": haul data, "HL": length-based data, "CA":
  age-based data
