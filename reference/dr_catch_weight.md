# Get catch weights

Calculate the total reported catch numbers and weight by species and
haul.

## Usage

``` r
dr_catch_weight(latin, not_numbers = TRUE)
```

## Arguments

- latin:

  Latin species name

- not_numbers:

  A boolean (default TRUE), indicating if total abundance (TotalNo)
  should also be calculated

## Value

A DuckDB view

## Details

The functions is supposed to give the same results as
icesDatras::getCatchWgt. If argument "not_numbers" is set to FALSE this
may though not hold true.
