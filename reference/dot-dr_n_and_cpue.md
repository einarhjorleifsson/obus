# Numbers caught and the CPUE in each length class

This function generates two new column `n` (numbers caught) and `cpue`
(numbers caught per one hour towing) for the length table (HL).

## Usage

``` r
.dr_n_and_cpue(d)
```

## Arguments

- d:

  DATRAS length table (HL) containing columns `.id`, `HLNoAtLngt`,
  `.datatype`, and `.effort`.

## Value

The input table with additional columns `n` and `cpue`.
