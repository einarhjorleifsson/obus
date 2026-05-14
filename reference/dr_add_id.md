# Generate a unique haul id

Generates a haul ID by concatenating the eight join-key fields and
stores it in a new column `.id`. Works with both new-style column names
(`Platform`, `StationName`, `HaulNumber`) and old-style names (`Ship`,
`StNo`, `HaulNo`).

## Usage

``` r
dr_add_id(d, base = "auto")
```

## Arguments

- d:

  A DATRAS table, one of HH, HL, or CA.

- base:

  One of `"auto"` (default), `"new"`, or `"old"`. `"auto"` inspects
  column names and chooses based on which style is present: `Ship` -\>
  old, `Platform` -\> new. An error is raised if neither or both are
  found.

## Value

A table (`d`) with an additional variable `.id`

## Examples

``` r
# New-style column names
example_new <- data.frame(
  Survey = "Surv1", Year = 2026, Quarter = 1, Country = "Country1",
  Platform = "Vessel1", Gear = "GOV", StationName = "1", HaulNumber = 1L
)
example_new |> dr_add_id()
#>   Survey Year Quarter  Country Platform Gear StationName HaulNumber
#> 1  Surv1 2026       1 Country1  Vessel1  GOV           1          1
#>                                     .id
#> 1 Surv1:2026:1:Country1:Vessel1:GOV:1:1

# Old-style column names
example_old <- data.frame(
  Survey = "Surv1", Year = 2026, Quarter = 1, Country = "Country1",
  Ship = "Vessel1", Gear = "GOV", StNo = "1", HaulNo = 1L
)
example_old |> dr_add_id()
#>   Survey Year Quarter  Country    Ship Gear StNo HaulNo
#> 1  Surv1 2026       1 Country1 Vessel1  GOV    1      1
#>                                     .id
#> 1 Surv1:2026:1:Country1:Vessel1:GOV:1:1
```
