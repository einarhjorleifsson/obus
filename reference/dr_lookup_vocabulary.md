# ICES vocabulary lookup table for DATRAS fields

Valid codes and their descriptions for the categorical fields used in
DATRAS exchange data, sourced from the ICES vocabulary server. Only
fields present in `dr_lookup_fields` (old-style names) are retained;
calendar fields (`Month`, `Quarter`, `Year`) are excluded. Regenerate
with `data-raw/DATASET_vocabulary.R`.

## Usage

``` r
dr_lookup_vocabulary
```

## Format

An object of class `tbl_df` (inherits from `tbl`, `data.frame`) with
10328 rows and 6 columns.

## Source

`icesVocab::getCodeTypeList()` and `icesVocab::getCodeList()` via the
ICES vocabulary server <https://vocab.ices.dk/>.

## Details

A data frame with 6 columns:

- old:

  Legacy DATRAS column name (as returned by
  [`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html)
  and derived products).

- new:

  Standard column name as used in the parquet files; `NA` where no
  mapping exists.

- key:

  The valid code value (character) as it appears in the data, e.g.
  `"V"`, `"GOV"`, `"M"`.

- description:

  Human-readable label for the code, e.g. `"Valid haul"`,
  `"Grand Opening Vertical trawl"`.

- type:

  ICES vocabulary type key, e.g. `"TS_HaulVal"`, `"Gear"`. Prefixes
  `TS_` and `AC_` are stripped when matching against `old` column names.

- type_desc:

  Human-readable description of the vocabulary type, e.g.
  `"Haul Validity Codes"`, `"Gear Types"`.
