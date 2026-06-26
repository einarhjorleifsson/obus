# HL record type lookup table

A data frame describing the integer codes assigned by
[`dr_add_record_type`](https://einarhjorleifsson.github.io/obus/reference/dr_add_record_type.md).
Each row defines one record type by its short label, whether
`LengthClass` is present, and a detailed description of the
variable-presence pattern that defines it.

## Usage

``` r
dr_lookup_hl_record_type
```

## Format

A data frame with 12 rows and 4 columns:

- record_type:

  Integer code (1–4, 10–16, 99).

- lc_present:

  Logical; `TRUE` when `LengthClass` is present (types 1–4), `FALSE`
  otherwise.

- label:

  Short human-readable label, e.g. `"Length-frequency, standard"`.

- description:

  Full description of the variable-presence pattern that defines the
  type.

## Details

Regenerate with `data-raw/DATASET_hl-record-types.R`.

## See also

[`dr_add_record_type`](https://einarhjorleifsson.github.io/obus/reference/dr_add_record_type.md)
