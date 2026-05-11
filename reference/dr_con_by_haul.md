# Get numbers and weights summary of species by haul

This function calculates and summarizes the total numbers and weights of
species reported in a survey. By processing fishing haul-level (HH) and
catch-level (HL) data, it generates the aggregate number (`n_haul`) and
weight (`w_haul`) of species caught per haul, alongside estimates
standardized to a 1-hour haul duration (`n_hour`, `w_hour`).

## Usage

``` r
dr_con_by_haul(
  latin = "Melanogrammus aeglefinus",
  trim = TRUE,
  method = "ices"
)
```

## Arguments

- latin:

  xxxx

- trim:

  Boolean (default TRUE), controls if additional non-essential variables
  are returned or not.

- method:

  xxx

## Value

A summarized `data.frame` with the following columns:

- `.id`: Unique haul identifier.

- `latin`: Latin species name, identifying the species.

- `n_haul`: Actual number of individuals per haul.

- `w_haul`: Actual weight (kg) per haul.

- `n_hour`: Number of individuals raised to a 1-hour haul.

- `w_hour`: Weight (kg) raised to a 1-hour haul.

If trim is FALSE then additional variables return

- `TotalNumber`: Total number of individuals of the species caught -
  nonstandardized.

- `SpeciesCategoryWeight`: Total weight (kg) of the species caught -
  nonstandardized.

- `DataType`: Type of data recording, if value is "C",
  SpeciesCategoryWeight is in unit per 60 minute hauling, otherwise unit
  is in reported haul ducation.

- `HaulDuration`: Type of data collected, e.g., raised to 1 hour or raw.

## Details

The final output is a summary by haul identifiers and species, enabling
an overview of catch numbers and weights. Additionally, the function
aims to provide similar weight calculations as
[`icesDatras::getCatchWgt`](https://rdrr.io/pkg/icesDatras/man/getCatchWgt.html),
making its results comparable to external references.

## Note

".id" are variables Survey, Year, Quarter, Country, Platform, Gear,
StationName and HaulNumber catenated, separated by ":".

## See also

[`icesDatras::getCatchWgt`](https://rdrr.io/pkg/icesDatras/man/getCatchWgt.html)
for an alternative approach to computing total catch weight by species
and haul.

[`dr_con`](dr_con.md) for information about connecting to DuckDB tables.
