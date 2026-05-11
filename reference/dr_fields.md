# Datras variable types

A table containing the variable (field) types of the datras data

## Usage

``` r
dr_fields
```

## Format

An object of class `tbl_df` (inherits from `tbl`, `data.frame`) with 214
rows and 5 columns.

## Source

<https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList>
and then some

## Details

A data frame with 208 rows and 5 columns:

- RecordHeader:

  The DATRAS data type - "HH": haul data, "HL": length-based data, "CA":
  age-based data

- FieldName:

  DATRAS variable name as returned by
  icesDatras::get_datras_unaggregated_data

- FieldNameOld:

  DATRAS variable name as returned by icesDatras::getDatras

- DataFormat:

  The value type, char (character), int (ingeger) and decimal (numeric)

- Description:

  Some description
