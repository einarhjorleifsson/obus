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

The input table with additional columns `n_haul` and `n_hour`.

## Details

For `DataType == "R"`, a missing (NA) `SubsamplingFactor` is treated as
1, meaning no subsampling correction is applied. This matches the
convention in the DATRAS R package and reflects the assumption that
absence of a subsampling factor implies the full catch was measured. For
all other DataTypes, NA `SubsamplingFactor` propagates to NA `n_haul`.
