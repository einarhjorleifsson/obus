
# obus

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/imbus)](https://CRAN.R-project.org/package=imbus)
<!-- badges: end -->

{obus} is a temporary experimental package used to explore various
DATRAS data connections and wrapper functions to make life a little
easier for everyday user. Some of this may be taken up in a more offical
package.

## Installation

You can install the development version of {obus} from
[GitHub](https://github.com/einarhjorleifsson/obus) with:

``` r
remotes::install_github("einarhjorleifsson/obus")
```

Because in some explorations {obus} has wrapper functions over
{icesDatras}-functions and because some modification has been done to
the latter (issues pending) for now you need to install it via:

``` r
remotes::install_github("einarhjorleifsson/icesDatras")
```

There are two ways to connect to the DATRAS data, either by importing
the whole datasets into R or by making a in-process DuckDB connection.

``` r
library(tidyverse)
library(obus)
library(icesDatras)
```

## Importing

The fastest way to import a the DATRAS tables into R is:

``` r
system.time({
  hh <- dr_get("HH", from = "parquet")
  hl <- dr_get("HL", from = "parquet")
  ca <- dr_get("CA", from = "parquet")
})
#>    user  system elapsed 
#>  18.271   5.443   3.890
hl |> glimpse()
#> Rows: 14,092,724
#> Columns: 36
#> $ RecordHeader          <chr> "﻿HL", "HL", "HL", "HL", "HL", "HL", "HL", "HL",…
#> $ Survey                <chr> "BITS", "BITS", "BITS", "BITS", "BITS", "BITS", …
#> $ Quarter               <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ Country               <chr> "DE", "DE", "DE", "DE", "DE", "DE", "DE", "DE", …
#> $ Platform              <chr> "06S1", "06S1", "06S1", "06S1", "06S1", "06S1", …
#> $ Gear                  <chr> "H20", "H20", "H20", "H20", "H20", "H20", "H20",…
#> $ SweepLength           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ GearExceptions        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DoorType              <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ StationName           <chr> "48", "48", "48", "491", "491", "491", "491", "4…
#> $ HaulNumber            <int> 43, 43, 43, 42, 42, 42, 42, 42, 42, 42, 42, 42, …
#> $ Year                  <int> 1991, 1991, 1991, 1991, 1991, 1991, 1991, 1991, …
#> $ SpeciesCodeType       <chr> "W", "W", "W", "W", "W", "W", "W", "W", "W", "W"…
#> $ SpeciesCode           <chr> "127143", "127143", "126440", "126417", "126417"…
#> $ SpeciesValidity       <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ SpeciesSex            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ TotalNumber           <dbl> 6, 6, 2, 596, 596, 596, 596, 596, 596, 596, 596,…
#> $ SpeciesCategory       <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampledNumber      <int> 3, 3, 1, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63,…
#> $ SubsamplingFactor     <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampleWeight       <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SpeciesCategoryWeight <int> 9, 9, 2, 240, 240, 240, 240, 240, 240, 240, 240,…
#> $ LengthCode            <chr> "1", "1", "1", "0", "0", "0", "0", "0", "0", "0"…
#> $ LengthClass           <int> 24, 25, 24, 150, 155, 160, 165, 170, 175, 210, 2…
#> $ NumberAtLength        <dbl> 2, 4, 2, 9, 9, 28, 57, 19, 19, 47, 38, 9, 9, 376…
#> $ DevelopmentStage      <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthType            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ ValidAphiaID          <int> 127143, 127143, 126440, 126417, 126417, 126417, …
#> $ latin                 <chr> "Pleuronectes platessa", "Pleuronectes platessa"…
#> $ DateofCalculation     <chr> "20250401", "20250401", "20250401", "20250401", …
#> $ .id                   <chr> "BITS:1991:1:DE:06S1:H20:48:43", "BITS:1991:1:DE…
#> $ length_cm             <dbl> 24.0, 25.0, 24.0, 15.0, 15.5, 16.0, 16.5, 17.0, …
#> $ HaulDuration          <int> 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, …
#> $ DataType              <chr> "C", "C", "C", "C", "C", "C", "C", "C", "C", "C"…
#> $ n                     <dbl> 1.0, 2.0, 1.0, 4.5, 4.5, 14.0, 28.5, 9.5, 9.5, 2…
#> $ cpue                  <dbl> 2, 4, 2, 9, 9, 28, 57, 19, 19, 47, 38, 9, 9, 376…
```

## Connecting

You can generate a connection to the main DATRAS tables by:

``` r
hh <- dr_con("HH")
hl <- dr_con("HL")
ca <- dr_con("CA")
```

## A little peek

``` r
hh
#> # Source:   table<rjpcxhnhfwscbkd> [?? x 74]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    RecordHeader Survey Quarter Country Platform Gear  SweepLength GearExceptions
#>    <chr>        <chr>    <int> <chr>   <chr>    <chr>       <int> <chr>         
#>  1 ﻿HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  2 HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  3 HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  4 HH           BITS         1 DK      26D4     EXP           110 <NA>          
#>  5 HH           BITS         1 DK      26D4     EXP           110 <NA>          
#>  6 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  7 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  8 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  9 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#> 10 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#> # ℹ more rows
#> # ℹ 66 more variables: DoorType <chr>, StationName <chr>, HaulNumber <int>,
#> #   Year <int>, Month <int>, Day <int>, StartTime <chr>, DepthStratum <chr>,
#> #   HaulDuration <int>, DayNight <chr>, ShootLatitude <dbl>,
#> #   ShootLongitude <dbl>, HaulLatitude <dbl>, HaulLongitude <dbl>,
#> #   StatisticalRectangle <chr>, BottomDepth <int>, HaulValidity <chr>,
#> #   HydrographicStationID <chr>, StandardSpeciesCode <chr>, …
hl
#> # Source:   SQL [?? x 7]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    .id                   latin length_cm SpeciesSex DevelopmentStage     n  cpue
#>    <chr>                 <chr>     <dbl> <chr>      <chr>            <dbl> <dbl>
#>  1 BITS:1991:1:DE:06S1:… Pleu…      24   <NA>       <NA>               1       2
#>  2 BITS:1991:1:DE:06S1:… Pleu…      25   <NA>       <NA>               2       4
#>  3 BITS:1991:1:DE:06S1:… Poll…      24   <NA>       <NA>               1       2
#>  4 BITS:1991:1:DE:06S1:… Clup…      15   <NA>       <NA>               4.5     9
#>  5 BITS:1991:1:DE:06S1:… Clup…      15.5 <NA>       <NA>               4.5     9
#>  6 BITS:1991:1:DE:06S1:… Clup…      16   <NA>       <NA>              14      28
#>  7 BITS:1991:1:DE:06S1:… Clup…      16.5 <NA>       <NA>              28.5    57
#>  8 BITS:1991:1:DE:06S1:… Clup…      17   <NA>       <NA>               9.5    19
#>  9 BITS:1991:1:DE:06S1:… Clup…      17.5 <NA>       <NA>               9.5    19
#> 10 BITS:1991:1:DE:06S1:… Clup…      21   <NA>       <NA>              23.5    47
#> # ℹ more rows
ca
#> # Source:   SQL [?? x 5]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    .id                          latin        length_cm IndividualSex LiverWeight
#>    <chr>                        <chr>            <dbl> <chr>               <dbl>
#>  1 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        34 M                      NA
#>  2 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        36 F                      NA
#>  3 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        39 F                      NA
#>  4 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        40 F                      NA
#>  5 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        43 F                      NA
#>  6 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        45 F                      NA
#>  7 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        30 M                      NA
#>  8 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        31 M                      NA
#>  9 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        34 M                      NA
#> 10 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        35 M                      NA
#> # ℹ more rows
```
