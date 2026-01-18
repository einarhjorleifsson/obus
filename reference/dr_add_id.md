# Generate a unique haul id

This function generates a haul ID by concatenating fields in the DATRAS
tables. The generated ID is stored in a new variable `.id`. The input
must contain the columns:
`Survey, Year, Quarter, Country, Platform, Gear, StationName, HaulNumber`.
If any of these columns are missing, an error will be raised.

## Usage

``` r
dr_add_id(d)
```

## Arguments

- d:

  A DATRAS table, one of HH, HL, or CA.

## Value

A table (`d`) with an additional variable `.id`

## Examples

``` r
# Example with a simulated DATRAS table
example_data <- data.frame(
  Survey = "Surv1",
  Year = 2026,
  Quarter = 1,
  Country = "Country1",
  Platform = "Platform1",
  Gear = "Gear1",
  StationName = "StationA",
  HaulNumber = 123
)
example_data |> dr_add_id()
#>   Survey Year Quarter  Country  Platform  Gear StationName HaulNumber
#> 1  Surv1 2026       1 Country1 Platform1 Gear1    StationA        123
#>                                                  .id
#> 1 Surv1:2026:1:Country1:Platform1:Gear1:StationA:123
```
