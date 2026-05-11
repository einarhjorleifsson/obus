# Lookup table for HL record types

A tibble describing the integer codes assigned by
[`dr_add_record_type`](dr_add_record_type.md). Each row defines one
record type with a short label and a description of the variable pattern
that defines it.

## Usage

``` r
hl_record_type_lookup
```

## Format

A tibble with columns:

- record_type:

  Integer code.

- lc_present:

  Logical; whether `LengthClass` is present for this type.

- label:

  Short human-readable label.

- description:

  Full description of the variable pattern.
