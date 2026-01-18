# Numbers caught and the CPUE in each length class

This function generates two new columns: `n` (numbers caught) and `cpue`
(numbers caught per one hour towing) for the length table (HL).

## Usage

``` r
dr_add_n_and_cpue(
  d,
  NumberAtLength = NumberAtLength,
  HaulDuration = HaulDuration,
  SubsamplingFactor = SubsamplingFactor
)
```

## Arguments

- d:

  DATRAS length table (HL) containing columns `.id`, a column for
  `NumberAtLength`, a column for `HaulDuration`, and a column for
  `SubsamplingFactor`.

- NumberAtLength:

  The column specifying the number of individuals (unquoted). Defaults
  to `NumberAtLength`.

- HaulDuration:

  The column specifying haul duration (unquoted). Defaults to
  `HaulDuration`.

- SubsamplingFactor:

  The column specifying the subsampling factor (unquoted). Defaults to
  `SubsamplingFactor`.

## Value

The input table with additional columns `n` and `cpue`.
